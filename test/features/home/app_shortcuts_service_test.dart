import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/home/providers/app_shortcuts_providers.dart';
import 'package:personal_hub/features/home/services/app_shortcuts_service.dart';

void main() {
  const service = AppShortcutsService();

  group('AppShortcutItem Model', () {
    test('instantiates with all required and default fields', () {
      const item = AppShortcutItem(
        id: 'test_id',
        title: 'Test Title',
        subtitle: 'Test Subtitle',
        iconName: 'test_icon',
        targetRoute: '/test_route',
        targetTabIndex: 2,
        payload: {'key': 'value'},
        isEnabled: true,
        order: 5,
      );

      expect(item.id, equals('test_id'));
      expect(item.title, equals('Test Title'));
      expect(item.subtitle, equals('Test Subtitle'));
      expect(item.iconName, equals('test_icon'));
      expect(item.targetRoute, equals('/test_route'));
      expect(item.targetTabIndex, equals(2));
      expect(item.payload, equals({'key': 'value'}));
      expect(item.isEnabled, isTrue);
      expect(item.order, equals(5));
    });

    test('copyWith modifies only specified fields', () {
      const original = AppShortcutItem(
        id: 'id1',
        title: 'Title 1',
        subtitle: 'Sub 1',
        iconName: 'icon1',
        targetRoute: '/route1',
        targetTabIndex: 0,
      );

      final modified = original.copyWith(
        title: 'Title 2',
        targetTabIndex: 3,
        isEnabled: false,
      );

      expect(modified.id, equals('id1'));
      expect(modified.title, equals('Title 2'));
      expect(modified.subtitle, equals('Sub 1'));
      expect(modified.iconName, equals('icon1'));
      expect(modified.targetRoute, equals('/route1'));
      expect(modified.targetTabIndex, equals(3));
      expect(modified.isEnabled, isFalse);
    });

    test('toMap and fromMap serialization roundtrip', () {
      const item = AppShortcutItem(
        id: 'quick_capture',
        title: 'Catat Cepat',
        subtitle: 'Input suara',
        iconName: 'mic',
        targetRoute: '/quick_capture',
        targetTabIndex: 0,
        payload: {'action': 'quick_capture'},
        isEnabled: true,
        order: 1,
      );

      final map = item.toMap();
      final restored = AppShortcutItem.fromMap(map);

      expect(restored.id, equals(item.id));
      expect(restored.title, equals(item.title));
      expect(restored.subtitle, equals(item.subtitle));
      expect(restored.iconName, equals(item.iconName));
      expect(restored.targetRoute, equals(item.targetRoute));
      expect(restored.targetTabIndex, equals(item.targetTabIndex));
      expect(restored.payload, equals(item.payload));
      expect(restored.isEnabled, equals(item.isEnabled));
      expect(restored.order, equals(item.order));
      expect(restored, equals(item));
    });

    test('toJson and fromJson serialization roundtrip', () {
      const item = AppShortcutItem(
        id: 'prayer_schedule',
        title: 'Jadwal Sholat',
        subtitle: 'Waktu sholat',
        iconName: 'compass',
        targetRoute: '/prayer_schedule',
        targetTabIndex: 0,
        payload: {'action': 'prayer_schedule'},
      );

      final jsonString = item.toJson();
      final restored = AppShortcutItem.fromJson(jsonString);

      expect(restored, equals(item));
      expect(restored.hashCode, equals(item.hashCode));
      expect(item.toString(), contains('prayer_schedule'));
    });
  });

  group('AppShortcutIntentResult Model', () {
    test('instantiates with proper attributes', () {
      const result = AppShortcutIntentResult(
        shortcutId: 'quick_capture',
        tabIndex: 0,
        route: '/quick_capture',
        payload: {'action': 'quick_capture'},
        isRecognized: true,
        isFallback: false,
      );

      expect(result.shortcutId, equals('quick_capture'));
      expect(result.tabIndex, equals(0));
      expect(result.route, equals('/quick_capture'));
      expect(result.payload['action'], equals('quick_capture'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('fallback factory produces safe default to Home', () {
      final fallback = AppShortcutIntentResult.fallback('invalid_id');

      expect(fallback.shortcutId, equals('invalid_id'));
      expect(fallback.tabIndex, equals(0));
      expect(fallback.route, equals(AppShortcutRoutes.home));
      expect(fallback.isRecognized, isFalse);
      expect(fallback.isFallback, isTrue);
      expect(fallback.payload['isFallback'], isTrue);
    });

    test('fallback factory handles null or whitespace shortcutId', () {
      final fallbackNull = AppShortcutIntentResult.fallback(null);
      expect(fallbackNull.shortcutId, equals('unknown'));

      final fallbackEmpty = AppShortcutIntentResult.fallback('   ');
      expect(fallbackEmpty.shortcutId, equals('unknown'));
    });

    test('toMap and toJson support', () {
      final result = AppShortcutIntentResult.fallback('err');
      final map = result.toMap();
      expect(map['shortcutId'], equals('err'));
      expect(map['isFallback'], isTrue);

      final jsonStr = result.toJson();
      expect(jsonDecode(jsonStr)['tabIndex'], equals(0));
      expect(result.toString(), contains('tabIndex: 0'));
    });
  });

  group('AppShortcutsService - Shortcut Enumeration', () {
    test('getAvailableShortcuts returns exactly 4 pre-defined items in order', () {
      final shortcuts = service.getAvailableShortcuts();

      expect(shortcuts.length, equals(4));
      expect(shortcuts.map((s) => s.id).toList(), equals([
        'quick_capture',
        'prayer_schedule',
        'new_note',
        'new_transaction',
      ]));
    });

    test('verifies pre-defined shortcuts meet exact specification', () {
      final shortcuts = service.getAvailableShortcuts();

      // 1. quick_capture: "Catat Cepat (Voice/Teks)"
      final quickCapture = shortcuts.firstWhere((s) => s.id == 'quick_capture');
      expect(quickCapture.title, equals('Catat Cepat (Voice/Teks)'));
      expect(quickCapture.iconName, equals('mic'));
      expect(quickCapture.targetRoute, equals('/quick_capture'));
      expect(quickCapture.targetTabIndex, equals(0));
      expect(quickCapture.payload['action'], equals('quick_capture'));

      // 2. prayer_schedule: "Jadwal Sholat & Kiblat"
      final prayer = shortcuts.firstWhere((s) => s.id == 'prayer_schedule');
      expect(prayer.title, equals('Jadwal Sholat & Kiblat'));
      expect(prayer.iconName, equals('compass'));
      expect(prayer.targetRoute, equals('/prayer_schedule'));
      expect(prayer.targetTabIndex, equals(0));
      expect(prayer.payload['action'], equals('prayer_schedule'));

      // 3. new_note: "Catatan Baru"
      final newNote = shortcuts.firstWhere((s) => s.id == 'new_note');
      expect(newNote.title, equals('Catatan Baru'));
      expect(newNote.iconName, equals('notebook_pen'));
      expect(newNote.targetRoute, equals('/notes/new'));
      expect(newNote.targetTabIndex, equals(1)); // Notes tab in MainNavigationShell
      expect(newNote.payload['action'], equals('new_note'));

      // 4. new_transaction: "Catat Pengeluaran"
      final newTx = shortcuts.firstWhere((s) => s.id == 'new_transaction');
      expect(newTx.title, equals('Catat Pengeluaran'));
      expect(newTx.iconName, equals('receipt'));
      expect(newTx.targetRoute, equals('/finance/new'));
      expect(newTx.targetTabIndex, equals(0));
      expect(newTx.payload['action'], equals('new_transaction'));
    });

    test('getAvailableShortcuts returns unmodifiable collection', () {
      final shortcuts = service.getAvailableShortcuts();
      expect(
        () => shortcuts.add(
          const AppShortcutItem(
            id: 'extra',
            title: 'Extra',
            subtitle: '',
            iconName: '',
            targetRoute: '',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('getStaticShortcuts returns the 3 shortcuts defined in Android shortcuts.xml', () {
      final staticList = service.getStaticShortcuts();
      expect(staticList.length, equals(3));
      final ids = staticList.map((s) => s.id).toSet();
      expect(ids, equals({'quick_capture', 'prayer_schedule', 'new_note'}));
    });

    test('getDynamicShortcuts returns dynamic shortcuts', () {
      final dynamicList = service.getDynamicShortcuts();
      expect(dynamicList.length, equals(1));
      expect(dynamicList.first.id, equals('new_transaction'));
    });
  });

  group('AppShortcutsService - Shortcut Retrieval & Validation', () {
    test('getShortcutById finds valid shortcuts', () {
      expect(service.getShortcutById('quick_capture')?.title, contains('Catat Cepat'));
      expect(service.getShortcutById('prayer_schedule')?.title, contains('Jadwal Sholat'));
      expect(service.getShortcutById('new_note')?.title, equals('Catatan Baru'));
      expect(service.getShortcutById('new_transaction')?.title, equals('Catat Pengeluaran'));
    });

    test('getShortcutById supports case-insensitive and trimmed lookup', () {
      expect(service.getShortcutById('  QUICK_CAPTURE  ')?.id, equals('quick_capture'));
      expect(service.getShortcutById('NEW_NOTE')?.id, equals('new_note'));
    });

    test('getShortcutById returns null for unknown or empty IDs', () {
      expect(service.getShortcutById('unknown_id'), isNull);
      expect(service.getShortcutById(''), isNull);
      expect(service.getShortcutById('   '), isNull);
    });

    test('isSupportedShortcut returns boolean verification', () {
      expect(service.isSupportedShortcut('quick_capture'), isTrue);
      expect(service.isSupportedShortcut('prayer_schedule'), isTrue);
      expect(service.isSupportedShortcut('new_note'), isTrue);
      expect(service.isSupportedShortcut('new_transaction'), isTrue);
      expect(service.isSupportedShortcut('invalid_shortcut'), isFalse);
    });
  });

  group('AppShortcutsService - Intent Normalization', () {
    test('normalizes direct shortcut IDs', () {
      expect(service.normalizeShortcutId('quick_capture'), equals('quick_capture'));
      expect(service.normalizeShortcutId('prayer_schedule'), equals('prayer_schedule'));
    });

    test('normalizes Android package prefixes', () {
      const packagePrefixed = 'id.personal.hub.personal_hub.quick_capture';
      expect(service.normalizeShortcutId(packagePrefixed), equals('quick_capture'));
    });

    test('normalizes Android intent action prefixes', () {
      expect(
        service.normalizeShortcutId('android.intent.action.quick_capture'),
        equals('quick_capture'),
      );
      expect(
        service.normalizeShortcutId('action_prayer_schedule'),
        equals('prayer_schedule'),
      );
      expect(
        service.normalizeShortcutId('shortcut_new_note'),
        equals('new_note'),
      );
    });

    test('normalizes deep link URIs with path or query params', () {
      expect(
        service.normalizeShortcutId('personalhub://shortcut/quick_capture'),
        equals('quick_capture'),
      );
      expect(
        service.normalizeShortcutId('personalhub://shortcut?id=prayer_schedule'),
        equals('prayer_schedule'),
      );
      expect(
        service.normalizeShortcutId('app://shortcut?shortcut_id=new_transaction'),
        equals('new_transaction'),
      );
      expect(
        service.normalizeShortcutId('app://new_note'),
        equals('new_note'),
      );
    });

    test('normalizes Android Quick Settings Tile triggers', () {
      expect(service.normalizeShortcutId('quick_settings_tile'), equals('quick_capture'));
      expect(service.normalizeShortcutId('quick_settings_capture'), equals('quick_capture'));
      expect(service.normalizeShortcutId('qs_capture'), equals('quick_capture'));
      expect(service.normalizeShortcutId('quick_settings_prayer'), equals('prayer_schedule'));
    });

    test('returns empty string for null, empty, or whitespace', () {
      expect(service.normalizeShortcutId(null), equals(''));
      expect(service.normalizeShortcutId(''), equals(''));
      expect(service.normalizeShortcutId('   '), equals(''));
    });
  });

  group('AppShortcutsService - Route Resolution & Intent Handling', () {
    test('handles "quick_capture" -> tab 0, route "/quick_capture"', () {
      final result = service.handleShortcutIntent('quick_capture');

      expect(result.shortcutId, equals('quick_capture'));
      expect(result.tabIndex, equals(0));
      expect(result.route, equals('/quick_capture'));
      expect(result.payload['action'], equals('quick_capture'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('handles "prayer_schedule" -> tab 0, route "/prayer_schedule"', () {
      final result = service.handleShortcutIntent('prayer_schedule');

      expect(result.shortcutId, equals('prayer_schedule'));
      expect(result.tabIndex, equals(0));
      expect(result.route, equals('/prayer_schedule'));
      expect(result.payload['action'], equals('prayer_schedule'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('handles "new_note" -> tab 1, route "/notes/new"', () {
      final result = service.handleShortcutIntent('new_note');

      expect(result.shortcutId, equals('new_note'));
      expect(result.tabIndex, equals(1)); // Catatan tab
      expect(result.route, equals('/notes/new'));
      expect(result.payload['action'], equals('new_note'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('handles "new_transaction" -> tab 0, route "/finance/new"', () {
      final result = service.handleShortcutIntent('new_transaction');

      expect(result.shortcutId, equals('new_transaction'));
      expect(result.tabIndex, equals(0));
      expect(result.route, equals('/finance/new'));
      expect(result.payload['action'], equals('new_transaction'));
      expect(result.payload['type'], equals('expense'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('handles deep link URI for new_note smoothly', () {
      final result = service.handleShortcutIntent('personalhub://shortcut/new_note');

      expect(result.shortcutId, equals('new_note'));
      expect(result.tabIndex, equals(1));
      expect(result.route, equals('/notes/new'));
      expect(result.isRecognized, isTrue);
      expect(result.isFallback, isFalse);
    });
  });

  group('AppShortcutsService - Fallback Behavior', () {
    test('returns fallback for unknown shortcut ID', () {
      final result = service.handleShortcutIntent('unsupported_action_123');

      expect(result.shortcutId, equals('unsupported_action_123'));
      expect(result.tabIndex, equals(0)); // Beranda
      expect(result.route, equals('/'));
      expect(result.isRecognized, isFalse);
      expect(result.isFallback, isTrue);
      expect(result.payload['action'], equals('none'));
    });

    test('returns fallback for empty or whitespace shortcut ID', () {
      final emptyResult = service.handleShortcutIntent('');
      expect(emptyResult.shortcutId, equals('unknown'));
      expect(emptyResult.tabIndex, equals(0));
      expect(emptyResult.route, equals('/'));
      expect(emptyResult.isRecognized, isFalse);
      expect(emptyResult.isFallback, isTrue);

      final wsResult = service.handleShortcutIntent('    ');
      expect(wsResult.shortcutId, equals('unknown'));
      expect(wsResult.tabIndex, equals(0));
      expect(wsResult.isRecognized, isFalse);
      expect(wsResult.isFallback, isTrue);
    });
  });

  group('App Shortcuts Riverpod Providers', () {
    test('availableShortcutsProvider provides the 4 shortcuts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final list = container.read(availableShortcutsProvider);
      expect(list.length, equals(4));
      expect(list.first.id, equals('quick_capture'));
    });

    test('shortcutByIdProvider resolves matching shortcut and returns null for unknown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final noteShortcut = container.read(shortcutByIdProvider('new_note'));
      expect(noteShortcut?.title, equals('Catatan Baru'));

      final nonExistent = container.read(shortcutByIdProvider('non_existent'));
      expect(nonExistent, isNull);
    });

    test('staticShortcutsProvider and dynamicShortcutsProvider return correct subsets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final staticList = container.read(staticShortcutsProvider);
      expect(staticList.length, equals(3));

      final dynamicList = container.read(dynamicShortcutsProvider);
      expect(dynamicList.length, equals(1));
    });

    test('activeShortcutIntentProvider lifecycle: build, process, select, clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially null
      expect(container.read(activeShortcutIntentProvider), isNull);
      expect(container.read(activeShortcutDestinationTabIndexProvider), isNull);
      expect(container.read(activeShortcutRouteProvider), isNull);

      // Process intent
      final notifier = container.read(activeShortcutIntentProvider.notifier);
      final result = notifier.processShortcutIntent('new_note');

      expect(result.shortcutId, equals('new_note'));
      expect(result.tabIndex, equals(1));
      expect(result.route, equals('/notes/new'));

      // Check reactive providers
      expect(container.read(activeShortcutIntentProvider)?.shortcutId, equals('new_note'));
      expect(container.read(activeShortcutDestinationTabIndexProvider), equals(1));
      expect(container.read(activeShortcutRouteProvider), equals('/notes/new'));

      // Clear intent
      notifier.clear();
      expect(container.read(activeShortcutIntentProvider), isNull);
      expect(container.read(activeShortcutDestinationTabIndexProvider), isNull);
      expect(container.read(activeShortcutRouteProvider), isNull);
    });
  });
}
