import 'package:flutter/material.dart';

/// WCAG AA/AAA compliant theme extension color tokens for Personal Hub v4.0 ("Sanctuary Luxe").
class HubColors extends ThemeExtension<HubColors> {
  final Color canvas;
  final Color surfaceCard;
  final Color surfaceSubtle;
  final Color surfaceElevated;
  final Color borderHairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primarySoft;
  final Color accentGold;
  final Color accentAi;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const HubColors({
    required this.canvas,
    required this.surfaceCard,
    required this.surfaceSubtle,
    this.surfaceElevated = const Color(0xFFFFFFFF),
    required this.borderHairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primarySoft,
    this.accentGold = const Color(0xFFC98A1A),
    this.accentAi = const Color(0xFF5B5FEF),
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Light theme token palette (Warm Editorial Alabaster + Sovereign Emerald + Burnished Gold).
  static const HubColors light = HubColors(
    canvas: Color(0xFFF4F2ED),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFECE9E2),
    surfaceElevated: Color(0xFFFFFFFF),
    borderHairline: Color(0xFFE2DDD3),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF57534E),
    primary: Color(0xFF0B6E5B),
    primarySoft: Color(0xFFE1F5EF),
    accentGold: Color(0xFFC98A1A),
    accentAi: Color(0xFF5B5FEF),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFE11D48),
    info: Color(0xFF2563EB),
  );

  /// Dark theme token palette (Deep Obsidian Velvet + Electric Emerald Jade + Champagne Gold).
  static const HubColors dark = HubColors(
    canvas: Color(0xFF07090F),
    surfaceCard: Color(0xFF101521),
    surfaceSubtle: Color(0xFF182032),
    surfaceElevated: Color(0xFF141B2B),
    borderHairline: Color(0xFF243047),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    primary: Color(0xFF10D9A3),
    primarySoft: Color(0xFF0C2E29),
    accentGold: Color(0xFFF5C451),
    accentAi: Color(0xFF818CF8),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    info: Color(0xFF38BDF8),
  );

  /// Retrieves the active [HubColors] from the current [BuildContext].
  static HubColors of(BuildContext context) {
    return Theme.of(context).extension<HubColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  HubColors copyWith({
    Color? canvas,
    Color? surfaceCard,
    Color? surfaceSubtle,
    Color? surfaceElevated,
    Color? borderHairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? primarySoft,
    Color? accentGold,
    Color? accentAi,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return HubColors(
      canvas: canvas ?? this.canvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      borderHairline: borderHairline ?? this.borderHairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accentGold: accentGold ?? this.accentGold,
      accentAi: accentAi ?? this.accentAi,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  HubColors lerp(ThemeExtension<HubColors>? other, double t) {
    if (other is! HubColors) return this;
    return HubColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      surfaceSubtle:
          Color.lerp(surfaceSubtle, other.surfaceSubtle, t) ?? surfaceSubtle,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      borderHairline:
          Color.lerp(borderHairline, other.borderHairline, t) ?? borderHairline,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      accentGold: Color.lerp(accentGold, other.accentGold, t) ?? accentGold,
      accentAi: Color.lerp(accentAi, other.accentAi, t) ?? accentAi,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

/// Design tokens for Personal Hub v4.0 ("Sanctuary Luxe").
/// High contrast Material 3 tactile system with WCAG AA/AAA compliance.
abstract final class AppTokens {
  // Brand Sovereign Emerald & Champagne Gold
  static const Color primaryLight = Color(0xFF0B6E5B);
  static const Color primaryDark = Color(0xFF10D9A3);
  static const Color primarySoftLight = Color(0xFFE1F5EF);
  static const Color primarySoftDark = Color(0xFF0C2E29);

  static const Color accentGoldLight = Color(0xFFC98A1A);
  static const Color accentGoldDark = Color(0xFFF5C451);

  static const Color accentAiLight = Color(0xFF5B5FEF);
  static const Color accentAiDark = Color(0xFF818CF8);

  // Surfaces Light (Warm Alabaster)
  static const Color canvasLight = Color(0xFFF4F2ED);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFECE9E2);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF57534E);
  static const Color borderLight = Color(0xFFE2DDD3);

  // Surfaces Dark (Obsidian Velvet)
  static const Color canvasDark = Color(0xFF07090F);
  static const Color cardDark = Color(0xFF101521);
  static const Color surfaceSubtleDark = Color(0xFF182032);
  static const Color surfaceElevatedDark = Color(0xFF141B2B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF243047);

  // Semantics
  static const Color successLight = Color(0xFF15803D);
  static const Color successDark = Color(0xFF34D399);

  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color errorLight = Color(0xFFE11D48);
  static const Color errorDark = Color(0xFFFB7185);

  static const Color dangerLight = Color(0xFFE11D48);
  static const Color dangerDark = Color(0xFFFB7185);

  static const Color infoLight = Color(0xFF2563EB);
  static const Color infoDark = Color(0xFF38BDF8);

  // Dynamic getters delegating to HubColors
  static Color primary(BuildContext context) => HubColors.of(context).primary;
  static Color primarySoft(BuildContext context) =>
      HubColors.of(context).primarySoft;
  static Color gold(BuildContext context) => HubColors.of(context).accentGold;
  static Color ai(BuildContext context) => HubColors.of(context).accentAi;
  static Color canvas(BuildContext context) => HubColors.of(context).canvas;
  static Color card(BuildContext context) => HubColors.of(context).surfaceCard;
  static Color surfaceSubtle(BuildContext context) =>
      HubColors.of(context).surfaceSubtle;
  static Color surfaceElevated(BuildContext context) =>
      HubColors.of(context).surfaceElevated;
  static Color textPrimary(BuildContext context) =>
      HubColors.of(context).textPrimary;
  static Color textSecondary(BuildContext context) =>
      HubColors.of(context).textSecondary;
  static Color border(BuildContext context) =>
      HubColors.of(context).borderHairline;
  static Color borderHairline(BuildContext context) =>
      HubColors.of(context).borderHairline;
  static Color success(BuildContext context) => HubColors.of(context).success;
  static Color warning(BuildContext context) => HubColors.of(context).warning;
  static Color error(BuildContext context) => HubColors.of(context).danger;
  static Color danger(BuildContext context) => HubColors.of(context).danger;
  static Color info(BuildContext context) => HubColors.of(context).info;
}

/// 5-step radius scale for Sanctuary Luxe tactile components.
abstract final class HubRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 18.0;
  static const double lg = 24.0;
  static const double pill = 999.0;

  static BorderRadius get rXs => BorderRadius.circular(xs);
  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rPill => BorderRadius.circular(pill);
}

/// Spacing scale in logical pixels (Sanctuary Luxe v4.0 standard).
abstract final class HubSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

/// Typography helper with tabular figure numbers.
abstract final class HubTypography {
  /// Ensures dynamic numbers (currency, timers, percentages) use tabular figures.
  static TextStyle tabular(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFeatures: [
        const FontFeature.tabularFigures(),
        ...?baseStyle.fontFeatures,
      ],
    );
  }
}
