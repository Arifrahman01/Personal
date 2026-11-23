import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Holds and updates the active application [ThemeMode].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Updates the active theme mode (`system`, `light`, or `dark`).
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

/// Provides the reactive [ThemeMode] configured in Settings.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Refleq Minimal Aurora Design System Color Tokens & Gradients.
abstract final class RefleqPalette {
  // Canvas & Surfaces (Obsidian depth)
  /// Deep Obsidian Indigo (#0C101D) - Main atmospheric canvas background.
  static const Color background = Color(0xFF0C101D);

  /// Elevated Obsidian Slate (#13192B) - Elevated surfaces and dialogs.
  static const Color surface = Color(0xFF13192B);

  /// Frosted Card Slate (#182035) - Base card slate tone.
  static const Color surfaceCard = Color(0xFF182035);

  /// Frosted Card Glass (rgba(24, 32, 53, 0.72) / #182035 with 72% opacity).
  static final Color surfaceCardGlass = const Color(0xFF182035).withValues(alpha: 0.72);

  /// Specular Glass Border (rgba(255, 255, 255, 0.10) / 10% white).
  static final Color surfaceBorder = Colors.white.withValues(alpha: 0.10);

  // Refleq Aurora Pastel Accents (Refleq Minimal UI)
  /// Rose Pink (#FB7185) - Health, physical activity, high priority.
  static const Color rosePink = Color(0xFFFB7185);
  static const Color rosePinkSurface = Color(0x22FB7185);

  /// Sky Cyan (#38BDF8) - Meetings, client schedule, calendar alerts.
  static const Color skyCyan = Color(0xFF38BDF8);
  static const Color skyCyanSurface = Color(0x2238BDF8);

  /// Lavender (#A78BFA) - Notes, AI copilot, creative tasks.
  static const Color lavender = Color(0xFFA78BFA);
  static const Color lavenderSurface = Color(0x22A78BFA);

  /// Royal Violet (#8B5CF6) - Primary brand anchor & gradient starter.
  static const Color royalViolet = Color(0xFF8B5CF6);
  static const Color royalVioletSurface = Color(0x228B5CF6);

  /// Amber Peach (#FBBF24) - Breaks, warnings, prayer due alerts.
  static const Color amberPeach = Color(0xFFFBBF24);
  static const Color amberPeachSurface = Color(0x22FBBF24);

  /// Emerald Mint (#34D399) - Positive finance, income, habits completed.
  static const Color emeraldMint = Color(0xFF34D399);
  static const Color emeraldMintSurface = Color(0x2234D399);

  // Sunset Aurora Gradients
  /// Sunset Aurora: Royal Violet (#8B5CF6) to Sunset Rose (#F43F5E).
  static const LinearGradient sunsetAurora = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sunset Warm: Rose Pink (#FB7185) to Amber Peach (#FBBF24).
  static const LinearGradient sunsetWarm = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFFBBF24)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Lavender Cloud: Royal Violet (#8B5CF6) to Soft Lavender (#A78BFA).
  static const LinearGradient lavenderCloud = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Material 3 Light Glass and Dark Glass themes with Plus Jakarta Sans typography.
abstract final class AppTheme {
  // Aliases for quick access to Refleq tokens
  static const Color canvasObsidian = RefleqPalette.background;
  static const Color elevatedSlate = RefleqPalette.surface;
  static final Color frostedCardGlass = RefleqPalette.surfaceCardGlass;
  static final Color glassBorderColor = RefleqPalette.surfaceBorder;

  static const Color rosePink = RefleqPalette.rosePink;
  static const Color skyCyan = RefleqPalette.skyCyan;
  static const Color lavender = RefleqPalette.lavender;
  static const Color royalViolet = RefleqPalette.royalViolet;
  static const Color amberPeach = RefleqPalette.amberPeach;
  static const Color emeraldMint = RefleqPalette.emeraldMint;

  static const LinearGradient sunsetAurora = RefleqPalette.sunsetAurora;
  static const LinearGradient sunsetWarm = RefleqPalette.sunsetWarm;
  static const LinearGradient lavenderCloud = RefleqPalette.lavenderCloud;

  static const Color _warmSandLight = Color(0xFFEFF6F5);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: RefleqPalette.royalViolet,
      brightness: Brightness.light,
      primary: RefleqPalette.royalViolet,
      secondary: RefleqPalette.skyCyan,
      tertiary: RefleqPalette.rosePink,
      surface: _warmSandLight,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _warmSandLight,
      cardColor: Colors.white.withValues(alpha: 0.72),
      navBackground: Colors.white.withValues(alpha: 0.80),
      glassBorder: Colors.white.withValues(alpha: 0.85),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: RefleqPalette.royalViolet,
      brightness: Brightness.dark,
      primary: RefleqPalette.royalViolet,
      secondary: RefleqPalette.skyCyan,
      tertiary: RefleqPalette.rosePink,
      surface: RefleqPalette.surface,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: RefleqPalette.background,
      cardColor: const Color(0xFF182035).withValues(alpha: 0.72),
      navBackground: RefleqPalette.surface.withValues(alpha: 0.92),
      glassBorder: Colors.white.withValues(alpha: 0.10),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color navBackground,
    required Color glassBorder,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
    );

    final textTheme = _safePlusJakartaTextTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: glassBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.brightness == Brightness.dark
            ? RefleqPalette.surface.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: glassBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.brightness == Brightness.dark
            ? RefleqPalette.surface.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: cardColor,
        side: BorderSide(color: glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  static TextTheme _safePlusJakartaTextTheme(
    TextTheme base,
    ColorScheme scheme,
  ) {
    try {
      return GoogleFonts.plusJakartaSansTextTheme(base).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
    } catch (_) {
      return base.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
    }
  }
}
