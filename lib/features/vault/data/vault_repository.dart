import 'dart:convert';

import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Persists password vault items in SQLite with AES-256-GCM encrypted secrets.
class VaultRepository {
  VaultRepository(
    this._db,
    this._configStore,
    this._crypto, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static const String _tableName = 'vault_items';

  final AppDatabase _db;
  final SecureConfigStore _configStore;
  final VaultCryptoService _crypto;
  final Uuid _uuid;

  /// Creates and persists a new encrypted vault entry.
  Future<VaultEntry> createEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
  }) async {
    _validateFields(title: title, password: password);
    final now = DateTime.now().toUtc();
    final entry = VaultEntry(
      id: _uuid.v4(),
      title: title.trim(),
      username: username.trim(),
      password: password,
      url: url.trim(),
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    return upsertEntry(entry);
  }

  /// Updates an existing vault entry with a newly encrypted payload and fresh nonce.
  Future<VaultEntry> updateEntry(VaultEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw const ValidationException('ID entri brankas tidak boleh kosong.');
    }
    _validateFields(title: entry.title, password: entry.password);

    final updated = entry.copyWith(
      title: entry.title.trim(),
      username: entry.username.trim(),
      url: entry.url.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    final row = await _toEncryptedRow(updated);
    final affected = await _db.db.update(
      _tableName,
      row,
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    if (affected == 0) {
      throw const ValidationException('Entri brankas tidak ditemukan.');
    }
    return updated;
  }

  /// Inserts or replaces a vault entry while preserving its [VaultEntry.id].
  Future<VaultEntry> upsertEntry(VaultEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw const ValidationException('ID entri brankas tidak boleh kosong.');
    }
    _validateFields(title: entry.title, password: entry.password);

    final normalized = entry.copyWith(
      title: entry.title.trim(),
      username: entry.username.trim(),
      url: entry.url.trim(),
      createdAt: entry.createdAt.toUtc(),
      updatedAt: entry.updatedAt.toUtc(),
    );
    final row = await _toEncryptedRow(normalized);
    await _db.db.insert(
      _tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return normalized;
  }

  /// Deletes a vault entry by [id].
  Future<void> deleteEntry(String id) async {
    await _db.db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Validates, normalizes, and encrypts [entry] into a SQLite row map without writing it.
  Future<Map<String, Object?>> encryptEntryForStorage(VaultEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw const ValidationException('ID entri brankas tidak boleh kosong.');
    }
    _validateFields(title: entry.title, password: entry.password);

    final normalized = entry.copyWith(
      title: entry.title.trim(),
      username: entry.username.trim(),
      url: entry.url.trim(),
      createdAt: entry.createdAt.toUtc(),
      updatedAt: entry.updatedAt.toUtc(),
    );
    return _toEncryptedRow(normalized);
  }

  /// Decrypts and returns vault entries sorted alphabetically by title, optionally filtered by [query].
  Future<List<VaultEntry>> getEntries({String? query}) async {
    final rows = await _db.db.query(_tableName);
    if (rows.isEmpty) {
      return const [];
    }

    final masterKey = await _configStore.getOrCreateVaultMasterKey();
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final entries = <VaultEntry>[];

    for (final row in rows) {
      final entry = await _fromEncryptedRow(row, masterKey);
      if (normalizedQuery.isEmpty || _matchesQuery(entry, normalizedQuery)) {
        entries.add(entry);
      }
    }

    entries.sort((a, b) {
      final titleCmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (titleCmp != 0) return titleCmp;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return entries;
  }

  void _validateFields({required String title, required String password}) {
    if (title.trim().isEmpty) {
      throw const ValidationException('Judul akun tidak boleh kosong.');
    }
    if (password.trim().isEmpty) {
      throw const ValidationException('Kata sandi tidak boleh kosong.');
    }
  }

  bool _matchesQuery(VaultEntry entry, String lowerQuery) {
    return entry.title.toLowerCase().contains(lowerQuery) ||
        entry.username.toLowerCase().contains(lowerQuery) ||
        entry.url.toLowerCase().contains(lowerQuery);
  }

  Future<Map<String, Object?>> _toEncryptedRow(VaultEntry entry) async {
    final masterKey = await _configStore.getOrCreateVaultMasterKey();
    final secretJson = jsonEncode({
      'title': entry.title,
      'username': entry.username,
      'password': entry.password,
      'url': entry.url,
      'notes': entry.notes,
    });
    final payload = await _crypto.encrypt(secretJson, masterKey);

    return {
      'id': entry.id,
      'title': '[terenkripsi]',
      'username': '',
      'encrypted_payload': payload.cipherTextBase64,
      'nonce': payload.nonceBase64,
      'mac': payload.macBase64,
      'created_at': entry.createdAt.toUtc().toIso8601String(),
      'updated_at': entry.updatedAt.toUtc().toIso8601String(),
    };
  }

  Future<VaultEntry> _fromEncryptedRow(
    Map<String, Object?> row,
    List<int> masterKey,
  ) async {
    final payload = EncryptedPayload(
      cipherTextBase64: row['encrypted_payload']! as String,
      nonceBase64: row['nonce']! as String,
      macBase64: row['mac']! as String,
    );

    final clearJson = await _crypto.decrypt(payload, masterKey);
    final decoded = jsonDecode(clearJson);
    if (decoded is! Map<String, dynamic>) {
      throw const VaultDecryptionException(
        'Struktur data brankas terenkripsi tidak valid.',
      );
    }

    final decodedTitle = (decoded['title'] as String?)?.trim();
    final rowTitle = row['title']! as String;
    final resolvedTitle =
        (decodedTitle != null && decodedTitle.isNotEmpty)
            ? decodedTitle
            : rowTitle;
    final resolvedUsername =
        (decoded['username'] as String?) ??
        (row['username'] as String?) ??
        '';

    return VaultEntry(
      id: row['id']! as String,
      title: resolvedTitle,
      username: resolvedUsername,
      password: (decoded['password'] as String?) ?? '',
      url: (decoded['url'] as String?) ?? '',
      notes: (decoded['notes'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
    );
  }
}
