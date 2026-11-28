import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/storage/app_preferences_repository.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

export 'package:personal_hub/core/theme/app_tokens.dart';
export 'package:personal_hub/core/theme/hub_widgets.dart';
export 'package:personal_hub/core/theme/luxe_components.dart';

/// Holds and updates the active application [ThemeMode].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Updates the active theme mode (`system`, `light`, or `dark`).
  void setThemeMode(ThemeMode mode) {
    state = mode;
    unawaited(
      ref
          .read(appPreferencesStoreProvider)
          .setString(AppPreferenceKeys.themeMode, mode.name)
          .catchError((_) {}),
    );
  }
}

/// Provides the reactive [ThemeMode] configured in Settings.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Material 3 Light and Dark themes for Personal Hub v4.0 ("Sanctuary Luxe")
/// with Plus Jakarta Sans typography.
abstract final class AppTheme {
  /// Font family name declared natively in `pubspec.yaml`.
  static const String fontFamily = 'Plus Jakarta Sans';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryLight,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      primary: AppTokens.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: AppTokens.primarySoftLight,
      onPrimaryContainer: const Color(0xFF064E3B),
      secondary: const Color(0xFF1F4E5F),
      secondaryContainer: const Color(0xFFE5EDF0),
      tertiary: AppTokens.accentGoldLight,
      surface: AppTokens.cardLight,
      onSurface: AppTokens.textPrimaryLight,
      onSurfaceVariant: AppTokens.textSecondaryLight,
      surfaceContainerLowest: AppTokens.canvasLight,
      surfaceContainerLow: const Color(0xFFFAF8F4),
      surfaceContainer: AppTokens.surfaceSubtleLight,
      surfaceContainerHigh: const Color(0xFFE7E2D9),
      surfaceContainerHighest: const Color(0xFFDDD7CC),
      outlineVariant: AppTokens.borderLight,
      error: AppTokens.errorLight,
    );

    return _buildTheme(
      scheme: scheme,
      hubColors: HubColors.light,
      scaffoldBackground: AppTokens.canvasLight,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryDark,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      primary: AppTokens.primaryDark,
      onPrimary: const Color(0xFF04221B),
      primaryContainer: AppTokens.primarySoftDark,
      onPrimaryContainer: const Color(0xFF6EE7B7),
      secondary: const Color(0xFF7DD3FC),
      secondaryContainer: const Color(0xFF172538),
      tertiary: AppTokens.accentGoldDark,
      surface: AppTokens.cardDark,
      onSurface: AppTokens.textPrimaryDark,
      onSurfaceVariant: AppTokens.textSecondaryDark,
      surfaceContainerLowest: AppTokens.canvasDark,
      surfaceContainerLow: const Color(0xFF0C111C),
      surfaceContainer: AppTokens.surfaceSubtleDark,
      surfaceContainerHigh: const Color(0xFF1D263B),
      surfaceContainerHighest: const Color(0xFF243047),
      outlineVariant: AppTokens.borderDark,
      error: AppTokens.errorDark,
    );

    return _buildTheme(
      scheme: scheme,
      hubColors: HubColors.dark,
      scaffoldBackground: AppTokens.canvasDark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required HubColors hubColors,
    required Color scaffoldBackground,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [hubColors],
    );

    final textTheme = _safePlusJakartaTextTheme(base.textTheme, scheme);

    return base.copyWith(
      extensions: [hubColors],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: hubColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: hubColors.borderHairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
        backgroundColor: hubColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(hubColors.surfaceCard),
        side: WidgetStatePropertyAll(
          BorderSide(color: hubColors.borderHairline),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: hubColors.borderHairline),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: hubColors.surfaceCard,
        selectedColor: hubColors.primarySoft,
        side: BorderSide(color: hubColors.borderHairline),
        shape: const StadiumBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: hubColors.borderHairline,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: hubColors.primary.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? hubColors.primary : hubColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: hubColors.primary, size: 22);
          }
          return IconThemeData(color: hubColors.textSecondary, size: 22);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: hubColors.primary.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: hubColors.primary, size: 22),
        unselectedIconTheme: IconThemeData(color: hubColors.textSecondary, size: 22),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: hubColors.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: hubColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(hubColors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: hubColors.borderHairline),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(hubColors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: hubColors.borderHairline),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: hubColors.surfaceSubtle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: hubColors.borderHairline),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: hubColors.surfaceSubtle.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: hubColors.borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: hubColors.borderHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
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
          side: BorderSide(color: hubColors.borderHairline),
        ),
      ),
    );
  }

  static TextTheme _safePlusJakartaTextTheme(
    TextTheme base,
    ColorScheme scheme,
  ) {
    return base.apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }
}
