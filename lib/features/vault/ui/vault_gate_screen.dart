import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/vault_list_screen.dart';

/// Root Vault tab widget switching between [VaultGateScreen] and [VaultListScreen].
class VaultTabView extends ConsumerWidget {
  const VaultTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockController = ref.watch(vaultLockControllerProvider);

    return ListenableBuilder(
      listenable: lockController,
      builder: (context, _) {
        if (lockController.isUnlocked) {
          return const VaultListScreen();
        }
        return const VaultGateScreen();
      },
    );
  }
}

/// Biometric and PIN gate displayed whenever the password vault is locked.
class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({super.key});

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasPin = false;
  bool _canUseBiometrics = false;
  bool _obscurePin = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGateState();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadGateState() async {
    final controller = ref.read(vaultLockControllerProvider);
    final hasPin = await controller.hasPin();
    final canBiometric = await controller.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _canUseBiometrics = canBiometric;
      _isLoading = false;
    });
  }

  Future<void> _handleSetupPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    if (pin != confirm) {
      setState(() {
        _errorMessage = 'Konfirmasi PIN tidak cocok.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(vaultLockControllerProvider);
      await controller.setupPin(pin);
      await controller.unlockWithPin(pin);
      _pinController.clear();
      _confirmPinController.clear();
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan PIN brankas. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleUnlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan PIN brankas terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ok = await ref.read(vaultLockControllerProvider).unlockWithPin(pin);
      if (!mounted) return;

      if (ok) {
        _pinController.clear();
      } else {
        setState(() {
          _errorMessage = 'PIN salah. Silakan coba lagi.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memverifikasi PIN. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleUnlockWithBiometrics() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ok = await ref
          .read(vaultLockControllerProvider)
          .unlockWithBiometrics();
      if (!mounted) return;

      if (ok) {
        _pinController.clear();
      } else {
        setState(() {
          _errorMessage = 'Autentikasi biometrik gagal atau dibatalkan.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Terjadi kesalahan saat autentikasi biometrik. Coba lagi atau gunakan PIN.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Brankas Kata Sandi')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.lock_rounded, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _hasPin ? 'Brankas Terkunci' : 'Buat PIN Brankas',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasPin
                            ? 'Masukkan PIN atau gunakan biometrik untuk membuka data kata sandi terenkripsi AES-256-GCM.'
                            : 'Atur PIN minimal 4 digit angka untuk melindungi brankas kata sandi lokal Anda.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        textInputAction: _hasPin
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: (_) {
                          if (_hasPin && !_isSubmitting) {
                            _handleUnlockWithPin();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: _hasPin ? 'PIN Brankas' : 'PIN Baru',
                          hintText: 'Minimal 4 digit angka',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscurePin
                                ? 'Tampilkan PIN'
                                : 'Sembunyikan PIN',
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                        ),
                      ),
                      if (!_hasPin) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPinController,
                          obscureText: _obscurePin,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isSubmitting) {
                              _handleSetupPin();
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Konfirmasi PIN Baru',
                            hintText: 'Ulangi PIN yang sama',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                      ],
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
                      FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : (_hasPin
                                  ? _handleUnlockWithPin
                                  : _handleSetupPin),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _hasPin
                                    ? Icons.lock_open_rounded
                                    : Icons.check_circle_outline_rounded,
                              ),
                        label: Text(
                          _hasPin ? 'Buka Brankas' : 'Simpan PIN & Buka',
                        ),
                      ),
                      if (_hasPin && _canUseBiometrics) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _handleUnlockWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Buka dengan Biometrik'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
