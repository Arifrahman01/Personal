import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

/// Reusable tactile card component for Personal Hub v3.0 Calm Clarity design.
/// Replaces high-cost GPU BackdropFilter on scroll lists with solid tonal surfaces.
class HubCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const HubCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HubSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final cardBg = backgroundColor ?? colors.surfaceCard;
    final border = borderColor ?? colors.borderHairline;
    final radius = borderRadius ?? HubRadius.rMd;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Clean tactile scaffold replacing GlassScaffold.
/// Safe by default, uses solid canvas background with 0 BackdropFilter and 0 neon orbs.
class HubScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool safeArea;
  final EdgeInsetsGeometry? padding;
  final bool? resizeToAvoidBottomInset;

  const HubScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeArea = true,
    this.padding,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final canvasColor = backgroundColor ?? HubColors.of(context).canvas;

    Widget? content = body;
    if (content != null && padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (content != null && safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: appBar,
      body: content,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// Tactile AppBar with consistent styling, 0 blur, and minimum 48x48dp action targets.
class HubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title;
  final String? titleText;
  final String? subtitleText;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final double elevation;
  final PreferredSizeWidget? bottom;

  const HubAppBar({
    super.key,
    this.title,
    this.titleText,
    this.subtitleText,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor,
    this.elevation = 0,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);

    Widget? effectiveTitle;
    if (title is Widget) {
      effectiveTitle = title as Widget;
    } else if (title is String) {
      effectiveTitle = Text(
        title as String,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      );
    } else if (titleText != null) {
      if (subtitleText != null && subtitleText!.isNotEmpty) {
        effectiveTitle = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              titleText!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              subtitleText!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        );
      } else {
        effectiveTitle = Text(
          titleText!,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        );
      }
    }

    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: elevation,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: effectiveTitle,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Section header with label and optional action.
class HubSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const HubSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      horizontal: HubSpacing.sm,
      vertical: HubSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Semantic badge type variants for [HubStatusBadge].
enum HubBadgeType {
  primary,
  success,
  warning,
  danger,
  info,
}

/// Soft tonal status badge with WCAG AA/AAA compliance.
class HubStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;
  final HubBadgeType? type;
  final VoidCallback? onTap;

  const HubStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
    this.type,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final primary = color ??
        (switch (type) {
          HubBadgeType.primary => colors.primary,
          HubBadgeType.success => colors.success,
          HubBadgeType.warning => colors.warning,
          HubBadgeType.danger => colors.danger,
          HubBadgeType.info => colors.info,
          null => colors.primary,
        });
    final bg = backgroundColor ?? primary.withValues(alpha: 0.12);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: HubRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: HubRadius.rPill,
        child: content,
      );
    }

    return content;
  }
}

/// Friendly, uncluttered empty state component.
class HubEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  const HubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HubSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: HubSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: HubSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: HubSpacing.lg),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: HubSpacing.lg),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact stat pill or tag.
class HubPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isSelected;

  const HubPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final primary = color ?? colors.primary;
    final bg = isSelected ? primary.withValues(alpha: 0.15) : colors.surfaceCard;
    final border = isSelected ? primary : colors.borderHairline;
    final textColor = isSelected ? primary : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: HubRadius.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: HubRadius.rPill,
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
