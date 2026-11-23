import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
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

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(vaultEntriesProvider);
    final query = ref.watch(vaultSearchQueryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brankas Kata Sandi'),
        actions: [
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Akun'),
      ),
      body: SafeArea(
        child: Column(
          children: [
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isRevealed ? entry.password : '••••••••••••',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: isRevealed ? 0.5 : 2.0,
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
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Salin Username'),
                      onPressed: onCopyUsername,
                    ),
                  if (entry.url.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.link_rounded, size: 16),
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
