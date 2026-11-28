import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/prayer_location_service.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _FakeBiometricAdapter implements BiometricAuthAdapter {
  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

class _FakeClipboardAdapter implements ClipboardAdapter {
  @override
  Future<String?> getText() async => '';

  @override
  Future<void> setText(String text) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Widget buildTestablePrayerScreen({
    required AppDatabase appDb,
    bool isEmbedded = false,
  }) {
    final mockLocationClient = MockClient(
      (_) async => http.Response(jsonEncode(const []), 200),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDb),
        prayerLocationServiceProvider.overrideWithValue(
          PrayerLocationService(client: mockLocationClient),
        ),
        secureConfigStoreProvider.overrideWithValue(
          SecureConfigStore(_InMemorySecureStorage()),
        ),
        biometricAuthAdapterProvider.overrideWithValue(
          _FakeBiometricAdapter(),
        ),
        clipboardGuardProvider.overrideWithValue(
          ClipboardGuard(_FakeClipboardAdapter()),
        ),
      ],
      child: MaterialApp(
        home: PrayerScheduleScreen(isEmbedded: isEmbedded),
      ),
    );
  }

  group('PrayerScheduleScreen Tests', () {
    testWidgets('renders clean front interface: city, prayer times, Syuruq, and tabs',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      await tester.pumpWidget(buildTestablePrayerScreen(appDb: appDb));
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Jadwal Sholat & Kiblat'), findsOneWidget);

      // Clean front interface: City & 5 daily prayers + Syuruq
      expect(find.text('Subuh'), findsOneWidget);
      expect(find.text('Syuruq (Terbit)'), findsOneWidget);
      expect(find.text('Dzuhur'), findsOneWidget);
      expect(find.text('Ashar'), findsOneWidget);
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.text('Isya'), findsOneWidget);
    });

    testWidgets(
        'settings icon in header opens bottom sheet Pengaturan Adzan & Lanjutan',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      await tester.pumpWidget(buildTestablePrayerScreen(appDb: appDb));
      await tester.pumpAndSettle();

      // Tap header settings icon
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('Pengaturan Adzan & Lanjutan'), findsOneWidget);
      expect(find.text('Mode Notifikasi Adzan'), findsOneWidget);
      expect(find.text('Status Notifikasi Server'), findsOneWidget);
      expect(find.text('Pengaturan Hisab & Pengingat'), findsOneWidget);
      expect(find.text('Metode Hisab'), findsOneWidget);
    });

    testWidgets('switching to Arah Kiblat tab displays Qibla compass bearing and dial',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      await tester.pumpWidget(buildTestablePrayerScreen(appDb: appDb));
      await tester.pumpAndSettle();

      // Tap Arah Kiblat tab
      await tester.tap(find.text('Arah Kiblat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Arah Kiblat —'), findsOneWidget);
      expect(find.textContaining('dari Utara Sejati'), findsOneWidget);
      expect(find.textContaining('km ke Ka\'bah'), findsOneWidget);
      expect(find.textContaining('Koordinat:'), findsNothing);
      expect(find.text('U'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets(
      'location picker shows Muslim Pro-style search, province & timezone without coordinates and updates city on selection',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final appDb = await AppDatabase.open(
          pathOverride: inMemoryDatabasePath,
          factoryOverride: databaseFactoryFfiNoIsolate,
        );
        addTearDown(() async => appDb.close());

        await tester.pumpWidget(buildTestablePrayerScreen(appDb: appDb));
        await tester.pumpAndSettle();

        // Buka pemilih lokasi kota/kecamatan
        await tester.tap(find.text('Ganti'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Lokasi Sholat'), findsOneWidget);
        expect(find.text('Deteksi Lokasi Otomatis (GPS)'), findsOneWidget);
        expect(find.text('DKI Jakarta • WIB'), findsAtLeastNWidgets(1));
        expect(find.textContaining('-6.2088'), findsNothing);
        expect(find.textContaining('106.8456'), findsNothing);

        // Cari kota Malang & pilih
        await tester.enterText(find.byType(TextField), 'Malang');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        final malangTile = find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Malang'),
        );
        expect(malangTile, findsOneWidget);
        expect(find.text('Jawa Timur • WIB'), findsOneWidget);

        await tester.tap(malangTile);
        await tester.pumpAndSettle();

        expect(find.text('Malang'), findsOneWidget);
        expect(find.text('Jawa Timur • WIB'), findsOneWidget);
      },
    );
  });
}
