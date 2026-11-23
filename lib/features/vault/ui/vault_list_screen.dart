import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/password_generator.dart';

/// Unlocked password vault screen with search, reveal toggle, clipboard auto-clear, and CRUD.
class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key});

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyWithGuard(String secret, {required String label}) async {
    await ref.read(clipboardGuardProvider).copySensitive(secret);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$label disalin. Clipboard akan dihapus otomatis dalam 30 detik.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _openEntryForm({VaultEntry? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _VaultEntryFormSheet(existing: existing);
      },
    );
  }

  Future<void> _confirmDelete(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Entri Brankas?'),
          content: Text(
            'Akun "${entry.title}" akan dihapus permanen dari brankas terenkripsi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(vaultEntriesProvider.notifier).deleteEntry(entry.id);
    }
  }

  Future<void> _openDuressPinDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 22),
                  SizedBox(width: 8),
                  Text('Atur Duress PIN'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duress PIN adalah PIN umpan darurat. Saat dimasukkan di layar brankas, brankas akan membuka profil alternatif (decoy) yang aman tanpa mengekspos akun Anda yang sebenarnya.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duress PIN Baru',
                        hintText: 'Min. 4 digit angka',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi Duress PIN',
                        hintText: 'Ulangi PIN umpan',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();
                    if (pin != confirm) {
                      setDialogState(() {
                        errorText = 'Konfirmasi Duress PIN tidak cocok.';
                      });
                      return;
                    }
                    try {
                      await controller.setupDuressPin(pin);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on ValidationException catch (e) {
                      setDialogState(() {
                        errorText = e.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        errorText = 'Gagal menyimpan Duress PIN. Coba lagi.';
                      });
                    }
                  },
                  child: const Text('Simpan Duress PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Duress PIN (PIN Umpan) berhasil dikonfigurasi.'),
          ),
        );
    }
  }

  Future<void> _openVaultSecuritySettings() async {
    final controller = ref.read(vaultLockControllerProvider);
    final hasDuress = await controller.hasDuressPin();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeTimeout = controller.autoLockTimeout;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const GlassIconTile(
                        icon: Icons.security_rounded,
                        size: 40,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keamanan & Pengaturan Brankas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kunci Otomatis (Auto-Lock Timeout)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kunci brankas jika aplikasi diminimalkan atau tidak aktif.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in [
                        (AutoLockTimeout.immediate, 'Seketika'),
                        (AutoLockTimeout.seconds30, '30 Detik'),
                        (AutoLockTimeout.minute1, '1 Menit'),
                        (AutoLockTimeout.minutes5, '5 Menit'),
                      ])
                        ChoiceChip(
                          label: Text(item.$2),
                          selected: activeTimeout == item.$1,
                          onSelected: (selected) async {
                            if (selected) {
                              await controller.setAutoLockTimeout(item.$1);
                              setSheetState(() {});
                            }
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duress PIN (Anti-Pemaksaan)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasDuress
                                  ? 'Duress PIN aktif. Jika dipaksa membuka brankas, masukkan PIN ini untuk membuka profil akun umpan tanpa membocorkan data asli.'
                                  : 'Belum diatur. Konfigurasikan PIN umpan untuk perlindungan ekstra saat berada dalam ancaman atau pemaksaan.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassBadge(
                        label: hasDuress ? 'Aktif' : 'Nonaktif',
                        backgroundColor: (hasDuress
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest)
                            .withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pin_outlined, size: 18),
                      label: Text(hasDuress ? 'Ubah Duress PIN' : 'Konfigurasi Duress PIN'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openDuressPinDialog();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vaultEntriesProvider);
    final query = ref.watch(vaultSearchQueryProvider);
    final vaultLock = ref.watch(vaultLockControllerProvider);
    final isDecoy = vaultLock.isDecoyMode;
    final theme = Theme.of(context);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Brankas Kata Sandi'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Brankas & Duress PIN',
            icon: const Icon(Icons.shield_outlined),
            onPressed: _openVaultSecuritySettings,
          ),
          IconButton(
            tooltip: 'Kunci brankas sekarang',
            icon: const Icon(Icons.lock_outline_rounded),
            onPressed: () {
              setState(() {
                _revealedIds.clear();
              });
              ref.read(vaultLockControllerProvider).lock();
            },
          ),
        ],
      ),
      floatingActionButton: GlassFabAnchor(
        child: Container(
          decoration: BoxDecoration(
            gradient: RefleqPalette.lavenderCloud,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openEntryForm(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Tambah Akun',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (isDecoy) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Decoy Mode Aktif',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Brankas sekunder dibuka. Data sensitif asli Anda tetap aman dan terisolasi.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const GlassBadge(
                        label: 'Aman',
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(vaultSearchQueryProvider.notifier).setQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Cari judul akun, username, atau URL...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close_rounded),
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
                          Icons.error_outline_rounded,
                          size: 40,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat data brankas.',
                          style: theme.textTheme.titleMedium,
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
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: const Icon(Icons.vpn_key_outlined, size: 28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              query.isEmpty
                                  ? 'Brankas masih kosong'
                                  : 'Akun tidak ditemukan',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              query.isEmpty
                                  ? 'Simpan kata sandi penting Anda dengan enkripsi AES-256-GCM lokal.'
                                  : 'Coba ubah kata kunci pencarian Anda.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isRevealed = _revealedIds.contains(entry.id);
                      return _VaultEntryCard(
                        entry: entry,
                        isRevealed: isRevealed,
                        onToggleReveal: () {
                          setState(() {
                            if (isRevealed) {
                              _revealedIds.remove(entry.id);
                            } else {
                              _revealedIds.add(entry.id);
                            }
                          });
                        },
                        onCopyPassword: () => _copyWithGuard(
                          entry.password,
                          label: 'Kata sandi',
                        ),
                        onCopyUsername: entry.username.isEmpty
                            ? null
                            : () => _copyWithGuard(
                                entry.username,
                                label: 'Username',
                              ),
                        onEdit: () => _openEntryForm(existing: entry),
                        onDelete: () => _confirmDelete(entry),
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

class _VaultEntryCard extends StatelessWidget {
  const _VaultEntryCard({
    required this.entry,
    required this.isRevealed,
    required this.onToggleReveal,
    required this.onCopyPassword,
    required this.onCopyUsername,
    required this.onEdit,
    required this.onDelete,
  });

  final VaultEntry entry;
  final bool isRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopyPassword;
  final VoidCallback? onCopyUsername;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static Color resolveCategoryColor(VaultEntry entry) {
    final title = entry.title.toLowerCase();
    final url = entry.url.toLowerCase();
    final username = entry.username.toLowerCase();
    final combined = '$title $url $username';

    if (combined.contains('google') ||
        combined.contains('github') ||
        combined.contains('work') ||
        combined.contains('slack') ||
        combined.contains('jira') ||
        combined.contains('office') ||
        combined.contains('gitlab')) {
      return RefleqPalette.skyCyan;
    }
    if (combined.contains('bank') ||
        combined.contains('bca') ||
        combined.contains('mandiri') ||
        combined.contains('paypal') ||
        combined.contains('crypto') ||
        combined.contains('finance') ||
        combined.contains('wallet') ||
        combined.contains('kartu')) {
      return RefleqPalette.rosePink;
    }
    if (combined.contains('personal') ||
        combined.contains('pribadi') ||
        combined.contains('vault') ||
        combined.contains('master') ||
        combined.contains('email')) {
      return RefleqPalette.lavender;
    }
    final hash = (entry.id.hashCode ^ entry.title.hashCode).abs();
    const cycle = [
      RefleqPalette.lavender,
      RefleqPalette.skyCyan,
      RefleqPalette.rosePink,
      RefleqPalette.emeraldMint,
    ];
    return cycle[hash % cycle.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = resolveCategoryColor(entry);

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.08),
      tintColor: isDark
          ? RefleqPalette.surfaceCard.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.72),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category Pastel Stripe
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.50),
                    blurRadius: 8,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              categoryColor.withValues(alpha: 0.18),
                          foregroundColor: isDark
                              ? categoryColor
                              : const Color(0xFF4C1D95),
                          child: Text(
                            entry.title.characters.first.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (entry.username.isNotEmpty)
                                Text(
                                  entry.username,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit entri',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          tooltip: 'Hapus entri',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? RefleqPalette.surface.withValues(alpha: 0.75)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isRevealed ? entry.password : '••••••••••••',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                letterSpacing: isRevealed ? 0.5 : 2.0,
                                color: isRevealed
                                    ? RefleqPalette.lavender
                                    : null,
                                fontWeight: isRevealed
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: isRevealed
                                ? 'Sembunyikan sandi'
                                : 'Tampilkan sandi',
                            icon: Icon(
                              isRevealed
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color:
                                  isRevealed ? RefleqPalette.lavender : null,
                            ),
                            onPressed: onToggleReveal,
                          ),
                          IconButton(
                            tooltip: 'Salin kata sandi',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: onCopyPassword,
                          ),
                        ],
                      ),
                    ),
                    if (entry.url.isNotEmpty ||
                        entry.notes.isNotEmpty ||
                        onCopyUsername != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (onCopyUsername != null)
                            ActionChip(
                              avatar:
                                  const Icon(Icons.person_outline, size: 16),
                              label: const Text('Salin Username'),
                              onPressed: onCopyUsername,
                            ),
                          if (entry.url.isNotEmpty)
                            Chip(
                              avatar:
                                  const Icon(Icons.link_rounded, size: 16),
                              label: Text(
                                entry.url,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.notes,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultEntryFormSheet extends ConsumerStatefulWidget {
  const _VaultEntryFormSheet({this.existing});

  final VaultEntry? existing;

  @override
  ConsumerState<_VaultEntryFormSheet> createState() =>
      _VaultEntryFormSheetState();
}

class _VaultEntryFormSheetState extends ConsumerState<_VaultEntryFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  bool _obscurePassword = true;
  bool _showGenerator = false;
  bool _isSaving = false;
  String? _errorMessage;

  int _genLength = 16;
  bool _genUpper = true;
  bool _genLower = true;
  bool _genDigits = true;
  bool _genSymbols = true;

  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _usernameController = TextEditingController(text: entry?.username ?? '');
    _passwordController = TextEditingController(text: entry?.password ?? '');
    _urlController = TextEditingController(text: entry?.url ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
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
    try {
      final generated = PasswordGenerator.generate(
        length: _genLength,
        upper: _genUpper,
        lower: _genLower,
        digits: _genDigits,
        symbols: _genSymbols,
      );
      setState(() {
        _passwordController.text = generated;
        _obscurePassword = false;
        _errorMessage = null;
      });
    } on ValidationException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(vaultEntriesProvider.notifier);
      final existing = widget.existing;
      if (existing == null) {
        await notifier.createEntry(
          title: _titleController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          url: _urlController.text,
          notes: _notesController.text,
        );
      } else {
        await notifier.updateEntry(
          existing.copyWith(
            title: _titleController.text,
            username: _usernameController.text,
            password: _passwordController.text,
            url: _urlController.text,
            notes: _notesController.text,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Edit Akun Brankas' : 'Tambah Akun Brankas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Akun *',
                hintText: 'Contoh: Email Kantor / Bank Utama',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username / Email',
                hintText: 'nama@contoh.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Kata Sandi *',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _obscurePassword
                          ? 'Tampilkan sandi'
                          : 'Sembunyikan sandi',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Generator kata sandi',
                      icon: Icon(
                        Icons.auto_fix_high_rounded,
                        color: _showGenerator
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      onPressed: () {
                        setState(() {
                          _showGenerator = !_showGenerator;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_showGenerator) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Generator Kata Sandi',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('$_genLength karakter'),
                        ],
                      ),
                      Slider(
                        value: _genLength.toDouble(),
                        min: 8,
                        max: 32,
                        divisions: 24,
                        label: '$_genLength',
                        onChanged: (value) {
                          setState(() {
                            _genLength = value.round();
                          });
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('A-Z'),
                            selected: _genUpper,
                            onSelected: (v) => setState(() => _genUpper = v),
                          ),
                          FilterChip(
                            label: const Text('a-z'),
                            selected: _genLower,
                            onSelected: (v) => setState(() => _genLower = v),
                          ),
                          FilterChip(
                            label: const Text('0-9'),
                            selected: _genDigits,
                            onSelected: (v) => setState(() => _genDigits = v),
                          ),
                          FilterChip(
                            label: const Text('Simbol'),
                            selected: _genSymbols,
                            onSelected: (v) => setState(() => _genSymbols = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _generatePassword,
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Buat Kata Sandi Acak'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL / Situs Web',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan',
                hintText: 'Pertanyaan keamanan, kode pemulihan, dll.',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Menyimpan...' : 'Simpan ke Brankas'),
            ),
          ],
        ),
      ),
    );
  }
}
