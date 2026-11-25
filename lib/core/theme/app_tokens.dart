import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// WCAG AA/AAA compliant theme extension color tokens for Personal Hub v3.0 ("Calm Clarity").
class HubColors extends ThemeExtension<HubColors> {
  final Color canvas;
  final Color surfaceCard;
  final Color surfaceSubtle;
  final Color borderHairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const HubColors({
    required this.canvas,
    required this.surfaceCard,
    required this.surfaceSubtle,
    required this.borderHairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Light theme token palette (WCAG AA/AAA).
  static const HubColors light = HubColors(
    canvas: Color(0xFFF6F7F9),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEEF1F4),
    borderHairline: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    primary: Color(0xFF0D6E66),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE6F4F2),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2626),
    info: Color(0xFF1D4ED8),
  );

  /// Dark theme token palette (WCAG AA/AAA).
  static const HubColors dark = HubColors(
    canvas: Color(0xFF0D1117),
    surfaceCard: Color(0xFF161B22),
    surfaceSubtle: Color(0xFF1E2530),
    borderHairline: Color(0xFF2B3340),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    primary: Color(0xFF2DD4BF),
    onPrimary: Color(0xFF062825),
    primarySoft: Color(0xFF123532),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
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
    Color? borderHairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return HubColors(
      canvas: canvas ?? this.canvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderHairline: borderHairline ?? this.borderHairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
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
      borderHairline:
          Color.lerp(borderHairline, other.borderHairline, t) ?? borderHairline,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

/// Design tokens for Personal Hub v3.0 ("Calm Clarity").
/// High contrast Material 3 tactile system with WCAG AA/AAA compliance.
abstract final class AppTokens {
  // Brand Emerald-Teal
  static const Color primaryLight = Color(0xFF0D6E66);
  static const Color primaryDark = Color(0xFF2DD4BF);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF062825);
  static const Color primarySoftLight = Color(0xFFE6F4F2);
  static const Color primarySoftDark = Color(0xFF123532);

  // Surfaces Light
  static const Color canvasLight = Color(0xFFF6F7F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFEEF1F4);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF4B5563);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Surfaces Dark
  static const Color canvasDark = Color(0xFF0D1117);
  static const Color cardDark = Color(0xFF161B22);
  static const Color surfaceSubtleDark = Color(0xFF1E2530);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF2B3340);

  // Semantics
  static const Color successLight = Color(0xFF15803D);
  static const Color successDark = Color(0xFF34D399);

  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);

  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);

  static const Color infoLight = Color(0xFF1D4ED8);
  static const Color infoDark = Color(0xFF60A5FA);

  // Dynamic getters delegating to HubColors
  static Color primary(BuildContext context) => HubColors.of(context).primary;
  static Color onPrimary(BuildContext context) =>
      HubColors.of(context).onPrimary;
  static Color primarySoft(BuildContext context) =>
      HubColors.of(context).primarySoft;
  static Color canvas(BuildContext context) => HubColors.of(context).canvas;
  static Color card(BuildContext context) => HubColors.of(context).surfaceCard;
  static Color surfaceSubtle(BuildContext context) =>
      HubColors.of(context).surfaceSubtle;
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

  /// Returns a WCAG AA (>= 4.5:1) foreground color for text/icons placed on
  /// soft tonal badge surfaces (10%-15% accent fill over light/dark cards).
  static Color tonalForeground(BuildContext context, Color accent) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return accent;
    }
    if (accent == warningLight) return const Color(0xFF92400E);
    if (accent == successLight) return const Color(0xFF166534);
    if (accent == dangerLight) return const Color(0xFFB91C1C);
    return accent;
  }
}

/// 5-step radius scale for tactile components.
abstract final class HubRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double pill = 999.0;

  static BorderRadius get rXs => BorderRadius.circular(xs);
  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rPill => BorderRadius.circular(pill);
}

/// Spacing scale in logical pixels (Calm Clarity v3.0 standard).
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

/// Safely formats [dateTime] in Indonesian (`id_ID`), falling back cleanly
/// when locale symbol data has not been initialized (e.g., isolated unit tests).
String safeFormatIndonesianDate(DateTime dateTime, String pattern) {
  final local = dateTime.toLocal();
  try {
    return DateFormat(pattern, 'id_ID').format(local);
  } catch (_) {
    return _fallbackIndonesianDateFormat(local, pattern);
  }
}

String _fallbackIndonesianDateFormat(DateTime local, String pattern) {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  final dayName = weekdays[local.weekday - 1];
  final shortMonth = shortMonths[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return switch (pattern) {
    'EEEE, d MMM yyyy' => '$dayName, ${local.day} $shortMonth ${local.year}',
    'd MMM yyyy' => '${local.day} $shortMonth ${local.year}',
    'd MMM, HH:mm' => '${local.day} $shortMonth, $hour:$minute',
    'MMM' => shortMonth,
    'HH:mm' => '$hour:$minute',
    _ => DateFormat(pattern).format(local),
  };
}
