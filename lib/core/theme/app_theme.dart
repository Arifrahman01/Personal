import 'package:flutter/material.dart';

/// Material 3 light and dark themes with an emerald-teal and warm neutral palette.
abstract final class AppTheme {
  static const Color _seedEmerald = Color(0xFF0F766E);
  static const Color _warmSandLight = Color(0xFFF7F6F2);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF0E1413);
  static const Color _cardDark = Color(0xFF16201E);
  static const Color _accentAmber = Color(0xFFD97706);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedEmerald,
      brightness: Brightness.light,
      secondary: const Color(0xFF115E59),
      tertiary: _accentAmber,
      surface: _warmSandLight,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _warmSandLight,
      cardColor: _cardLight,
      navBackground: _cardLight,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF14B8A6),
      brightness: Brightness.dark,
      tertiary: const Color(0xFFF59E0B),
      surface: _surfaceDark,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _surfaceDark,
      cardColor: _cardDark,
      navBackground: _cardDark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color navBackground,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
