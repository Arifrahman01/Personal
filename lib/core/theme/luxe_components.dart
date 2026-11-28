import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';

/// Atmospheric, lightweight ambient canvas background with zero BackdropFilter.
/// Paints subtle corner radial gradient washes tuned for Warm Alabaster (Light)
/// and Deep Obsidian Velvet (Dark).
class LuxeAmbientBackground extends StatelessWidget {
  const LuxeAmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = HubColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.canvas),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -130,
            right: -90,
            child: _AmbientGlowOrb(
              size: 360,
              color: colors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            ),
          ),
          Positioned(
            top: 220,
            left: -140,
            child: _AmbientGlowOrb(
              size: 320,
              color: colors.accentGold.withValues(alpha: isDark ? 0.08 : 0.07),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -40,
            child: _AmbientGlowOrb(
              size: 340,
              color: colors.accentAi.withValues(alpha: isDark ? 0.09 : 0.05),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientGlowOrb extends StatelessWidget {
  const _AmbientGlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
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
      ),
    );
  }
}

/// CustomPainter rendering delicate translucent geometric star & orbital rings
/// for Sanctuary Luxe hero cards without any GPU blur cost.
class LuxeGeometricPatternPainter extends CustomPainter {
  const LuxeGeometricPatternPainter({
    this.color = Colors.white,
    this.opacity = 0.07,
  });

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final anchor = Offset(size.width * 0.88, size.height * 0.28);
    final baseRadius = math.min(size.width, size.height) * 0.55;

    // Concentric orbital rings
    for (final factor in [0.45, 0.78, 1.12]) {
      canvas.drawCircle(anchor, baseRadius * factor, paint);
    }

    // 8-point subtle sacred star geometry
    final starRadius = baseRadius * 0.62;
    for (var rectIdx = 0; rectIdx < 2; rectIdx++) {
      final angle = rectIdx * (math.pi / 4);
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final theta = angle + i * (math.pi / 2);
        final pt = Offset(
          anchor.dx + starRadius * math.cos(theta),
          anchor.dy + starRadius * math.sin(theta),
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LuxeGeometricPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}

/// Signature Sanctuary Luxe multi-stop gradient hero card with specular top rim,
/// ambient glow shadow, and optional geometric vector surface art.
class LuxeHeroCard extends StatelessWidget {
  const LuxeHeroCard({
    super.key,
    required this.child,
    this.gradient,
    this.glowColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius,
    this.onTap,
    this.showPattern = true,
    this.patternOpacity = 0.08,
  });

  final Widget child;
  final Gradient? gradient;
  final Color? glowColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool showPattern;
  final double patternOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? HubRadius.rLg;
    final effectiveGradient =
        gradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A4D41),
            Color(0xFF0B6E5B),
            Color(0xFF103E47),
          ],
        );
    final effectiveGlow = glowColor ?? const Color(0xFF0B6E5B);

    Widget inner = Padding(padding: padding, child: child);
    if (onTap != null) {
      inner = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: inner,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveGlow.withValues(alpha: isDark ? 0.28 : 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (showPattern)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: LuxeGeometricPatternPainter(
                      opacity: patternOpacity,
                    ),
                  ),
                ),
              ),
            inner,
          ],
        ),
      ),
    );
  }
}

/// Sculpted rounded-square icon medallion with soft tonal fill and hairline rim.
class LuxeIconMedallion extends StatelessWidget {
  const LuxeIconMedallion({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.gradient,
    this.size = 40,
    this.iconSize = 20,
    this.borderRadius = 12,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double size;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (gradient != null ? Colors.white : AppTokens.primary(context));
    final bg = gradient == null
        ? (backgroundColor ?? fg.withValues(alpha: 0.12))
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: gradient != null
              ? Colors.white.withValues(alpha: 0.22)
              : fg.withValues(alpha: 0.22),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Refined tonal squircle icon button for AppBars with >=48dp touch area.
class LuxeHeaderIconButton extends StatelessWidget {
  const LuxeHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = accentColor ?? colors.textPrimary;
    final bg = accentColor != null
        ? accentColor!.withValues(alpha: isDark ? 0.16 : 0.10)
        : colors.surfaceCard.withValues(alpha: isDark ? 0.85 : 0.92);
    final border = accentColor != null
        ? accentColor!.withValues(alpha: 0.30)
        : colors.borderHairline;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(6),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

/// Crafted emerald-to-gold monogram emblem for AppBar & Workspace Sidebar.
class LuxeBrandEmblem extends StatelessWidget {
  const LuxeBrandEmblem({
    super.key,
    this.size = 38,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            const Color(0xFF0A4D41),
            colors.accentGold.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.50,
        color: Colors.white,
      ),
    );
  }
}

/// Editorial section eyebrow with glowing accent dot and optional trailing action.
class LuxeSectionLabel extends StatelessWidget {
  const LuxeSectionLabel({
    super.key,
    required this.title,
    this.dotColor,
    this.trailing,
  });

  final String title;
  final Color? dotColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final effectiveDot = dotColor ?? colors.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveDot,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveDot.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// Smooth rounded linear progress bar with linear gradient fill and luminous tip.
class LuxeGlowingProgressBar extends StatelessWidget {
  const LuxeGlowingProgressBar({
    super.key,
    required this.value,
    this.height = 7.0,
    this.trackColor,
    this.gradient,
    this.glowColor,
  });

  final double value;
  final double height;
  final Color? trackColor;
  final Gradient? gradient;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final colors = HubColors.of(context);
    final effectiveTrack = trackColor ?? colors.borderHairline;
    final effectiveGlow = glowColor ?? colors.primary;
    final effectiveGradient =
        gradient ??
        LinearGradient(
          colors: [colors.primary, colors.accentGold],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 120.0;
        final fillWidth = (totalWidth * clamped).clamp(0.0, totalWidth);

        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: effectiveTrack,
            borderRadius: HubRadius.rPill,
          ),
          alignment: Alignment.centerLeft,
          child: fillWidth <= 0
              ? const SizedBox.shrink()
              : Container(
                  width: math.max(height, fillWidth),
                  height: height,
                  decoration: BoxDecoration(
                    gradient: effectiveGradient,
                    borderRadius: HubRadius.rPill,
                    boxShadow: [
                      BoxShadow(
                        color: effectiveGlow.withValues(alpha: 0.40),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Custom-painted smooth circular progress gauge with rounded caps and center child.
class LuxeCircularGauge extends StatelessWidget {
  const LuxeCircularGauge({
    super.key,
    required this.progress,
    this.size = 44,
    this.strokeWidth = 4.5,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final activeColor = color ?? colors.primary;
    final bgTrack = trackColor ?? colors.borderHairline;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LuxeCircularGaugePainter(
          progress: progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0,
          strokeWidth: strokeWidth,
          activeColor: activeColor,
          trackColor: bgTrack,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _LuxeCircularGaugePainter extends CustomPainter {
  const _LuxeCircularGaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuxeCircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Precision Astrolabe Qibla Compass Dial Painter with concentric rings and 72 ticks.
class LuxeCompassDialPainter extends CustomPainter {
  const LuxeCompassDialPainter({
    required this.primaryColor,
    required this.goldColor,
    required this.borderColor,
    required this.textColor,
    required this.surfaceColor,
    required this.isAligned,
    required this.successColor,
  });

  final Color primaryColor;
  final Color goldColor;
  final Color borderColor;
  final Color textColor;
  final Color surfaceColor;
  final bool isAligned;
  final Color successColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ambient halo
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isAligned ? successColor : primaryColor).withValues(
            alpha: isAligned ? 0.18 : 0.08,
          ),
          surfaceColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, haloPaint);

    // Outer bezel ring
    final outerBorder = Paint()
      ..color = isAligned ? successColor : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 2.5 : 1.5;
    canvas.drawCircle(center, radius - 2, outerBorder);

    // Inner concentric astrolabe rings
    final innerRingPaint = Paint()
      ..color = (isAligned ? successColor : primaryColor).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.78, innerRingPaint);
    canvas.drawCircle(center, radius * 0.44, innerRingPaint);

    // 72 degree ticks (every 5 degrees)
    final minorTick = Paint()
      ..color = textColor.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    final mediumTick = Paint()
      ..color = textColor.withValues(alpha: 0.40)
      ..strokeWidth = 1.4;
    final cardinalTick = Paint()
      ..color = isAligned ? successColor : goldColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (var deg = 0; deg < 360; deg += 5) {
      final isCardinal = deg % 90 == 0;
      final isMedium = deg % 30 == 0;
      final tickLen = isCardinal ? 13.0 : (isMedium ? 8.0 : 4.5);
      final rad = deg * (math.pi / 180.0);
      final outerR = radius - 4;
      final innerR = outerR - tickLen;

      final p1 = Offset(
        center.dx + innerR * math.sin(rad),
        center.dy - innerR * math.cos(rad),
      );
      final p2 = Offset(
        center.dx + outerR * math.sin(rad),
        center.dy - outerR * math.cos(rad),
      );

      canvas.drawLine(
        p1,
        p2,
        isCardinal ? cardinalTick : (isMedium ? mediumTick : minorTick),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LuxeCompassDialPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.goldColor != goldColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.successColor != successColor;
  }
}

/// Custom-painted sculpted compass needle pointing toward Qibla.
class LuxeQiblaNeedle extends StatelessWidget {
  const LuxeQiblaNeedle({
    super.key,
    required this.isAligned,
    this.size = 132,
  });

  final bool isAligned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final northColor = isAligned ? colors.success : colors.primary;
    final southColor = colors.textSecondary.withValues(alpha: 0.35);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LuxeQiblaNeedlePainter(
          northColor: northColor,
          southColor: southColor,
          goldColor: colors.accentGold,
          centerColor: colors.surfaceCard,
        ),
      ),
    );
  }
}

class _LuxeQiblaNeedlePainter extends CustomPainter {
  const _LuxeQiblaNeedlePainter({
    required this.northColor,
    required this.southColor,
    required this.goldColor,
    required this.centerColor,
  });

  final Color northColor;
  final Color southColor;
  final Color goldColor;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfW = size.width * 0.11;

    // North / Qibla tip
    final northPath = Path()
      ..moveTo(cx, 6)
      ..lineTo(cx + halfW, cy)
      ..lineTo(cx - halfW, cy)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..color = northColor
        ..style = PaintingStyle.fill,
    );

    // South counterweight
    final southPath = Path()
      ..moveTo(cx, size.height - 14)
      ..lineTo(cx + halfW * 0.72, cy)
      ..lineTo(cx - halfW * 0.72, cy)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..color = southColor
        ..style = PaintingStyle.fill,
    );

    // Golden Kaaba beacon dot near tip
    canvas.drawCircle(
      Offset(cx, 24),
      4.5,
      Paint()..color = goldColor,
    );

    // Center jewel pivot
    canvas.drawCircle(
      Offset(cx, cy),
      8,
      Paint()..color = northColor,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = centerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _LuxeQiblaNeedlePainter oldDelegate) {
    return oldDelegate.northColor != northColor ||
        oldDelegate.southColor != southColor ||
        oldDelegate.goldColor != goldColor;
  }
}
