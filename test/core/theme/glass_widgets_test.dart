import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';

void main() {
  group('RefleqPalette Design Tokens', () {
    test('Tokens match specifications', () {
      expect(RefleqPalette.background, const Color(0xFF0C101D));
      expect(RefleqPalette.surface, const Color(0xFF13192B));
      expect(RefleqPalette.surfaceCard, const Color(0xFF182035));
      expect(RefleqPalette.rosePink, const Color(0xFFFB7185));
      expect(RefleqPalette.skyCyan, const Color(0xFF38BDF8));
      expect(RefleqPalette.lavender, const Color(0xFFA78BFA));
      expect(RefleqPalette.royalViolet, const Color(0xFF8B5CF6));
      expect(RefleqPalette.amberPeach, const Color(0xFFFBBF24));
      expect(RefleqPalette.emeraldMint, const Color(0xFF34D399));

      // Gradient checks
      expect(RefleqPalette.sunsetAurora.colors, const [
        Color(0xFF8B5CF6),
        Color(0xFFF43F5E),
      ]);
      expect(RefleqPalette.sunsetWarm.colors, const [
        Color(0xFFFB7185),
        Color(0xFFFBBF24),
      ]);
      expect(RefleqPalette.lavenderCloud.colors, const [
        Color(0xFF8B5CF6),
        Color(0xFFA78BFA),
      ]);
    });

    test('AppTheme aliases link to RefleqPalette', () {
      expect(AppTheme.canvasObsidian, RefleqPalette.background);
      expect(AppTheme.elevatedSlate, RefleqPalette.surface);
      expect(AppTheme.rosePink, RefleqPalette.rosePink);
      expect(AppTheme.skyCyan, RefleqPalette.skyCyan);
      expect(AppTheme.lavender, RefleqPalette.lavender);
      expect(AppTheme.royalViolet, RefleqPalette.royalViolet);
      expect(AppTheme.amberPeach, RefleqPalette.amberPeach);
      expect(AppTheme.emeraldMint, RefleqPalette.emeraldMint);
      expect(AppTheme.sunsetAurora, RefleqPalette.sunsetAurora);
    });
  });

  group('Glass Widgets Rendering Tests (Dark & Light Mode)', () {
    testWidgets('GlassCard and RefleqColorStripeCard render in Dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: RefleqColorStripeCard(
                stripeColor: RefleqPalette.rosePink,
                child: const Text('Rose Priority Item'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Rose Priority Item'), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(RefleqColorStripeCard), findsOneWidget);
    });

    testWidgets('GlassCard and RefleqColorStripeCard render in Light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: RefleqColorStripeCard(
                stripeColor: RefleqPalette.skyCyan,
                child: const Text('Sky Cyan Meeting Item'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sky Cyan Meeting Item'), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(RefleqColorStripeCard), findsOneWidget);
    });

    testWidgets('GlassBadge renders with icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: GlassBadge(
                label: '14:30 WIB',
                icon: Icons.access_time_rounded,
                backgroundColor: RefleqPalette.amberPeachSurface,
                foregroundColor: RefleqPalette.amberPeach,
              ),
            ),
          ),
        ),
      );

      expect(find.text('14:30 WIB'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    });

    testWidgets('GlassBottomNavBar renders capsule dock with sunset aurora active tab', (tester) async {
      var selectedTab = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: GlassBottomNavBar(
                  selectedIndex: selectedTab,
                  onDestinationSelected: (idx) {
                    setState(() => selectedTab = idx);
                  },
                  destinations: const [
                    GlassNavDestination(
                      label: 'Beranda',
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                    ),
                    GlassNavDestination(
                      label: 'Jadwal',
                      icon: Icons.calendar_today_outlined,
                      selectedIcon: Icons.calendar_month_rounded,
                    ),
                  ],
                ),
                body: const SizedBox(),
              );
            },
          ),
        ),
      );

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Jadwal'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      await tester.tap(find.text('Jadwal'));
      await tester.pumpAndSettle();

      expect(selectedTab, 1);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });

    testWidgets('GlassScaffold renders ambient background mesh', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const GlassScaffold(
            body: Text('Scaffold Content'),
          ),
        ),
      );

      expect(find.text('Scaffold Content'), findsOneWidget);
      expect(find.byType(GlassScaffold), findsOneWidget);
    });
  });
}
