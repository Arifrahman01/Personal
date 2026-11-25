import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';

/// Clean linear percent progress bar for Calm Clarity design system.
class LinearPercentBar extends StatelessWidget {
  const LinearPercentBar({
    super.key,
    required this.value,
    this.color,
    this.gradient,
    this.backgroundColor,
    this.height = 6.0,
  });

  final double value;
  final Color? color;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clampedRatio = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final trackColor = backgroundColor ?? AppTokens.border(context);
    final barColor = color ?? AppTokens.primary(context);

    return ClipRRect(
      borderRadius: HubRadius.rPill,
      child: Container(
        height: height,
        color: trackColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: constraints.maxWidth * clampedRatio,
                decoration: BoxDecoration(
                  color: gradient == null ? barColor : null,
                  gradient: gradient,
                  borderRadius: HubRadius.rPill,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Month selector bar (< November 2026 >).
class MonthSwitcherCard extends StatelessWidget {
  const MonthSwitcherCard({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final FinanceMonth month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: onPrevious,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Expanded(
            child: Text(
              month.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTokens.textPrimary(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: onNext,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    );
  }
}

/// Model badge chip indicating AI model status.
class ModelBadgeChip extends StatelessWidget {
  const ModelBadgeChip({super.key, required this.didFallback, this.usedModel});

  final bool didFallback;
  final String? usedModel;

  @override
  Widget build(BuildContext context) {
    final label = didFallback ? 'Fallback' : 'Free';
    final color = didFallback ? AppTokens.warning(context) : AppTokens.info(context);

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: HubRadius.rPill,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Error banner with dismiss action.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final errColor = AppTokens.error(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: errColor.withValues(alpha: 0.12),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: errColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.alertCircle,
            size: 20,
            color: errColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: errColor),
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: onDismiss,
            icon: Icon(LucideIcons.x, size: 18, color: errColor),
          ),
        ],
      ),
    );
  }
}
