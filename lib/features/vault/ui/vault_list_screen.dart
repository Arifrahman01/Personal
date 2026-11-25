import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/settings/ui/pages/security_vault_settings_page.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/password_generator.dart';

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

  static String resolveEntryCategory(VaultEntry entry) {
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

  static Color getCategoryColor(String category, BuildContext context) {
    switch (category) {
      case 'Kerja':
        return AppTokens.info(context);
      case 'Keuangan':
        return AppTokens.primary(context);
      case 'Pribadi':
      default:
        return AppTokens.warning(context);
    }
  }

  Future<void> _copyWithGuard(String secret, {required String label}) async {
    await ref.read(clipboardGuardProvider).copySensitive(secret);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                LucideIcons.timer,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 16,
              ),
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
      backgroundColor: AppTokens.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      builder: (sheetContext) {
        return _VaultEntryFormSheet(existing: existing);
      },
    );
  }

  Future<void> _openDetailSheet(VaultEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTokens.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      builder: (sheetContext) {
        return _VaultAccountDetailSheet(
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
                backgroundColor: AppTokens.error(context),
                foregroundColor: Theme.of(context).colorScheme.onError,
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

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Brankas Kata Sandi'),
        backgroundColor: AppTokens.canvas(context),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Asisten AI',
            icon: const Icon(LucideIcons.sparkles),
            onPressed: () => MainNavigationShell.openAiChat(context),
          ),
          IconButton(
            tooltip: 'Pengaturan Brankas & Duress PIN',
            icon: const Icon(LucideIcons.shieldCheck),
            onPressed: _openSecuritySettings,
          ),
          IconButton(
            tooltip: 'Kunci brankas sekarang',
            icon: const Icon(LucideIcons.lock),
            onPressed: () {
              ref.read(vaultLockControllerProvider).lock();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: AppTokens.onPrimary(context),
        shape: RoundedRectangleBorder(borderRadius: HubRadius.rPill),
        icon: const Icon(LucideIcons.plus, size: 20),
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
                      LucideIcons.shieldAlert,
                      size: 20,
                      color: AppTokens.warning(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Penyamaran (Decoy) Aktif',
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(vaultSearchQueryProvider.notifier).setQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Cari akun, username, atau URL...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(vaultSearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: primary.withValues(alpha: 0.18),
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
            const SizedBox(height: 4),

            // Entries List
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.alertCircle,
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
                          .where((e) => resolveEntryCategory(e) == _selectedCategory)
                          .toList();

                  if (entries.isEmpty) {
                    final isUnfilteredEmpty =
                        query.isEmpty && _selectedCategory == 'Semua';
                    return HubEmptyState(
                      icon: LucideIcons.keyRound,
                      title: query.isEmpty
                          ? (_selectedCategory == 'Semua'
                              ? 'Brankas masih kosong'
                              : 'Tidak ada akun di kategori "$_selectedCategory"')
                          : 'Akun tidak ditemukan',
                      message: query.isEmpty
                          ? 'Simpan kata sandi Anda dengan aman dan terenkripsi di perangkat ini.'
                          : 'Coba ubah kata kunci pencarian Anda.',
                      actionLabel: isUnfilteredEmpty
                          ? 'Tambah Akun Pertama'
                          : 'Reset Filter',
                      onAction: isUnfilteredEmpty
                          ? () => _openEntryForm()
                          : () {
                              _searchController.clear();
                              ref
                                  .read(vaultSearchQueryProvider.notifier)
                                  .setQuery('');
                              setState(() {
                                _selectedCategory = 'Semua';
                              });
                            },
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final category = resolveEntryCategory(entry);
                      final catColor = getCategoryColor(category, context);

                      return _VaultCompactCard(
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
    );
  }
}

/// Compact tactile Vault Account Card with 1 main copy button (48x48dp).
class _VaultCompactCard extends StatelessWidget {
  const _VaultCompactCard({
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
          // Initial Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: categoryColor.withValues(alpha: 0.15),
            foregroundColor: categoryColor,
            child: Text(
              initial,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Username
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

          // 1 Main Action Button: Salin Sandi (48x48dp)
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Salin kata sandi',
            icon: const Icon(LucideIcons.copy, size: 20),
            color: AppTokens.primary(context),
            onPressed: onCopyPassword,
          ),
        ],
      ),
    );
  }
}

/// Detail Sheet Akun: displays full details, temporary password reveal,
/// copy actions, edit and delete options.
class _VaultAccountDetailSheet extends StatefulWidget {
  const _VaultAccountDetailSheet({
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
  State<_VaultAccountDetailSheet> createState() =>
      _VaultAccountDetailSheetState();
}

class _VaultAccountDetailSheetState extends State<_VaultAccountDetailSheet> {
  bool _isPasswordRevealed = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final category = _VaultListScreenState.resolveEntryCategory(entry);
    final catColor = _VaultListScreenState.getCategoryColor(category, context);
    final primary = AppTokens.primary(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTokens.border(context),
                borderRadius: HubRadius.rPill,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Username Field
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
                      entry.username,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (widget.onCopyUsername != null)
                    IconButton(
                      tooltip: 'Salin username',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.copy, size: 18),
                      onPressed: widget.onCopyUsername,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Password Field
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
                      fontWeight:
                          _isPasswordRevealed ? FontWeight.w600 : FontWeight.w400,
                      color: _isPasswordRevealed ? primary : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _isPasswordRevealed ? 'Sembunyikan sandi' : 'Tampilkan sandi',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(
                    _isPasswordRevealed ? LucideIcons.eyeOff : LucideIcons.eye,
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
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(LucideIcons.copy, size: 18),
                  onPressed: widget.onCopyPassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // URL Field
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
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.copy, size: 18),
                      onPressed: widget.onCopyUrl,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Notes Field
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          // Action Buttons: Edit and Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: const Text(
                    'Edit Akun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: widget.onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.error(context),
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text(
                    'Hapus Akun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

/// Form sheet for creating or updating a VaultEntry.
class _VaultEntryFormSheet extends ConsumerStatefulWidget {
  const _VaultEntryFormSheet({this.existing});

  final VaultEntry? existing;

  @override
  ConsumerState<_VaultEntryFormSheet> createState() =>
      _VaultEntryFormSheetState();
}

class _VaultEntryFormSheetState extends ConsumerState<_VaultEntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _usernameController =
        TextEditingController(text: widget.existing?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.existing?.password ?? '');
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final generated = PasswordGenerator.generate(
      length: 16,
      upper: true,
      lower: true,
      digits: true,
      symbols: true,
    );
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(vaultEntriesProvider.notifier);
      if (widget.existing != null) {
        await notifier.updateEntry(
          widget.existing!.copyWith(
            title: _titleController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            url: _urlController.text.trim(),
            notes: _notesController.text.trim(),
          ),
        );
      } else {
        await notifier.createEntry(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan entri brankas. Coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final primary = AppTokens.primary(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.border(context),
                      borderRadius: HubRadius.rPill,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      isEditing ? LucideIcons.pencil : LucideIcons.plusCircle,
                      size: 22,
                      color: primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Akun' : 'Tambah Akun Baru',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Akun *',
                    hintText: 'Misal: GitHub, Email Kantor, dsb.',
                    prefixIcon: Icon(LucideIcons.tag),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Judul akun tidak boleh kosong.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username / Email',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi *',
                    hintText: 'Sandi rahasia',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Tampilkan sandi'
                          : 'Sembunyikan sandi',
                      icon: Icon(
                        _obscurePassword
                            ? LucideIcons.eye
                            : LucideIcons.eyeOff,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi tidak boleh kosong.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _generatePassword,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Buat Sandi Acak (16 Karakter)'),
                  ),
                ),
                const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Alamat Website / URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(LucideIcons.globe),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Pertanyaan keamanan, nomor pemulihan, dsb.',
                  prefixIcon: Icon(LucideIcons.fileText),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: AppTokens.error(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: AppTokens.onPrimary(context),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                ),
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTokens.onPrimary(context),
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  isEditing ? 'Simpan Perubahan' : 'Simpan ke Brankas',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
