import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';

/// Chat message bubble for [AiChatScreen] with adaptive light/dark styling
/// and model fallback indicator badge for assistant replies.
class AiChatBubble extends StatelessWidget {
  const AiChatBubble({super.key, required this.message});

  final ChatThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colors = HubColors.of(context);

    final borderColor = isUser
        ? Colors.white.withValues(alpha: 0.18)
        : colors.borderHairline;
    final textColor = isUser ? Colors.white : colors.textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? null : colors.surfaceCard,
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E8F74), Color(0xFF0A5C4D)],
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                AiModelBadgeChip(
                  didFallback: message.didFallback,
                  usedModel: message.usedModel,
                ),
                const SizedBox(height: 6),
              ],
              SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge showing whether the AI response came from the primary (`Free`)
/// or fallback (`Fallback`) model.
class AiModelBadgeChip extends StatelessWidget {
  const AiModelBadgeChip({
    super.key,
    required this.didFallback,
    this.usedModel,
  });

  final bool didFallback;
  final String? usedModel;

  @override
  Widget build(BuildContext context) {
    final primary = AppTokens.primary(context);
    final warning = AppTokens.warning(context);

    final bgColor = didFallback
        ? warning.withValues(alpha: 0.15)
        : primary.withValues(alpha: 0.15);
    final fgColor = didFallback ? warning : primary;
    final label = didFallback ? 'Fallback' : 'Free';

    return Tooltip(
      message: usedModel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: HubRadius.rPill,
          border: Border.all(color: fgColor.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
