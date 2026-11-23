import 'package:flutter/material.dart';
import 'package:personal_hub/features/home/providers/home_providers.dart';
import 'package:personal_hub/features/home/ui/widgets/ai_daily_briefing_card.dart';

export 'package:personal_hub/features/home/ui/widgets/ai_daily_briefing_card.dart';

/// Compact and collapsible AI Daily Briefing card for Calm Clarity Home Screen.
class TodayBriefingCard extends StatelessWidget {
  const TodayBriefingCard({
    super.key,
    required this.briefingState,
    required this.onGenerate,
  });

  final DailyBriefingState briefingState;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return AiDailyBriefingCard(
      briefingState: briefingState,
      onGenerate: onGenerate,
    );
  }
}
