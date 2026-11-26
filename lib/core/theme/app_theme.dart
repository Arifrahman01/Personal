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
  static final Color surfaceCardGlass =
      const Color(0xFF182035).withValues(alpha: 0.72);

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

/// Material 3 Light and Dark themes with Plus Jakarta Sans typography.
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

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryLight,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      primary: AppTokens.primaryLight,
      surface: AppTokens.cardLight,
      surfaceContainerLowest: AppTokens.canvasLight,
      surfaceContainerLow: const Color(0xFFF8FAFC),
      surfaceContainer: AppTokens.surfaceSubtleLight,
      surfaceContainerHigh: const Color(0xFFE8ECEF),
      surfaceContainerHighest: const Color(0xFFE0E5EB),
      outlineVariant: AppTokens.borderLight,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: AppTokens.canvasLight,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryDark,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      primary: AppTokens.primaryDark,
      surface: AppTokens.cardDark,
      surfaceContainerLowest: AppTokens.canvasDark,
      surfaceContainerLow: const Color(0xFF131820),
      surfaceContainer: AppTokens.surfaceSubtleDark,
      surfaceContainerHigh: const Color(0xFF222A36),
      surfaceContainerHighest: const Color(0xFF2B3340),
      outlineVariant: AppTokens.borderDark,
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: AppTokens.canvasDark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        year2023: false,
      ),
      sliderTheme: const SliderThemeData(
        year2023: false,
      ),
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
        color: scheme.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
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
          side: BorderSide(color: scheme.outlineVariant),
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
