import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/ui/widgets/vault_compact_card.dart';

/// Account detail modal bottom sheet displaying decrypted fields,
/// temporary password reveal toggle, copy actions, and edit/delete triggers.
class VaultAccountDetailSheet extends StatefulWidget {
  const VaultAccountDetailSheet({
    super.key,
    required this.entry,
    required this.onCopyPassword,
    this.onCopyUsername,
    this.onCopyUrl,
    required this.onEdit,
    required this.onDelete,
  });

  final VaultEntry entry;
  final VoidCallback onCopyPassword;
  final VoidCallback? onCopyUsername;
  final VoidCallback? onCopyUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<VaultAccountDetailSheet> createState() =>
      _VaultAccountDetailSheetState();
}

class _VaultAccountDetailSheetState extends State<VaultAccountDetailSheet> {
  bool _isPasswordRevealed = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final category = resolveVaultEntryCategory(entry);
    final catColor = getVaultCategoryColor(category, context);
    final colors = HubColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colors.primary;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HubSpacing.xl,
          HubSpacing.xs,
          HubSpacing.xl,
          HubSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: catColor.withValues(alpha: 0.15),
                  foregroundColor: catColor,
                  child: Text(
                    entry.title.isNotEmpty
                        ? entry.title.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (entry.username.isNotEmpty) ...[
              Text(
                'Username / Email',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        entry.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.onCopyUsername != null)
                      IconButton(
                        tooltip: 'Salin username',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: widget.onCopyUsername,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Kata Sandi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTokens.canvas(context),
                borderRadius: HubRadius.rSm,
                border: Border.all(color: AppTokens.border(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _isPasswordRevealed ? entry.password : '••••••••••••',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        letterSpacing: _isPasswordRevealed ? 0.5 : 2.5,
                        fontWeight: _isPasswordRevealed
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _isPasswordRevealed ? primary : null,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _isPasswordRevealed
                        ? 'Sembunyikan sandi'
                        : 'Tampilkan sandi',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: Icon(
                      _isPasswordRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordRevealed = !_isPasswordRevealed;
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Salin kata sandi',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: widget.onCopyPassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (entry.url.isNotEmpty) ...[
              Text(
                'Alamat Website / URL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        entry.url,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTokens.info(context),
                        ),
                      ),
                    ),
                    if (widget.onCopyUrl != null)
                      IconButton(
                        tooltip: 'Salin URL',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: widget.onCopyUrl,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (entry.notes.isNotEmpty) ...[
              Text(
                'Catatan Tambahan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.canvas(context),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(color: AppTokens.border(context)),
                ),
                child: SelectableText(
                  entry.notes,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: HubRadius.rSm,
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Akun'),
                    onPressed: widget.onEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: HubRadius.rSm,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus Akun'),
                    onPressed: widget.onDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
