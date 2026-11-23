import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/finance/ui/widgets/finance_shared_widgets.dart';

/// Modal dialog presenting Samudra AI's monthly financial evaluation.
class MonthlyInsightDialog extends StatelessWidget {
  const MonthlyInsightDialog({
    super.key,
    required this.month,
    required this.response,
  });

  final FinanceMonth month;
  final AiResponse response;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Analisa Bulan Ini')),
          ModelBadgeChip(
            didFallback: response.didFallback,
            usedModel: response.usedModel,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              month.label,
              style: TextStyle(
                fontSize: 13,
                color: AppTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              response.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTokens.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
