import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/finance/models/gold_price_models.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Persistence contract for lightweight application preferences stored in SQLite
/// (without abusing OS Keystore/Keychain).
abstract interface class AppPreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// SQLite-backed implementation of [AppPreferencesStore] using the `app_preferences` table.
class SqliteAppPreferencesStore implements AppPreferencesStore {
  SqliteAppPreferencesStore(this._database);

  static const String tableName = 'app_preferences';
  final AppDatabase _database;

  @override
  Future<String?> getString(String key) async {
    final rows = await _database.db.query(
      tableName,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setString(String key, String value) async {
    await _database.db.insert(
      tableName,
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String key) async {
    await _database.db.delete(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}

/// Ephemeral in-memory fallback used in isolated widget tests without [AppDatabase].
class InMemoryAppPreferencesStore implements AppPreferencesStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Canonical preference keys persisted in `app_preferences`.
abstract final class AppPreferenceKeys {
  static const String themeMode = 'theme_mode';
  static const String homeModuleVisibility = 'home_module_visibility';
  static const String manualZakatAssets = 'manual_zakat_assets';
}

/// Helper to load startup preferences synchronously-before-runApp from [AppPreferencesStore].
class AppPreferencesBootstrap {
  const AppPreferencesBootstrap({
    required this.themeMode,
    required this.homeModulePreferences,
    required this.manualZakatAssets,
  });

  final ThemeMode themeMode;
  final HomeModulePreferences homeModulePreferences;
  final ManualZakatAssetInput manualZakatAssets;

  static Future<AppPreferencesBootstrap> load(AppPreferencesStore store) async {
    final rawTheme = await store.getString(AppPreferenceKeys.themeMode);
    final themeMode = switch (rawTheme?.trim()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    var homePrefs = const HomeModulePreferences();
    final rawHome = await store.getString(
      AppPreferenceKeys.homeModuleVisibility,
    );
    if (rawHome != null && rawHome.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHome);
        if (decoded is Map<String, dynamic>) {
          homePrefs = HomeModulePreferences.fromJson(decoded);
        }
      } catch (_) {}
    }

    var zakatAssets = const ManualZakatAssetInput();
    final rawZakat = await store.getString(
      AppPreferenceKeys.manualZakatAssets,
    );
    if (rawZakat != null && rawZakat.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawZakat);
        if (decoded is Map<String, dynamic>) {
          zakatAssets = ManualZakatAssetInput.fromJson(decoded);
        }
      } catch (_) {}
    }

    return AppPreferencesBootstrap(
      themeMode: themeMode,
      homeModulePreferences: homePrefs,
      manualZakatAssets: zakatAssets,
    );
  }
}

/// Provides the active [AppPreferencesStore], falling back safely to in-memory
/// when [appDatabaseProvider] is not overridden in isolated widget tests.
final appPreferencesStoreProvider = Provider<AppPreferencesStore>((ref) {
  try {
    final db = ref.watch(appDatabaseProvider);
    return SqliteAppPreferencesStore(db);
  } catch (_) {
    return InMemoryAppPreferencesStore();
  }
});

/// Startup-hydrated initial [ThemeMode]. Overridden in `main.dart`.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Startup-hydrated initial [HomeModulePreferences]. Overridden in `main.dart`.
final initialHomeModulePreferencesProvider = Provider<HomeModulePreferences>(
  (ref) => const HomeModulePreferences(),
);

/// Startup-hydrated initial [ManualZakatAssetInput]. Overridden in `main.dart`.
final initialManualZakatAssetProvider = Provider<ManualZakatAssetInput>(
  (ref) => const ManualZakatAssetInput(),
);
