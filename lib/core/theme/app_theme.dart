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

/// Material 3 Light Glass and Dark Glass themes with Plus Jakarta Sans typography.
abstract final class AppTheme {
  static const Color _seedEmerald = Color(0xFF0F766E);
  static const Color _warmSandLight = Color(0xFFEFF6F5);
  static const Color _surfaceDark = Color(0xFF081214);
  static const Color _accentAmber = Color(0xFFD97706);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedEmerald,
      brightness: Brightness.light,
      secondary: const Color(0xFF0D9488),
      tertiary: _accentAmber,
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
      seedColor: const Color(0xFF14B8A6),
      brightness: Brightness.dark,
      secondary: const Color(0xFF2DD4BF),
      tertiary: const Color(0xFFF59E0B),
      surface: _surfaceDark,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _surfaceDark,
      cardColor: const Color(0xFF122123).withValues(alpha: 0.66),
      navBackground: const Color(0xFF0E1C1E).withValues(alpha: 0.80),
      glassBorder: Colors.white.withValues(alpha: 0.14),
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
            ? const Color(0xFF102022).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: glassBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.brightness == Brightness.dark
            ? const Color(0xFF0E1C1E).withValues(alpha: 0.96)
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
