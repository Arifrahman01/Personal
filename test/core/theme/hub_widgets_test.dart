import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/theme/app_theme.dart';

void main() {
  group('HubColors ThemeExtension', () {
    test('HubColors light and dark provide all WCAG AA/AAA tokens', () {
      const light = HubColors.light;
      const dark = HubColors.dark;

      expect(light.canvas, const Color(0xFFF4F2ED));
      expect(light.surfaceCard, const Color(0xFFFFFFFF));
      expect(light.surfaceSubtle, const Color(0xFFECE9E2));
      expect(light.surfaceElevated, const Color(0xFFFFFFFF));
      expect(light.borderHairline, const Color(0xFFE2DDD3));
      expect(light.textPrimary, const Color(0xFF0F172A));
      expect(light.textSecondary, const Color(0xFF57534E));
      expect(light.primary, const Color(0xFF0B6E5B));
      expect(light.primarySoft, const Color(0xFFE1F5EF));
      expect(light.accentGold, const Color(0xFFC98A1A));
      expect(light.accentAi, const Color(0xFF5B5FEF));
      expect(light.success, const Color(0xFF15803D));
      expect(light.warning, const Color(0xFFB45309));
      expect(light.danger, const Color(0xFFE11D48));
      expect(light.info, const Color(0xFF2563EB));

      expect(dark.canvas, const Color(0xFF07090F));
      expect(dark.surfaceCard, const Color(0xFF101521));
      expect(dark.surfaceSubtle, const Color(0xFF182032));
      expect(dark.surfaceElevated, const Color(0xFF141B2B));
      expect(dark.borderHairline, const Color(0xFF243047));
      expect(dark.textPrimary, const Color(0xFFF8FAFC));
      expect(dark.textSecondary, const Color(0xFF94A3B8));
      expect(dark.primary, const Color(0xFF10D9A3));
      expect(dark.primarySoft, const Color(0xFF0C2E29));
      expect(dark.accentGold, const Color(0xFFF5C451));
      expect(dark.accentAi, const Color(0xFF818CF8));
      expect(dark.success, const Color(0xFF34D399));
      expect(dark.warning, const Color(0xFFFBBF24));
      expect(dark.danger, const Color(0xFFFB7185));
      expect(dark.info, const Color(0xFF38BDF8));
    });

    test('HubColors copyWith and lerp operate cleanly', () {
      const light = HubColors.light;
      const dark = HubColors.dark;

      final modified = light.copyWith(canvas: Colors.black);
      expect(modified.canvas, Colors.black);
      expect(modified.primary, light.primary);

      final lerped = light.lerp(dark, 0.5);
      expect(lerped, isNotNull);
      expect(light.lerp(null, 0.5), equals(light));
    });

    testWidgets('HubColors.of(context) retrieves correct theme palette', (tester) async {
      late HubColors extractedLight;
      late HubColors extractedDark;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.light,
          child: Builder(
            builder: (ctx) {
              extractedLight = HubColors.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(extractedLight.canvas, HubColors.light.canvas);

      await tester.pumpWidget(
        Theme(
          data: AppTheme.dark,
          child: Builder(
            builder: (ctx) {
              extractedDark = HubColors.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(extractedDark.canvas, HubColors.dark.canvas);
    });
  });

  group('HubCard', () {
    testWidgets('renders cleanly with 0 BackdropFilter and handles onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HubCard(
              onTap: () => tapped = true,
              child: const Text('Test Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Card Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.text('Test Card Content'));
      expect(tapped, isTrue);
    });
  });

  group('HubScaffold & HubAppBar', () {
    testWidgets('HubScaffold renders with 0 BackdropFilter and custom background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const HubScaffold(
            appBar: HubAppBar(
              titleText: 'Judul Hub',
              subtitleText: 'Subjudul',
            ),
            body: Text('Body Content'),
          ),
        ),
      );

      expect(find.text('Judul Hub'), findsOneWidget);
      expect(find.text('Subjudul'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('HubStatusBadge', () {
    testWidgets('renders label and icon and handles onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HubStatusBadge(
              label: 'Aktif',
              icon: Icons.check_rounded,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Aktif'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Aktif'));
      expect(tapped, isTrue);
    });
  });

  group('HubEmptyState', () {
    testWidgets('renders icon, title, message and CTA button', (tester) async {
      bool ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HubEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Belum ada data',
              message: 'Mulai dengan menambahkan catatan baru.',
              actionLabel: 'Tambah Data',
              onAction: () => ctaPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.text('Mulai dengan menambahkan catatan baru.'), findsOneWidget);
      expect(find.text('Tambah Data'), findsOneWidget);

      await tester.tap(find.text('Tambah Data'));
      expect(ctaPressed, isTrue);
    });
  });

  group('HubTypography', () {
    test('HubTypography.tabular adds tabular figures font feature', () {
      const baseStyle = TextStyle(fontSize: 14);
      final tabularStyle = HubTypography.tabular(baseStyle);

      expect(tabularStyle.fontFeatures, isNotNull);
      expect(
        tabularStyle.fontFeatures!.any(
          (f) => f == const FontFeature.tabularFigures(),
        ),
        isTrue,
      );
    });
  });
}
