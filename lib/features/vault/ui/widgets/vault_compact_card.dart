import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';

/// Resolves display category (`Keuangan`, `Kerja`, `Pribadi`) for [entry].
String resolveVaultEntryCategory(VaultEntry entry) {
  final combined =
      '${entry.title} ${entry.url} ${entry.username} ${entry.notes}'
          .toLowerCase();

  if (combined.contains('bank') ||
      combined.contains('bca') ||
      combined.contains('mandiri') ||
      combined.contains('paypal') ||
      combined.contains('crypto') ||
      combined.contains('finance') ||
      combined.contains('wallet') ||
      combined.contains('kartu') ||
      combined.contains('bni') ||
      combined.contains('bri') ||
      combined.contains('jenius') ||
      combined.contains('jago') ||
      combined.contains('ovo') ||
      combined.contains('gopay') ||
      combined.contains('dana') ||
      combined.contains('bibit') ||
      combined.contains('ajaib') ||
      combined.contains('saham')) {
    return 'Keuangan';
  }

  if (combined.contains('google') ||
      combined.contains('github') ||
      combined.contains('work') ||
      combined.contains('slack') ||
      combined.contains('jira') ||
      combined.contains('office') ||
      combined.contains('gitlab') ||
      combined.contains('dev') ||
      combined.contains('aws') ||
      combined.contains('cloud') ||
      combined.contains('trello') ||
      combined.contains('zoom') ||
      combined.contains('teams') ||
      combined.contains('linkedin') ||
      combined.contains('kerja')) {
    return 'Kerja';
  }

  return 'Pribadi';
}

/// Resolves category accent color for a resolved [category].
Color getVaultCategoryColor(String category, BuildContext context) {
  final colors = HubColors.of(context);
  switch (category) {
    case 'Kerja':
      return colors.info;
    case 'Keuangan':
      return colors.primary;
    case 'Pribadi':
    default:
      return Theme.of(context).colorScheme.tertiary;
  }
}

/// Compact tactile Vault Account Card with 1 main copy button (48x48dp).
class VaultCompactCard extends StatelessWidget {
  const VaultCompactCard({
    super.key,
    required this.entry,
    required this.category,
    required this.categoryColor,
    required this.onTap,
    required this.onCopyPassword,
  });

  final VaultEntry entry;
  final String category;
  final Color categoryColor;
  final VoidCallback onTap;
  final VoidCallback onCopyPassword;

  @override
  Widget build(BuildContext context) {
    final initial = entry.title.trim().isNotEmpty
        ? entry.title.trim().characters.first.toUpperCase()
        : '?';

    return HubCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: categoryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: HubRadius.rPill,
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.username.isNotEmpty ? entry.username : '••••••••••••',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Salin kata sandi',
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: AppTokens.primary(context),
            onPressed: onCopyPassword,
          ),
        ],
      ),
    );
  }
}
