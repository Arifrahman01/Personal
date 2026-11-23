import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
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

  Widget _buildCircularKeypadButton({
    required Widget content,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        splashColor: RefleqPalette.lavender.withValues(alpha: 0.30),
        highlightColor: RefleqPalette.lavender.withValues(alpha: 0.15),
        onTap: onTap,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RefleqPalette.surfaceCard.withValues(alpha: 0.85),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  void _onKeypadDigit(String digit) {
    if (_pinController.text.length < 8) {
      setState(() {
        _pinController.text = '${_pinController.text}$digit';
        _errorMessage = null;
      });
      if (_hasPin && _pinController.text.length == 4) {
        _handleUnlockWithPin();
      }
    }
  }

  void _onKeypadBackspace() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onKeypadClear() {
    setState(() {
      _pinController.clear();
      _confirmPinController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const GlassScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Brankas Kata Sandi')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassCard(
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GlassIconTile(
                        icon: _hasPin
                            ? Icons.lock_outline_rounded
                            : Icons.shield_outlined,
                        size: 48,
                        iconSize: 24,
                        color: RefleqPalette.lavender,
                        backgroundColor: RefleqPalette.lavenderSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // High-contrast security badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: RefleqPalette.surfaceCard,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: RefleqPalette.lavender.withValues(
                              alpha: 0.45,
                            ),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: RefleqPalette.lavender.withValues(
                                alpha: 0.20,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 14,
                              color: RefleqPalette.lavender,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AES-256-GCM Zero-Knowledge',
                              style: TextStyle(
                                color: RefleqPalette.lavender,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hasPin ? 'Brankas Terkunci' : 'Buat PIN Brankas',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasPin
                          ? 'Masukkan PIN atau gunakan biometrik untuk membuka data kata sandi terenkripsi AES-256-GCM.'
                          : 'Atur PIN minimal 4 digit angka untuk melindungi brankas kata sandi lokal Anda.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(height: 16),
                      // Lavender glow PIN dots
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled =
                                index < _pinController.text.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: isFilled ? 18 : 16,
                              height: isFilled ? 18 : 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isFilled
                                    ? RefleqPalette.lavenderCloud
                                    : null,
                                color: isFilled
                                    ? null
                                    : Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: isFilled
                                      ? const Color(0xFFC4B5FD)
                                      : Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFA78BFA)
                                              .withValues(alpha: 0.70),
                                          blurRadius: 14,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      // Accessible text field keeping controller in sync with keyboard/tests
                      SizedBox(
                        height: 0,
                        width: 0,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (!_isSubmitting) {
                                _handleUnlockWithPin();
                              }
                            },
                          ),
                        ),
                      ),
                      // Obsidian glass keypad with circular number buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['1', '2', '3'])
                                  _buildCircularKeypadButton(
                                    content: Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['4', '5', '6'])
                                  _buildCircularKeypadButton(
                                    content: Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['7', '8', '9'])
                                  _buildCircularKeypadButton(
                                    content: Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_canUseBiometrics)
                                  _buildCircularKeypadButton(
                                    content: const Icon(
                                      Icons.fingerprint_rounded,
                                      color: RefleqPalette.lavender,
                                      size: 28,
                                    ),
                                    onTap: _handleUnlockWithBiometrics,
                                  )
                                else
                                  _buildCircularKeypadButton(
                                    content: const Icon(
                                      Icons.clear_rounded,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                    onTap: _onKeypadClear,
                                  ),
                                _buildCircularKeypadButton(
                                  content: const Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onTap: () => _onKeypadDigit('0'),
                                ),
                                _buildCircularKeypadButton(
                                  content: const Icon(
                                    Icons.backspace_outlined,
                                    color: Colors.white70,
                                    size: 22,
                                  ),
                                  onTap: _onKeypadBackspace,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'PIN Baru',
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
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: RefleqPalette.lavender,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _hasPin
                                  ? Icons.lock_open_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                      label: Text(
                        _hasPin ? 'Buka Brankas' : 'Simpan PIN & Buka',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_hasPin && _canUseBiometrics) ...[
                      const SizedBox(height: 10),
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
    );
  }
}
