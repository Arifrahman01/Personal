import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/backup/services/backup_crypto_service.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:sqflite/sqflite.dart';

/// Summary of restored records per module after importing a `.phub` backup.
@immutable
class BackupRestoreReport {
  const BackupRestoreReport({
    required this.notesCount,
    required this.meetingsCount,
    required this.vaultCount,
    required this.tasksCount,
    required this.habitsCount,
    required this.transactionsCount,
    this.chatMessagesCount = 0,
    this.habitLogsCount = 0,
    this.prayerPrefsCount = 0,
  });

  final int notesCount;
  final int meetingsCount;
  final int vaultCount;
  final int tasksCount;
  final int habitsCount;
  final int transactionsCount;
  final int chatMessagesCount;
  final int habitLogsCount;
  final int prayerPrefsCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupRestoreReport &&
          runtimeType == other.runtimeType &&
          notesCount == other.notesCount &&
          meetingsCount == other.meetingsCount &&
          vaultCount == other.vaultCount &&
          tasksCount == other.tasksCount &&
          habitsCount == other.habitsCount &&
          transactionsCount == other.transactionsCount &&
          chatMessagesCount == other.chatMessagesCount &&
          habitLogsCount == other.habitLogsCount &&
          prayerPrefsCount == other.prayerPrefsCount;

  @override
  int get hashCode => Object.hash(
    notesCount,
    meetingsCount,
    vaultCount,
    tasksCount,
    habitsCount,
    transactionsCount,
    chatMessagesCount,
    habitLogsCount,
    prayerPrefsCount,
  );
}

/// Exports and restores passphrase-encrypted `.phub` snapshots across all 9 SQLite tables.
class BackupService {
  BackupService(
    this._db,
    this._vaultRepo,
    this._crypto, [
    this._configStore,
  ]);

  static const String _vaultEntriesKey = 'vault_entries';

  static const Map<String, Set<String>> _nonVaultTableColumns = {
    'notes': {
      'id',
      'title',
      'content',
      'tags',
      'is_pinned',
      'created_at',
      'updated_at',
    },
    'meetings': {
      'id',
      'title',
      'scheduled_at',
      'location',
      'attendees',
      'agenda',
      'notes',
      'action_items',
      'reminder_minutes',
      'created_at',
      'updated_at',
    },
    'chat_messages': {
      'id',
      'role',
      'content',
      'used_model',
      'did_fallback',
      'created_at',
    },
    'prayer_prefs': {
      'id',
      'city_name',
      'latitude',
      'longitude',
      'method',
      'pre_reminder_minutes',
      'sound_enabled',
      'enabled_prayers',
    },
    'tasks': {
      'id',
      'title',
      'due_date',
      'priority',
      'is_done',
      'source_meeting_id',
      'created_at',
      'updated_at',
    },
    'habits': {
      'id',
      'title',
      'category',
      'target_per_day',
      'created_at',
    },
    'habit_logs': {
      'id',
      'habit_id',
      'log_date',
      'completed_count',
    },
    'transactions': {
      'id',
      'type',
      'amount',
      'category',
      'note',
      'occurred_at',
      'created_at',
    },
  };

  final AppDatabase _db;
  final VaultRepository _vaultRepo;
  final BackupCryptoService _crypto;
  final SecureConfigStore? _configStore;

  /// Exports all 9 SQLite tables (with Vault entries decrypted inside the encrypted payload)
  /// as `.phub` encrypted bytes protected by [passphrase].
  ///
  /// Throws [VaultDecryptionException] if the Vault has a configured PIN and its
  /// master key is currently locked.
  Future<Uint8List> exportEncryptedBytes({required String passphrase}) async {
    if (passphrase.length < BackupCryptoService.minPassphraseLength) {
      throw const ValidationException(
        'Passphrase backup minimal harus 6 karakter.',
      );
    }

    if (_configStore != null &&
        await _configStore.hasPin() &&
        !_configStore.hasUnlockedMasterKey) {
      throw const VaultDecryptionException(
        'Buka kunci Brankas terlebih dahulu untuk mengekspor cadangan terenkripsi.',
      );
    }

    final tables = <String, Object?>{};
    for (final table in _nonVaultTableColumns.keys) {
      tables[table] = await _db.db.query(table);
    }

    final vaultEntries = await _vaultRepo.getEntries();
    tables[_vaultEntriesKey] = vaultEntries
        .map(
          (entry) => <String, Object?>{
            'id': entry.id,
            'title': entry.title,
            'username': entry.username,
            'password': entry.password,
            'url': entry.url,
            'notes': entry.notes,
            'created_at': entry.createdAt.toUtc().toIso8601String(),
            'updated_at': entry.updatedAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false);

    final snapshot = <String, Object?>{
      'schemaVersion': AppDatabase.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };

    return _crypto.encryptSnapshot(
      jsonEncode(snapshot),
      passphrase: passphrase,
    );
  }

  /// Decrypts and validates [bytes] BEFORE touching SQLite, replaces all tables
  /// atomically for non-vault data, and re-encrypts Vault entries under the
  /// destination device's Vault master key via [VaultRepository.upsertEntry].
  Future<BackupRestoreReport> importEncryptedBytes(
    Uint8List bytes, {
    required String passphrase,
  }) async {
    final jsonString = await _crypto.decryptSnapshot(
      bytes,
      passphrase: passphrase,
    );
    final parsed = _parseAndValidateSnapshot(jsonString);

    // Pre-encrypt all vault entries BEFORE modifying SQLite so an encryption
    // or master-key failure can never leave the database partially restored or wiped.
    final encryptedVaultRows = <Map<String, Object?>>[];
    for (final vaultEntry in parsed.vaultEntries) {
      encryptedVaultRows.add(
        await _vaultRepo.encryptEntryForStorage(vaultEntry),
      );
    }

    // Sanitize orphaned foreign-key references from legacy backups.
    final restoredMeetingIds = parsed.nonVaultTables['meetings']!
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();
    for (final taskRow in parsed.nonVaultTables['tasks']!) {
      final sourceId = taskRow['source_meeting_id'];
      if (sourceId is String && !restoredMeetingIds.contains(sourceId)) {
        taskRow['source_meeting_id'] = null;
      }
    }

    await _db.db.transaction((txn) async {
      for (final table in _nonVaultTableColumns.keys) {
        await txn.delete(table);
      }
      await txn.delete('vault_items');

      for (final entry in parsed.nonVaultTables.entries) {
        for (final row in entry.value) {
          await txn.insert(
            entry.key,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final vaultRow in encryptedVaultRows) {
        await txn.insert(
          'vault_items',
          vaultRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return BackupRestoreReport(
      notesCount: parsed.nonVaultTables['notes']!.length,
      meetingsCount: parsed.nonVaultTables['meetings']!.length,
      vaultCount: parsed.vaultEntries.length,
      tasksCount: parsed.nonVaultTables['tasks']!.length,
      habitsCount: parsed.nonVaultTables['habits']!.length,
      transactionsCount: parsed.nonVaultTables['transactions']!.length,
      chatMessagesCount: parsed.nonVaultTables['chat_messages']!.length,
      habitLogsCount: parsed.nonVaultTables['habit_logs']!.length,
      prayerPrefsCount: parsed.nonVaultTables['prayer_prefs']!.length,
    );
  }

  _ParsedBackupSnapshot _parseAndValidateSnapshot(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupDecryptionException(
          'Isi snapshot backup tidak valid.',
        );
      }

      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion is! int ||
          schemaVersion < 1 ||
          schemaVersion > AppDatabase.schemaVersion) {
        throw const BackupDecryptionException(
          'Versi skema snapshot backup tidak didukung.',
        );
      }

      final tablesRaw = decoded['tables'];
      if (tablesRaw is! Map<String, dynamic>) {
        throw const BackupDecryptionException(
          'Struktur tabel snapshot backup tidak valid.',
        );
      }

      final nonVaultTables = <String, List<Map<String, Object?>>>{};
      for (final entry in _nonVaultTableColumns.entries) {
        final tableName = entry.key;
        final allowedColumns = entry.value;
        final rawList = tablesRaw[tableName];
        if (rawList is! List) {
          throw BackupDecryptionException(
            'Data tabel $tableName pada backup tidak valid.',
          );
        }

        final sanitizedRows = <Map<String, Object?>>[];
        for (final item in rawList) {
          if (item is! Map<String, dynamic>) {
            throw BackupDecryptionException(
              'Baris pada tabel $tableName tidak valid.',
            );
          }
          final row = <String, Object?>{};
          for (final column in allowedColumns) {
            if (item.containsKey(column)) {
              row[column] = item[column];
            }
          }
          if (row.isEmpty) {
            throw BackupDecryptionException(
              'Baris pada tabel $tableName kosong atau rusak.',
            );
          }
          sanitizedRows.add(row);
        }
        nonVaultTables[tableName] = sanitizedRows;
      }

      final rawVaultList = tablesRaw[_vaultEntriesKey];
      if (rawVaultList is! List) {
        throw const BackupDecryptionException(
          'Data brankas pada backup tidak valid.',
        );
      }

      final vaultEntries = <VaultEntry>[];
      for (final item in rawVaultList) {
        if (item is! Map<String, dynamic>) {
          throw const BackupDecryptionException(
            'Entri brankas pada backup tidak valid.',
          );
        }
        final id = item['id'];
        final title = item['title'];
        final password = item['password'];
        final createdAtRaw = item['created_at'];
        final updatedAtRaw = item['updated_at'];

        if (id is! String ||
            id.trim().isEmpty ||
            title is! String ||
            title.trim().isEmpty ||
            password is! String ||
            password.trim().isEmpty ||
            createdAtRaw is! String ||
            updatedAtRaw is! String) {
          throw const BackupDecryptionException(
            'Field wajib entri brankas pada backup tidak valid.',
          );
        }

        vaultEntries.add(
          VaultEntry(
            id: id,
            title: title,
            username: (item['username'] as String?) ?? '',
            password: password,
            url: (item['url'] as String?) ?? '',
            notes: (item['notes'] as String?) ?? '',
            createdAt: DateTime.parse(createdAtRaw).toUtc(),
            updatedAt: DateTime.parse(updatedAtRaw).toUtc(),
          ),
        );
      }

      return _ParsedBackupSnapshot(
        nonVaultTables: nonVaultTables,
        vaultEntries: vaultEntries,
      );
    } on BackupDecryptionException {
      rethrow;
    } catch (_) {
      throw const BackupDecryptionException(
        'Snapshot backup rusak atau formatnya tidak dikenali.',
      );
    }
  }
}

class _ParsedBackupSnapshot {
  const _ParsedBackupSnapshot({
    required this.nonVaultTables,
    required this.vaultEntries,
  });

  final Map<String, List<Map<String, Object?>>> nonVaultTables;
  final List<VaultEntry> vaultEntries;
}
