import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Modular sub-page for Vault & App Security settings:
/// PIN, Duress PIN (anti-coercion decoy), and Auto-Lock timeout.
class SecurityVaultSettingsPage extends ConsumerStatefulWidget {
  const SecurityVaultSettingsPage({super.key});

  @override
  ConsumerState<SecurityVaultSettingsPage> createState() =>
      _SecurityVaultSettingsPageState();
}

class _SecurityVaultSettingsPageState
    extends ConsumerState<SecurityVaultSettingsPage> {
  bool _isLoading = true;
  bool _hasPin = false;
  bool _hasDuressPin = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final controller = ref.read(vaultLockControllerProvider);
    final hasPin = await controller.hasPin();
    final hasDuress = await controller.hasDuressPin();
    final canBio = await controller.canUseBiometrics();
    await controller.loadAutoLockTimeout();

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _hasDuressPin = hasDuress;
      _canUseBiometrics = canBio;
      _isLoading = false;
    });
  }

  Future<void> _openPinDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(LucideIcons.keyRound, size: 20, color: AppTokens.primary(context)),
                  const SizedBox(width: 8),
                  Text(_hasPin ? 'Ubah PIN Brankas' : 'Atur PIN Brankas'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pinController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'PIN Baru',
                        hintText: 'Minimal 4 digit angka',
                        prefixIcon: const Icon(LucideIcons.pin),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi PIN Baru',
                        hintText: 'Ulangi PIN yang sama',
                        prefixIcon: Icon(LucideIcons.shieldCheck),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
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
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();
                    if (pin != confirm) {
                      setDialogState(() {
                        errorText = 'Konfirmasi PIN tidak cocok.';
                      });
                      return;
                    }
                    try {
                      await controller.setupPin(pin);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on ValidationException catch (e) {
                      setDialogState(() {
                        errorText = e.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        errorText = 'Gagal menyimpan PIN. Coba lagi.';
                      });
                    }
                  },
                  child: const Text('Simpan PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();

    if (saved == true && mounted) {
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN brankas berhasil diperbarui.')),
      );
    }
  }

  Future<void> _openDuressPinDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(LucideIcons.shieldAlert, size: 20, color: AppTokens.warning(context)),
                  const SizedBox(width: 8),
                  const Text('Atur Duress PIN'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duress PIN adalah PIN umpan darurat. Saat dimasukkan di layar brankas, brankas akan membuka profil alternatif (decoy) yang aman tanpa membocorkan akun asli Anda.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.textSecondary(context),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pinController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duress PIN Baru',
                        hintText: 'Minimal 4 digit angka',
                        prefixIcon: const Icon(LucideIcons.pin),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi Duress PIN',
                        hintText: 'Ulangi PIN umpan',
                        prefixIcon: Icon(LucideIcons.shieldCheck),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
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

    if (saved == true && mounted) {
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duress PIN (PIN Umpan) berhasil dikonfigurasi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(vaultLockControllerProvider);
    final activeTimeout = controller.autoLockTimeout;
    final primary = AppTokens.primary(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTokens.canvas(context),
        appBar: AppBar(title: const Text('Keamanan & Brankas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Keamanan & Brankas'),
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // PIN Utama
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.keyRound, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PIN Utama Brankas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    HubPill(
                      label: _hasPin ? 'Terkonfigurasi' : 'Belum Diatur',
                      color: _hasPin ? AppTokens.success(context) : AppTokens.warning(context),
                      isSelected: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Melindungi seluruh data kata sandi dengan enkripsi AES-256-GCM zero-knowledge.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openPinDialog,
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: Text(_hasPin ? 'Ubah PIN Utama' : 'Atur PIN Utama'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Duress PIN
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.shieldAlert, size: 20, color: AppTokens.warning(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Duress PIN (Anti-Pemaksaan)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    HubPill(
                      label: _hasDuressPin ? 'Aktif' : 'Nonaktif',
                      color: _hasDuressPin ? AppTokens.success(context) : AppTokens.textSecondary(context),
                      isSelected: _hasDuressPin,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hasDuressPin
                      ? 'Duress PIN aktif. Jika dipaksa membuka brankas di bawah ancaman, masukkan PIN ini untuk membuka brankas profil umpan (decoy) tanpa membocorkan data akun asli Anda.'
                      : 'Belum diatur. Konfigurasikan PIN umpan untuk perlindungan ekstra saat berada dalam ancaman atau pemaksaan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openDuressPinDialog,
                  icon: const Icon(LucideIcons.shield, size: 16),
                  label: Text(_hasDuressPin ? 'Ubah Duress PIN' : 'Konfigurasi Duress PIN'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Auto-Lock Timeout
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.timer, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kunci Otomatis (Auto-Lock)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kunci brankas jika aplikasi diminimalkan atau tidak aktif.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
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
                            setState(() {});
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Biometrics
          HubCard(
            child: Row(
              children: [
                Icon(LucideIcons.fingerprint, size: 22, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autentikasi Biometrik',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _canUseBiometrics
                            ? 'Sensor sidik jari / wajah terdeteksi dan aktif.'
                            : 'Sensor biometrik tidak tersedia atau tidak diaktifkan.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                HubPill(
                  label: _canUseBiometrics ? 'Tersedia' : 'Tidak Ada',
                  color: _canUseBiometrics ? AppTokens.success(context) : AppTokens.textSecondary(context),
                  isSelected: _canUseBiometrics,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Kunci Brankas Sekarang
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.error(context),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
            ),
            onPressed: () {
              ref.read(vaultLockControllerProvider).lock();
              Navigator.of(context).pop();
            },
            icon: const Icon(LucideIcons.lock, size: 18),
            label: const Text(
              'Kunci Brankas Sekarang',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
