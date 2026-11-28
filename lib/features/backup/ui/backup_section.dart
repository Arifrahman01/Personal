import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/core/utils/file_export_helper.dart';
import 'package:personal_hub/features/backup/providers/backup_providers.dart';
import 'package:personal_hub/features/backup/services/backup_crypto_service.dart';
import 'package:personal_hub/features/backup/services/backup_service.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Callback that persists/shares exported `.phub` bytes with a suggested [fileName].
typedef BackupExportHandler =
    Future<void> Function(Uint8List bytes, String fileName);

/// Callback that lets the user choose a `.phub` file and returns its raw bytes,
/// or `null` if the user cancels.
typedef BackupPickHandler = Future<Uint8List?> Function();

/// Verifies Vault authorization before exporting encrypted backups containing Vault data.
///
/// If a Vault PIN is configured and the Vault is currently locked or in decoy mode,
/// prompts the user to unlock with the primary PIN or biometrics, and returns
/// `unlockedTemporarily = true` so callers can re-lock immediately after export.
Future<({bool authorized, bool unlockedTemporarily})>
ensureVaultAuthorizedForBackup(BuildContext context, WidgetRef ref) async {
  final lockController = ref.read(vaultLockControllerProvider);
  var hasPin = false;
  try {
    hasPin = await lockController.hasPin();
  } on MissingPluginException {
    hasPin = false;
  } on UnimplementedError {
    hasPin = false;
  }

  if (!hasPin) {
    return (authorized: true, unlockedTemporarily: false);
  }

  if (lockController.isUnlocked && !lockController.isDecoyMode) {
    return (authorized: true, unlockedTemporarily: false);
  }

  if (!context.mounted) {
    return (authorized: false, unlockedTemporarily: false);
  }

  final canBiometrics = await lockController.canUseBiometrics().catchError(
    (_) => false,
  );
  if (!context.mounted) {
    return (authorized: false, unlockedTemporarily: false);
  }

  final unlocked = await showDialog<bool>(
    context: context,
    builder: (_) => _VaultBackupAuthDialog(
      lockController: lockController,
      canUseBiometrics: canBiometrics,
    ),
  );

  return (
    authorized: unlocked == true,
    unlockedTemporarily: unlocked == true,
  );
}

/// Prompts the user for a backup encryption/decryption passphrase.
Future<String?> showBackupPassphraseDialog(
  BuildContext context, {
  required bool isExport,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(isExport: isExport),
  );
}

/// Settings section providing encrypted `.phub` backup export and restore,
/// and clear human explanation of backup rotation.
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
    final colorScheme = theme.colorScheme;
    final primary = AppTokens.primary(context);

    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primary.withValues(alpha: 0.15),
                foregroundColor: primary,
                child: const Icon(Icons.verified_user_outlined, size: 20),
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
                      'Simpan cadangan terenkripsi dengan passphrase pribadi Anda.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Mencakup catatan, agenda meeting, brankas sandi, tugas, kebiasaan, transaksi keuangan, riwayat AI, dan jadwal sholat.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTokens.textSecondary(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: HubRadius.rSm,
              border: Border.all(color: primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rotasi Otomatis: 7 Harian • 4 Mingguan • 3 Bulanan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
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
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                ),
                onPressed: _isBusy ? null : _handleExport,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Ekspor Backup (.phub)'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                ),
                onPressed: _isBusy ? null : _handleImport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Impor Backup (.phub)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    final auth = await ensureVaultAuthorizedForBackup(context, ref);
    if (!auth.authorized || !mounted) return;

    try {
      final passphrase = await showBackupPassphraseDialog(
        context,
        isExport: true,
      );
      if (passphrase == null || !mounted) return;

      setState(() => _isBusy = true);
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
    } on VaultDecryptionException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Gagal mengekspor berkas backup. Coba lagi.',
        isError: true,
      );
    } finally {
      if (auth.unlockedTemporarily) {
        ref.read(vaultLockControllerProvider).lock();
      }
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
      if (!mounted) return;
      _showSnackBar('Gagal membaca berkas backup.', isError: true);
      setState(() => _isBusy = false);
      return;
    }

    if (bytes == null || !mounted) {
      setState(() => _isBusy = false);
      return;
    }

    setState(() => _isBusy = false);
    final passphrase = await showBackupPassphraseDialog(
      context,
      isExport: false,
    );
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
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Pilih berkas backup (.phub)',
      type: FileType.any,
    );
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTokens.error(context) : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _VaultBackupAuthDialog extends StatefulWidget {
  const _VaultBackupAuthDialog({
    required this.lockController,
    required this.canUseBiometrics,
  });

  final VaultLockController lockController;
  final bool canUseBiometrics;

  @override
  State<_VaultBackupAuthDialog> createState() => _VaultBackupAuthDialogState();
}

class _VaultBackupAuthDialogState extends State<_VaultBackupAuthDialog> {
  final _pinController = TextEditingController();
  bool _isVerifying = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Masukkan PIN utama Brankas terlebih dahulu.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final ok = await widget.lockController.unlockWithPin(pin);
      if (!mounted) return;
      if (ok && !widget.lockController.isDecoyMode) {
        Navigator.of(context).pop(true);
        return;
      }
      if (ok && widget.lockController.isDecoyMode) {
        widget.lockController.lock();
      }
      setState(() {
        _isVerifying = false;
        _errorText = widget.lockController.isLockedOut
            ? 'Terlalu banyak percobaan salah. Coba lagi nanti.'
            : 'PIN utama Brankas tidak sesuai.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = 'Gagal memverifikasi PIN Brankas.';
      });
    }
  }

  Future<void> _verifyBiometrics() async {
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });
    try {
      final ok = await widget.lockController.unlockWithBiometrics();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isVerifying = false;
        _errorText = 'Autentikasi biometrik gagal atau dibatalkan.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = 'Autentikasi biometrik gagal.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verifikasi Brankas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cadangan .phub menyertakan entri Brankas Anda. Masukkan PIN utama Brankas untuk melanjutkan ekspor.',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pinController,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  VaultLockController.maxPinLength,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'PIN Utama Brankas',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onSubmitted: (_) {
                if (!_isVerifying) _verifyPin();
              },
            ),
            if (widget.canUseBiometrics) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : _verifyBiometrics,
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text('Verifikasi dengan Biometrik'),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(
                  color: AppTokens.error(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _verifyPin,
          child: const Text('Verifikasi'),
        ),
      ],
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
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.textSecondary(context),
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
                style: TextStyle(
                  color: AppTokens.error(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
