import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/settings/ui/pages/security_vault_settings_page.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/widgets/vault_account_detail_sheet.dart';
import 'package:personal_hub/features/vault/ui/widgets/vault_compact_card.dart';
import 'package:personal_hub/features/vault/ui/widgets/vault_entry_form_sheet.dart';

/// Unlocked password vault screen with category filtering, 1-tap copy,
/// account detail sheet, and security settings.
class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  static const List<String> _categories = [
    'Semua',
    'Kerja',
    'Keuangan',
    'Pribadi',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyWithGuard(String secret, {required String label}) async {
    await ref.read(clipboardGuardProvider).copySensitive(secret);
    if (!mounted) return;
    final onInverse = Theme.of(context).colorScheme.onInverseSurface;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.timer_outlined, color: onInverse, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label disalin. Clipboard akan dihapus otomatis dalam 30 detik.',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openEntryForm({VaultEntry? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return VaultEntryFormSheet(existing: existing);
      },
    );
  }

  Future<void> _openDetailSheet(VaultEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return VaultAccountDetailSheet(
          entry: entry,
          onCopyPassword: () => _copyWithGuard(
            entry.password,
            label: 'Kata sandi',
          ),
          onCopyUsername: entry.username.isNotEmpty
              ? () => _copyWithGuard(entry.username, label: 'Username')
              : null,
          onCopyUrl: entry.url.isNotEmpty
              ? () => _copyWithGuard(entry.url, label: 'URL')
              : null,
          onEdit: () {
            Navigator.of(sheetContext).pop();
            _openEntryForm(existing: entry);
          },
          onDelete: () async {
            Navigator.of(sheetContext).pop();
            await _confirmDelete(entry);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(VaultEntry entry) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Akun Brankas?'),
          content: Text(
            'Akun "${entry.title}" akan dihapus permanen dari brankas terenkripsi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(vaultEntriesProvider.notifier).deleteEntry(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun "${entry.title}" telah dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSecuritySettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SecurityVaultSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vaultEntriesProvider);
    final query = ref.watch(vaultSearchQueryProvider);
    final vaultLock = ref.watch(vaultLockControllerProvider);
    final isDecoy = vaultLock.isDecoyMode;
    final primary = AppTokens.primary(context);

    return LuxeAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              LuxeIconMedallion(
                icon: Icons.verified_user_rounded,
                color: primary,
                size: 34,
                iconSize: 18,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Brankas Kata Sandi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          actions: [
            LuxeHeaderIconButton(
              tooltip: 'AI Copilot',
              icon: Icons.auto_awesome_rounded,
              accentColor: HubColors.of(context).accentAi,
              onPressed: () => MainNavigationShell.openAiChat(context),
            ),
            LuxeHeaderIconButton(
              tooltip: 'Pengaturan Brankas & Duress PIN',
              icon: Icons.verified_user_outlined,
              onPressed: _openSecuritySettings,
            ),
            LuxeHeaderIconButton(
              tooltip: 'Kunci brankas sekarang',
              icon: Icons.lock_outline_rounded,
              accentColor: HubColors.of(context).accentGold,
              onPressed: () {
                ref.read(vaultLockControllerProvider).lock();
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tambah Akun',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _openEntryForm(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Decoy Mode Banner
            if (isDecoy)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.warning(context).withValues(alpha: 0.15),
                  borderRadius: HubRadius.rSm,
                  border: Border.all(
                    color: AppTokens.warning(context).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gpp_maybe_outlined,
                      size: 20,
                      color: AppTokens.warning(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decoy Mode Aktif',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTokens.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Brankas sekunder dibuka. Data sensitif asli Anda tetap aman terisolasi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Material 3 SearchBar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HubSpacing.lg,
                HubSpacing.sm,
                HubSpacing.lg,
                HubSpacing.xs,
              ),
              child: SearchBar(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(vaultSearchQueryProvider.notifier).setQuery(value);
                },
                hintText: 'Cari akun, username, atau URL...',
                leading: const Icon(Icons.search_rounded, size: 20),
                trailing: query.isNotEmpty
                    ? [
                        IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(vaultSearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        ),
                      ]
                    : null,
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: HubSpacing.lg,
                vertical: HubSpacing.xs,
              ),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: HubSpacing.sm),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: primary.withValues(alpha: 0.16),
                      side: BorderSide(
                        color: isSelected
                            ? primary
                            : AppTokens.border(context),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? primary : AppTokens.textSecondary(context),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: HubSpacing.xs),

            // Entries List
            Expanded(
              child: entriesAsync.when(
                loading: () => const HubSkeletonList(),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: AppTokens.error(context),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gagal memuat data brankas.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () =>
                              ref.read(vaultEntriesProvider.notifier).refresh(),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (allEntries) {
                  // Filter by category
                  final entries = _selectedCategory == 'Semua'
                      ? allEntries
                      : allEntries
                          .where(
                            (e) =>
                                resolveVaultEntryCategory(e) ==
                                _selectedCategory,
                          )
                          .toList();

                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.vpn_key_outlined,
                                size: 28,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              query.isEmpty
                                  ? (_selectedCategory == 'Semua'
                                      ? 'Brankas masih kosong'
                                      : 'Tidak ada akun di kategori "$_selectedCategory"')
                                  : 'Akun tidak ditemukan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              query.isEmpty
                                  ? 'Simpan kata sandi Anda dengan aman terlindungi enkripsi AES-256-GCM.'
                                  : 'Coba ubah kata kunci pencarian Anda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final category = resolveVaultEntryCategory(entry);
                      final catColor = getVaultCategoryColor(category, context);

                      return VaultCompactCard(
                        entry: entry,
                        category: category,
                        categoryColor: catColor,
                        onTap: () => _openDetailSheet(entry),
                        onCopyPassword: () => _copyWithGuard(
                          entry.password,
                          label: 'Kata sandi',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
