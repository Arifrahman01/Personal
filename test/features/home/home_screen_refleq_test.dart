import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
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

  Widget buildTestableHomeScreen({
    required AppDatabase appDb,
    required ClipboardGuard clipboardGuard,
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
        clipboardGuardProvider.overrideWithValue(clipboardGuard),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen - Refleq Minimal Aurora Dashboard Tests', () {
    testWidgets('renders all Refleq aesthetic elements on standard phone (390x844)', (tester) async {
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

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        buildTestableHomeScreen(appDb: appDb, clipboardGuard: clipboardGuard),
      );
      await tester.pumpAndSettle();

      // 1. Reactive Copilot badge
      expect(find.textContaining('Copilot'), findsWidgets);

      // 2. Horizontal Date/Prayer Strip
      final now = DateTime.now();
      expect(find.text('${now.day}'), findsWidgets);

      // 3. 2x2 Modular Action Tiles
      expect(find.text('Keuangan Harian'), findsOneWidget);
      expect(find.text('Tugas & Habit'), findsOneWidget);
      expect(find.text('Jadwal & Kiblat'), findsOneWidget);
      expect(find.text('Voice Copilot'), findsWidgets);

      // 4. Quick Capture Floating Bar
      expect(
        find.widgetWithText(TextField, 'Tulis ide, "beli bensin 50rb", tugas...'),
        findsOneWidget,
      );

      // 5. Hero Card
      expect(find.textContaining('Sholat Berikutnya'), findsOneWidget);
    });

    testWidgets('verifies layout responsiveness without RenderFlex overflow on small screen (320x600)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
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

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      FlutterErrorDetails? capturedDetails;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedDetails = details;
        oldOnError?.call(details);
      };

      await tester.pumpWidget(
        buildTestableHomeScreen(appDb: appDb, clipboardGuard: clipboardGuard),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = oldOnError;
      if (capturedDetails != null) {
        debugPrint('OVERFLOW DETAILS: ${capturedDetails!.summary}');
        debugPrint('CONTEXT: ${capturedDetails!.context}');
      }
      expect(capturedDetails, isNull);
    });

    testWidgets('verifies layout responsiveness on tablet screen (768x1024)', (tester) async {
      tester.view.physicalSize = const Size(768 * 2, 1024 * 2);
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

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        buildTestableHomeScreen(appDb: appDb, clipboardGuard: clipboardGuard),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
