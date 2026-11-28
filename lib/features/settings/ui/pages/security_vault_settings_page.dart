import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Modular sub-page for Vault & App Security settings:
/// PIN, Duress PIN (anti-coercion decoy), and Auto-Lock timeout.
///
/// Requires verification of the current primary PIN (or biometrics) before
/// altering PINs, Duress PIN, or auto-lock timeout while locked.
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
    await controller.loadBruteforceState();

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _hasDuressPin = hasDuress;
      _canUseBiometrics = canBio;
      _isLoading = false;
    });
  }

  List<TextInputFormatter> get _pinInputFormatters => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(VaultLockController.maxPinLength),
  ];

  Future<void> _openPinDialog() async {
    final controller = ref.read(vaultLockControllerProvider);
    final currentPinController = TextEditingController();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool obscure = true;
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit({bool viaBiometrics = false}) async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin != confirm) {
                setDialogState(() {
                  errorText = 'Konfirmasi PIN tidak cocok.';
                });
                return;
              }
              if (_hasPin &&
                  !viaBiometrics &&
                  currentPinController.text.trim().isEmpty) {
                setDialogState(() {
                  errorText = 'Masukkan PIN utama saat ini terlebih dahulu.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await controller.setupPin(
                  pin,
                  currentPin: _hasPin && !viaBiometrics
                      ? currentPinController.text.trim()
                      : null,
                  authenticatedViaBiometrics: _hasPin && viaBiometrics,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on ValidationException catch (e) {
                setDialogState(() {
                  isSaving = false;
                  errorText = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  isSaving = false;
                  errorText = 'Gagal menyimpan PIN. Coba lagi.';
                });
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    size: 20,
                    color: AppTokens.primary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasPin ? 'Ubah PIN Brankas' : 'Atur PIN Brankas',
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasPin) ...[
                      TextField(
                        controller: currentPinController,
                        obscureText: obscure,
                        keyboardType: TextInputType.number,
                        inputFormatters: _pinInputFormatters,
                        decoration: const InputDecoration(
                          labelText: 'PIN Saat Ini',
                          hintText: 'Masukkan PIN lama (4–8 digit)',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: pinController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      inputFormatters: _pinInputFormatters,
                      decoration: InputDecoration(
                        labelText: 'PIN Baru (4–8 digit)',
                        hintText: '4 sampai 8 digit angka',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
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
                      inputFormatters: _pinInputFormatters,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi PIN Baru',
                        hintText: 'Ulangi PIN yang sama',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    if (_hasPin && _canUseBiometrics) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => submit(viaBiometrics: true),
                        icon: const Icon(Icons.fingerprint_rounded, size: 18),
                        label: const Text('Verifikasi & Simpan via Biometrik'),
                      ),
                    ],
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : () => submit(),
                  child: const Text('Simpan PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPinController.dispose();
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
    final currentPinController = TextEditingController();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool obscure = true;
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit({bool viaBiometrics = false}) async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin != confirm) {
                setDialogState(() {
                  errorText = 'Konfirmasi Duress PIN tidak cocok.';
                });
                return;
              }
              if (_hasPin &&
                  !viaBiometrics &&
                  currentPinController.text.trim().isEmpty) {
                setDialogState(() {
                  errorText = 'Masukkan PIN utama saat ini untuk verifikasi.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await controller.setupDuressPin(
                  pin,
                  currentPin: _hasPin && !viaBiometrics
                      ? currentPinController.text.trim()
                      : null,
                  authenticatedViaBiometrics: _hasPin && viaBiometrics,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on ValidationException catch (e) {
                setDialogState(() {
                  isSaving = false;
                  errorText = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  isSaving = false;
                  errorText = 'Gagal menyimpan Duress PIN. Coba lagi.';
                });
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.gpp_maybe_outlined,
                    size: 20,
                    color: AppTokens.warning(context),
                  ),
                  const SizedBox(width: 8),
                  const Text('Atur Duress PIN'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (_hasPin) ...[
                      TextField(
                        controller: currentPinController,
                        obscureText: obscure,
                        keyboardType: TextInputType.number,
                        inputFormatters: _pinInputFormatters,
                        decoration: const InputDecoration(
                          labelText: 'PIN Utama Saat Ini',
                          hintText: 'Verifikasi PIN utama (4–8 digit)',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: pinController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      inputFormatters: _pinInputFormatters,
                      decoration: InputDecoration(
                        labelText: 'Duress PIN Baru (4–8 digit)',
                        hintText: '4 sampai 8 digit angka',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
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
                      inputFormatters: _pinInputFormatters,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmasi Duress PIN',
                        hintText: 'Ulangi PIN umpan',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    if (_hasPin && _canUseBiometrics) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => submit(viaBiometrics: true),
                        icon: const Icon(Icons.fingerprint_rounded, size: 18),
                        label: const Text('Verifikasi & Simpan via Biometrik'),
                      ),
                    ],
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : () => submit(),
                  child: const Text('Simpan Duress PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPinController.dispose();
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

  Future<void> _updateAutoLockWithAuth(AutoLockTimeout timeout) async {
    final controller = ref.read(vaultLockControllerProvider);
    if (!_hasPin || (controller.isUnlocked && !controller.isDecoyMode)) {
      await controller.setAutoLockTimeout(timeout);
      if (mounted) setState(() {});
      return;
    }

    final pinController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verifyAndSave({bool viaBiometrics = false}) async {
              if (!viaBiometrics && pinController.text.trim().isEmpty) {
                setDialogState(() {
                  errorText = 'Masukkan PIN utama terlebih dahulu.';
                });
                return;
              }
              setDialogState(() {
                isSaving = true;
                errorText = null;
              });
              try {
                await controller.setAutoLockTimeout(
                  timeout,
                  currentPin: viaBiometrics ? null : pinController.text.trim(),
                  authenticatedViaBiometrics: viaBiometrics,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on ValidationException catch (e) {
                setDialogState(() {
                  isSaving = false;
                  errorText = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  isSaving = false;
                  errorText = 'Gagal memverifikasi otorisasi.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Verifikasi Perubahan Auto-Lock'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Masukkan PIN utama brankas untuk mengubah durasi penguncian otomatis.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: _pinInputFormatters,
                    decoration: const InputDecoration(
                      labelText: 'PIN Utama',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    onSubmitted: (_) {
                      if (!isSaving) verifyAndSave();
                    },
                  ),
                  if (_canUseBiometrics) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () => verifyAndSave(viaBiometrics: true),
                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                      label: const Text('Verifikasi dengan Biometrik'),
                    ),
                  ],
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
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : () => verifyAndSave(),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(vaultLockControllerProvider);
    final activeTimeout = controller.autoLockTimeout;
    final primary = AppTokens.primary(context);
    final isDecoyMode = controller.isDecoyMode;

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: HubSpacing.lg,
            vertical: HubSpacing.lg,
          ),
          children: [
            const HubSectionHeader(
              title: 'KUNCI & AKSES BRANKAS',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),
            // PIN Utama
            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 20, color: primary),
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
                        color: _hasPin
                            ? AppTokens.success(context)
                            : AppTokens.warning(context),
                        isSelected: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Melindungi seluruh kata sandi Anda dengan enkripsi lokal yang aman dan terisolasi.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openPinDialog,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(_hasPin ? 'Ubah PIN Utama' : 'Atur PIN Utama'),
                  ),
                ],
              ),
            ),
            if (!isDecoyMode) ...[
              const SizedBox(height: 16),
              // Duress PIN (hidden when unlocked in decoy mode so coercers cannot detect it)
              HubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gpp_maybe_outlined,
                          size: 20,
                          color: AppTokens.warning(context),
                        ),
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
                          color: _hasDuressPin
                              ? AppTokens.success(context)
                              : AppTokens.textSecondary(context),
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
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(
                        _hasDuressPin
                            ? 'Ubah Duress PIN'
                            : 'Konfigurasi Duress PIN',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: HubSpacing.lg),
            const HubSectionHeader(
              title: 'PENGUNCIAN OTOMATIS & BIOMETRIK',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),

            // Auto-Lock Timeout
            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 20, color: primary),
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
                            if (selected && activeTimeout != item.$1) {
                              await _updateAutoLockWithAuth(item.$1);
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
                  Icon(Icons.fingerprint_rounded, size: 22, color: primary),
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
                    color: _canUseBiometrics
                        ? AppTokens.success(context)
                        : AppTokens.textSecondary(context),
                    isSelected: _canUseBiometrics,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Kunci Brankas Sekarang
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
              ),
              onPressed: () {
                ref.read(vaultLockControllerProvider).lock();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text(
                'Kunci Brankas Sekarang',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
