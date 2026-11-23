import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Wraps a tab [FloatingActionButton] so it clears an ancestor [GlassBottomNavBar]
/// without adding extra bottom inset when the screen is rendered standalone.
class GlassFabAnchor extends StatelessWidget {
  const GlassFabAnchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final extraBottom = math.max(0.0, media.padding.bottom - media.viewPadding.bottom);
    if (extraBottom <= 0) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: extraBottom),
      child: child,
    );
  }
}

/// Marks whether an ancestor [GlassScaffold] has already painted the ambient canvas.
class _GlassCanvasScope extends InheritedWidget {
  const _GlassCanvasScope({required super.child});

  static bool hasAncestor(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_GlassCanvasScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_GlassCanvasScope oldWidget) => false;
}

/// Ambient emerald/teal/indigo mesh gradient backdrop paired with a transparent [Scaffold].
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final hasCanvas = _GlassCanvasScope.hasAncestor(context);
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );

    if (hasCanvas) {
      return scaffold;
    }

    return _GlassCanvasScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientGlassCanvas(),
          scaffold,
        ],
      ),
    );
  }
}

class _AmbientGlassCanvas extends StatelessWidget {
  const _AmbientGlassCanvas();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF061114),
              Color(0xFF0A1B1D),
              Color(0xFF0D1422),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF6F4),
              Color(0xFFF3F8F7),
              Color(0xFFEEF1FA),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: baseGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -110,
            left: -70,
            child: _GlowOrb(
              size: 320,
              color: (isDark
                      ? const Color(0xFF14B8A6)
                      : const Color(0xFF2DD4BF))
                  .withValues(alpha: isDark ? 0.22 : 0.20),
            ),
          ),
          Positioned(
            top: 150,
            right: -95,
            child: _GlowOrb(
              size: 290,
              color: (isDark
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF38BDF8))
                  .withValues(alpha: isDark ? 0.16 : 0.16),
            ),
          ),
          Positioned(
            bottom: -120,
            left: 20,
            child: _GlowOrb(
              size: 340,
              color: (isDark
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF818CF8))
                  .withValues(alpha: isDark ? 0.18 : 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.35),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted glassmorphic card with [BackdropFilter] blur, translucent fill, and crisp 1px border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.tintColor,
    this.blurSigma = 16,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final double blurSigma;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(20);

    final effectiveTint =
        tintColor ??
        (isDark
            ? const Color(0xFF132224).withValues(alpha: 0.62)
            : Colors.white.withValues(alpha: 0.68));
    final effectiveBorder =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.82));

    Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    content = Material(
      type: MaterialType.transparency,
      child: onTap != null
          ? InkWell(borderRadius: radius, onTap: onTap, child: content)
          : content,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: effectiveTint,
              borderRadius: radius,
              border: Border.all(color: effectiveBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveTint.withValues(
                    alpha: (effectiveTint.a + 0.08).clamp(0.0, 1.0),
                  ),
                  effectiveTint,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Frosted translucent top [AppBar] for glassmorphic screens.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A1618).withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.60),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: title,
            actions: actions,
            leading: leading,
            bottom: bottom,
            centerTitle: centerTitle,
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
        ),
      ),
    );
  }
}

/// Navigation item configuration for [GlassBottomNavBar].
class GlassNavDestination {
  const GlassNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Floating frosted-glass bottom navigation bar.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(26);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0E1D1F).withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.78),
                borderRadius: radius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.90),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _GlassNavItem(
                          destination: destinations[i],
                          isSelected: i == selectedIndex,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.24 : 0.14,
    );
    final fgColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 20,
                color: fgColor,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted status pill badge.
class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        backgroundColor ??
        theme.colorScheme.primaryContainer.withValues(alpha: 0.72);
    final fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final border = borderColor ?? fg.withValues(alpha: 0.16);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted square/rounded icon tile for quick-hub shortcuts and feature headers.
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.primary;
    final bg = backgroundColor ?? fg.withValues(alpha: 0.14);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}
