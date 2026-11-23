import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/core/utils/file_export_helper.dart';
import 'package:personal_hub/features/backup/providers/backup_providers.dart';
import 'package:personal_hub/features/backup/services/backup_crypto_service.dart';
import 'package:personal_hub/features/backup/services/backup_service.dart';

/// Callback that persists/shares exported `.phub` bytes with a suggested [fileName].
typedef BackupExportHandler =
    Future<void> Function(Uint8List bytes, String fileName);

/// Callback that lets the user choose a `.phub` file and returns its raw bytes,
/// or `null` if the user cancels.
typedef BackupPickHandler = Future<Uint8List?> Function();

/// Settings section providing encrypted `.phub` backup export and restore.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({
    super.key,
    this.onExportFile,
    this.onPickImportBytes,
  });

  final BackupExportHandler? onExportFile;
  final BackupPickHandler? onPickImportBytes;

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GlassIconTile(
                icon: LucideIcons.shieldCheck,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup & Restore (.phub)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enkripsi AES-256-GCM dengan passphrase pribadi Anda.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Mencakup catatan, rapat, brankas sandi, tugas, kebiasaan, transaksi keuangan, riwayat AI, dan preferensi jadwal sholat.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _handleExport,
                icon: const Icon(LucideIcons.upload, size: 17),
                label: const Text('Ekspor Backup (.phub)'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _handleImport,
                icon: const Icon(LucideIcons.download, size: 17),
                label: const Text('Impor Backup (.phub)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    final passphrase = await _showPassphraseDialog(isExport: true);
    if (passphrase == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final bytes = await service.exportEncryptedBytes(passphrase: passphrase);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'personal_hub_backup_$stamp.phub';

      final handler = widget.onExportFile ?? _defaultExportHandler;
      await handler(bytes, fileName);

      if (!mounted) return;
      _showSnackBar('Backup terenkripsi ($fileName) berhasil dibuat.');
    } on ValidationException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Gagal mengekspor berkas backup. Coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isBusy = true);
    Uint8List? bytes;
    try {
      final picker = widget.onPickImportBytes ?? _defaultPickImportBytes;
      bytes = await picker();
    } catch (_) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showSnackBar('Gagal membaca berkas backup.', isError: true);
      }
      return;
    }

    if (!mounted) return;
    if (bytes == null) {
      setState(() => _isBusy = false);
      return;
    }

    setState(() => _isBusy = false);
    final passphrase = await _showPassphraseDialog(isExport: false);
    if (passphrase == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final report = await service.importEncryptedBytes(
        bytes,
        passphrase: passphrase,
      );
      invalidateAllFeatureProviders(ref);

      if (!mounted) return;
      _showSnackBar(_formatRestoreSummary(report));
    } on BackupDecryptionException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message, isError: true);
    } on ValidationException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Gagal memulihkan data dari berkas backup.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _defaultExportHandler(Uint8List bytes, String fileName) async {
    await shareBackupBytes(bytes, fileName);
  }

  Future<Uint8List?> _defaultPickImportBytes() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Pilih berkas backup (.phub)',
      type: FileType.any,
    );
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  Future<String?> _showPassphraseDialog({required bool isExport}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PassphraseDialog(isExport: isExport),
    );
  }

  String _formatRestoreSummary(BackupRestoreReport report) {
    return 'Restore selesai: '
        '${report.notesCount} catatan, '
        '${report.meetingsCount} rapat, '
        '${report.vaultCount} brankas, '
        '${report.tasksCount} tugas, '
        '${report.habitsCount} kebiasaan, '
        '${report.transactionsCount} transaksi.';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.isExport});

  final bool isExport;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassphrase = true;
  String? _errorText;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final passphrase = _passphraseController.text;
    if (widget.isExport) {
      if (passphrase.length < BackupCryptoService.minPassphraseLength) {
        setState(() {
          _errorText = 'Passphrase minimal 6 karakter.';
        });
        return;
      }
      if (passphrase != _confirmController.text) {
        setState(() {
          _errorText = 'Konfirmasi passphrase tidak cocok.';
        });
        return;
      }
    } else if (passphrase.isEmpty) {
      setState(() {
        _errorText = 'Masukkan passphrase backup terlebih dahulu.';
      });
      return;
    }

    Navigator.of(context).pop(passphrase);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.isExport
            ? 'Passphrase Ekspor Backup'
            : 'Passphrase Impor Backup',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isExport
                  ? 'Simpan passphrase ini dengan aman. Tanpa passphrase, berkas .phub tidak dapat didekripsi.'
                  : 'Memulihkan backup akan menggantikan seluruh data lokal saat ini dengan isi berkas .phub.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passphraseController,
              obscureText: _obscurePassphrase,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Passphrase',
                hintText: 'Minimal 6 karakter',
                suffixIcon: IconButton(
                  tooltip: _obscurePassphrase
                      ? 'Tampilkan passphrase'
                      : 'Sembunyikan passphrase',
                  onPressed: () {
                    setState(() {
                      _obscurePassphrase = !_obscurePassphrase;
                    });
                  },
                  icon: Icon(
                    _obscurePassphrase
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!widget.isExport) _submit();
              },
            ),
            if (widget.isExport) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _obscurePassphrase,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Passphrase',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isExport ? 'Ekspor' : 'Pulihkan'),
        ),
      ],
    );
  }
}
