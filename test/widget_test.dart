import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
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

  testWidgets(
    'PersonalHubApp renders 5-tab docked NavigationBar on mobile screens (<600dp) and navigates tabs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
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
          child: const PersonalHubApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);

      for (final label in ['Hari Ini', 'Agenda', 'Catatan', 'Keuangan', 'Vault']) {
        expect(
          find.descendant(of: navBar, matching: find.text(label)),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Agenda')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsWidgets);
      expect(find.text('Meeting'), findsWidgets);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Catatan')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada catatan'), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Keuangan')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keuangan & Zakat'), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Vault')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buat PIN Brankas'), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Hari Ini')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal Hub'), findsOneWidget);
    },
  );

  testWidgets(
    'PersonalHubApp renders NavigationRail on wide screens (>=600dp)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
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
          child: const PersonalHubApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navRail = find.byType(NavigationRail);
      expect(navRail, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'MainNavigationShell displays privacy overlay when app is inactive or hidden and clears on resume',
    (WidgetTester tester) async {
      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
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
          child: const PersonalHubApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no privacy shield overlay
      expect(find.text('Personal Hub - Layar Terlindungi'), findsNothing);

      // Transition to inactive (e.g. multitasking card / app switcher)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('Personal Hub - Layar Terlindungi'), findsOneWidget);

      // Return to foreground (resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Personal Hub - Layar Terlindungi'), findsNothing);

      // Full background sequence: resumed -> inactive -> hidden -> paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text('Personal Hub - Layar Terlindungi'), findsOneWidget);

      // Return sequence: paused -> hidden -> inactive -> resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Personal Hub - Layar Terlindungi'), findsNothing);
    },
  );
}
