import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
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
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
  });

  Widget buildTestablePrayerScreen({
    required AppDatabase appDb,
    bool isEmbedded = false,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDb),
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
      expect(find.text('U'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });
}
