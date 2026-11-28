import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';

/// Compact AI Daily Briefing card with Samudra Indigo-Violet accent styling.
class AiDailyBriefingCard extends StatefulWidget {
  const AiDailyBriefingCard({
    super.key,
    required this.briefingState,
    required this.onGenerate,
  });

  final DailyBriefingState briefingState;
  final VoidCallback onGenerate;

  @override
  State<AiDailyBriefingCard> createState() => _AiDailyBriefingCardState();
}

class _AiDailyBriefingCardState extends State<AiDailyBriefingCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final state = widget.briefingState;
    final hasBriefing = state.response != null;
    final timeFmt = DateFormat('HH:mm');

    return HubCard(
      padding: const EdgeInsets.all(16),
      borderColor: colors.accentAi.withValues(alpha: 0.30),
      elevationGlowColor: colors.accentAi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    LuxeIconMedallion(
                      icon: Icons.auto_awesome_rounded,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.accentAi, colors.primary],
                      ),
                      size: 34,
                      iconSize: 17,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Ringkasan Hari Ini (AI)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!hasBriefing && !state.isLoading)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentAi, colors.primary],
                    ),
                    borderRadius: HubRadius.rPill,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: HubRadius.rPill,
                      onTap: widget.onGenerate,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        child: Text(
                          'Buat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (hasBriefing)
                IconButton(
                  tooltip: _isExpanded
                      ? 'Ciutkan ringkasan'
                      : 'Perluas ringkasan',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
            ],
          ),

          // Content body
          if (state.isLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accentAi,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menyusun ringkasan agenda & tugas hari ini...',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (state.errorMessage != null && !hasBriefing) ...[
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: colors.danger,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onGenerate,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
              ),
            ),
          ] else if (hasBriefing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accentAi.withValues(alpha: 0.06),
                borderRadius: HubRadius.rSm,
                border: Border.all(
                  color: colors.accentAi.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                state.response!.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.textPrimary,
                ),
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (state.generatedAt != null && _isExpanded) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Dibuat jam ${timeFmt.format(state.generatedAt!)} via ${state.response!.usedModel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HubTypography.tabular(
                        TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onGenerate,
                    borderRadius: HubRadius.rXs,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 12,
                            color: colors.accentAi,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Perbarui',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.accentAi,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Tekan "Buat" untuk merangkum agenda & prioritas harimu secara cerdas.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
