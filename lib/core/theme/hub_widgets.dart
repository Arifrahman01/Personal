import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

/// Reusable tactile card component built on Material 3 [Card.outlined].
/// Uses solid tonal surfaces with 0 BackdropFilter.
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

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      color: cardBg,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border, width: borderWidth),
      ),
      child: onTap != null
          ? InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
  }
}

/// Clean Material 3 scaffold with SafeArea support and 0 BackdropFilter.
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

/// Material 3 AppBar wrapper with consistent typography and optional subtitle.
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
    final theme = Theme.of(context);
    final colors = HubColors.of(context);

    Widget? effectiveTitle;
    if (title is Widget) {
      effectiveTitle = title as Widget;
    } else if (title is String) {
      effectiveTitle = Text(
        title as String,
        style: theme.textTheme.titleLarge?.copyWith(
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              subtitleText!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        );
      } else {
        effectiveTitle = Text(
          titleText!,
          style: theme.textTheme.titleLarge?.copyWith(
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

/// Section header using Material 3 [TextTheme.labelLarge] and optional trailing widget.
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

/// Soft tonal status badge built on Material 3 [Material] with [StadiumBorder].
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
    final textTheme = Theme.of(context).textTheme;
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

    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );

    return Material(
      type: MaterialType.canvas,
      color: bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: inner,
            )
          : inner,
    );
  }
}

/// Friendly, uncluttered empty state component using M3 [ColorScheme] and [FilledButton].
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: HubSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: HubSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
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
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact stat pill or filter tag built on Material 3 [FilterChip].
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
    final textTheme = Theme.of(context).textTheme;
    final primary = color ?? colors.primary;
    final bg = isSelected ? primary.withValues(alpha: 0.15) : colors.surfaceCard;
    final border = isSelected ? primary : colors.borderHairline;
    final textColor = isSelected ? primary : colors.textPrimary;

    return FilterChip(
      label: Text(
        label,
        style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
      avatar: icon != null ? Icon(icon, size: 16, color: textColor) : null,
      selected: isSelected,
      showCheckmark: false,
      color: WidgetStatePropertyAll(bg),
      side: BorderSide(color: border, width: 1),
      shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onSelected: onTap != null ? (_) => onTap!() : null,
    );
  }
}
