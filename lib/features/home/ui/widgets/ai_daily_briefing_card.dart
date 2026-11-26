import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';

/// Compact AI Daily Briefing card that can be folded or expanded.
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
    final state = widget.briefingState;
    final hasBriefing = state.response != null;
    final timeFmt = DateFormat('HH:mm');

    return HubCard(
      padding: const EdgeInsets.all(16),
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
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppTokens.primary(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Ringkasan Hari Ini (AI)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!hasBriefing && !state.isLoading)
                FilledButton.tonal(
                  onPressed: widget.onGenerate,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
                  ),
                  child: const Text('Buat', style: TextStyle(fontSize: 12)),
                )
              else if (hasBriefing)
                IconButton(
                  tooltip: _isExpanded ? 'Ciutkan ringkasan' : 'Perluas ringkasan',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTokens.textSecondary(context),
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
                    color: AppTokens.primary(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menyusun ringkasan agenda & tugas hari ini...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
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
                color: AppTokens.error(context),
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
            const SizedBox(height: 10),
            Text(
              state.response!.content,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTokens.textPrimary(context),
              ),
              maxLines: _isExpanded ? null : 2,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onGenerate,
                    borderRadius: HubRadius.rXs,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 11,
                            color: AppTokens.primary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Perbarui',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTokens.primary(context),
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
            const SizedBox(height: 6),
            Text(
              'Tekan "Buat" untuk merangkum agenda & prioritas harimu secara cerdas.',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
