import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';

void main() {
  testWidgets(
    'SettingsScreen displays modular 6-row hub with human-friendly wording',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tampilan Antarmuka
      expect(find.text('Tampilan Antarmuka'), findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);
      expect(find.text('Terang'), findsOneWidget);
      expect(find.text('Gelap'), findsOneWidget);

      // 2. Tampilkan di Beranda
      expect(find.text('Tampilkan di Beranda'), findsOneWidget);

      // 3. Asisten AI
      expect(find.text('Asisten AI'), findsOneWidget);

      // 4. Keamanan & Brankas
      expect(find.text('Keamanan & Brankas'), findsOneWidget);

      // 5. Jadwal Sholat & Adzan
      expect(find.text('Jadwal Sholat & Adzan'), findsOneWidget);

      // 6. Backup & Sinkronisasi
      expect(find.text('Backup & Sinkronisasi'), findsOneWidget);

      // HUMAN FRIENDLY WORDING CHECKS:
      // Must contain human-friendly retention summary:
      expect(
        find.textContaining('7 Harian • 4 Mingguan • 3 Bulanan'),
        findsOneWidget,
      );

      // FORBIDDEN TECHNICAL JARGON CHECKS:
      expect(find.textContaining('Son cycle'), findsNothing);
      expect(find.textContaining('Father cycle'), findsNothing);
      expect(find.textContaining('Grandfather'), findsNothing);
    },
  );

  testWidgets(
    'SettingsScreen opens Tampilkan di Beranda sheet and toggles module visibility',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state: all modules are visible (true)
      var prefs = container.read(homeModulePreferencesProvider);
      expect(prefs.showPrayer, isTrue);
      expect(prefs.showFocus, isTrue);
      expect(prefs.showFinance, isTrue);
      expect(prefs.showHabits, isTrue);
      expect(prefs.showAiBriefing, isTrue);

      // Tap on 'Tampilkan di Beranda' row
      await tester.tap(find.text('Tampilkan di Beranda'));
      await tester.pumpAndSettle();

      // Verify the bottom sheet opened
      expect(
        find.text('Pilih modul kartu yang ingin Anda tampilkan pada halaman Hari Ini.'),
        findsOneWidget,
      );

      // Find all Switch widgets
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(5));

      // Toggle first switch (Jadwal Sholat)
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      prefs = container.read(homeModulePreferencesProvider);
      expect(prefs.showPrayer, isFalse);

      // Toggle third switch (Saldo Bulan Ini)
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      prefs = container.read(homeModulePreferencesProvider);
      expect(prefs.showFinance, isFalse);
    },
  );

  testWidgets(
    'SettingsScreen switches theme mode',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.system);

      // Tap 'Gelap'
      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Tap 'Terang'
      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.light);
    },
  );
}
