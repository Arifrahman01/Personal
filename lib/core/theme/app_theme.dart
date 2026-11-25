import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

export 'package:personal_hub/core/theme/app_tokens.dart';
export 'package:personal_hub/core/theme/hub_widgets.dart';

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

/// Material 3 Light and Dark themes with Plus Jakarta Sans typography.
abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryLight,
      brightness: Brightness.light,
      primary: AppTokens.primaryLight,
      onPrimary: AppTokens.onPrimaryLight,
      primaryContainer: AppTokens.primarySoftLight,
      onPrimaryContainer: AppTokens.primaryLight,
      error: AppTokens.errorLight,
      onError: AppTokens.onPrimaryLight,
      surface: AppTokens.cardLight,
      surfaceContainerLowest: AppTokens.canvasLight,
      surfaceContainerHighest: AppTokens.surfaceSubtleLight,
      onSurface: AppTokens.textPrimaryLight,
      onSurfaceVariant: AppTokens.textSecondaryLight,
      outlineVariant: AppTokens.borderLight,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: AppTokens.canvasLight,
      cardColor: AppTokens.cardLight,
      navBackground: AppTokens.cardLight,
      subtleSurface: AppTokens.surfaceSubtleLight,
      borderColor: AppTokens.borderLight,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryDark,
      brightness: Brightness.dark,
      primary: AppTokens.primaryDark,
      onPrimary: AppTokens.onPrimaryDark,
      primaryContainer: AppTokens.primarySoftDark,
      onPrimaryContainer: AppTokens.primaryDark,
      error: AppTokens.errorDark,
      onError: AppTokens.canvasDark,
      surface: AppTokens.cardDark,
      surfaceContainerLowest: AppTokens.canvasDark,
      surfaceContainerHighest: AppTokens.surfaceSubtleDark,
      onSurface: AppTokens.textPrimaryDark,
      onSurfaceVariant: AppTokens.textSecondaryDark,
      outlineVariant: AppTokens.borderDark,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: AppTokens.canvasDark,
      cardColor: AppTokens.cardDark,
      navBackground: AppTokens.cardDark,
      subtleSurface: AppTokens.surfaceSubtleDark,
      borderColor: AppTokens.borderDark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color navBackground,
    required Color subtleSurface,
    required Color borderColor,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [
        scheme.brightness == Brightness.dark ? HubColors.dark : HubColors.light,
      ],
    );

    final textTheme = _safePlusJakartaTextTheme(base.textTheme, scheme);

    return base.copyWith(
      extensions: [
        scheme.brightness == Brightness.dark ? HubColors.dark : HubColors.light,
      ],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: HubRadius.rMd,
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: cardColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return (textTheme.labelSmall ?? const TextStyle()).copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            overflow: TextOverflow.ellipsis,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtleSurface,
        border: OutlineInputBorder(
          borderRadius: HubRadius.rSm,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HubRadius.rSm,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HubRadius.rSm,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: HubRadius.rSm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: HubRadius.rSm,
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
