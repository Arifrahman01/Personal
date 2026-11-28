import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
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

  Widget buildTestableAgendaHubScreen({
    required AppDatabase appDb,
    int initialSection = 0,
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
        home: AgendaHubScreen(initialSection: initialSection),
      ),
    );
  }

  group('AgendaHubScreen Tests', () {
    testWidgets('renders all 3 segments: Meeting, Tugas & Habit, Sholat & Kiblat',
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

      await tester.pumpWidget(
        buildTestableAgendaHubScreen(appDb: appDb, initialSection: 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Meeting'), findsOneWidget);
      expect(find.text('Tugas & Habit'), findsOneWidget);
      expect(find.text('Sholat & Kiblat'), findsOneWidget);
    });

    testWidgets('initialSection: 1 opens Tugas & Habit sub-tab', (tester) async {
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

      await tester.pumpWidget(
        buildTestableAgendaHubScreen(appDb: appDb, initialSection: 1),
      );
      await tester.pumpAndSettle();

      // Should show quick task input from TasksHabitsScreen
      expect(find.byKey(const Key('quick_task_input')), findsOneWidget);
    });

    testWidgets('initialSection: 2 opens Sholat & Kiblat sub-tab', (tester) async {
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

      await tester.pumpWidget(
        buildTestableAgendaHubScreen(appDb: appDb, initialSection: 2),
      );
      await tester.pumpAndSettle();

      // Should find prayer elements
      expect(find.text('Jadwal & Notif'), findsOneWidget);
      expect(find.text('Arah Kiblat'), findsOneWidget);
    });

    testWidgets('switching SegmentedButton switches visible views', (tester) async {
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

      await tester.pumpWidget(
        buildTestableAgendaHubScreen(appDb: appDb, initialSection: 0),
      );
      await tester.pumpAndSettle();

      // Tap on Tugas & Habit segment
      await tester.tap(find.text('Tugas & Habit'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick_task_input')), findsOneWidget);

      // Tap on Sholat & Kiblat segment
      await tester.tap(find.text('Sholat & Kiblat'));
      await tester.pumpAndSettle();
      expect(find.text('Arah Kiblat'), findsOneWidget);
    });
  });
}
