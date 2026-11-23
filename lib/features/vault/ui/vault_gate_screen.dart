import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

export 'vault_tab_view.dart';

/// Biometric and PIN gate displayed whenever the password vault is locked.
class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({super.key});

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

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
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final keyLabel = event.logicalKey.keyLabel;
    if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _onKeypadDigit(keyLabel);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onKeypadBackspace();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (!_isSubmitting) {
        _handleUnlockWithPin();
      }
    }
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

  void _onKeypadDigit(String digit) {
    if (_pinController.text.length < 8) {
      setState(() {
        _pinController.text = '${_pinController.text}$digit';
        _errorMessage = null;
      });
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

  Widget _buildKeypadButton({
    required Widget content,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = backgroundColor ?? AppTokens.card(context);
    final border = borderColor ?? AppTokens.border(context);
    final primary = AppTokens.primary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        splashColor: primary.withValues(alpha: 0.20),
        highlightColor: primary.withValues(alpha: 0.10),
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cardBg,
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppTokens.primary(context);
    final textPrimary = AppTokens.textPrimary(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTokens.canvas(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pinLength = _pinController.text.length;
    final dotCount = pinLength > 4 ? pinLength : 4;

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Brankas Kata Sandi'),
        backgroundColor: AppTokens.canvas(context),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _hasPin ? _handleKeyEvent : null,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: HubCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shield Icon
                      Center(
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hasPin ? LucideIcons.lock : LucideIcons.shieldCheck,
                            size: 24,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Security Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.10),
                            borderRadius: HubRadius.rPill,
                            border: Border.all(
                              color: primary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.shield, size: 12, color: primary),
                              const SizedBox(width: 5),
                              Text(
                                'Terkunci Aman',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      _hasPin ? 'Brankas Terkunci' : 'Buat PIN Brankas',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasPin
                          ? 'Masukkan PIN (4-8 digit) atau gunakan biometrik.'
                          : 'Atur PIN minimal 4 digit angka untuk melindungi brankas.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTokens.textSecondary(context),
                        height: 1.3,
                      ),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(height: 12),
                      // PIN dots indicator with primary emerald-teal glow
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(dotCount, (index) {
                            final isFilled = index < pinLength;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              width: isFilled ? 16 : 14,
                              height: isFilled ? 16 : 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? primary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                border: Border.all(
                                  color: isFilled
                                      ? primary
                                      : AppTokens.border(context),
                                  width: 1.5,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.45),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Adaptive tactile keypad
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['1', '2', '3'])
                                  _buildKeypadButton(
                                    content: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['4', '5', '6'])
                                  _buildKeypadButton(
                                    content: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['7', '8', '9'])
                                  _buildKeypadButton(
                                    content: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Action / Confirm / Biometric button on left
                                if (pinLength > 0)
                                  _buildKeypadButton(
                                    backgroundColor: primary.withValues(alpha: 0.15),
                                    borderColor: primary.withValues(alpha: 0.5),
                                    content: Icon(
                                      LucideIcons.check,
                                      color: primary,
                                      size: 24,
                                    ),
                                    onTap: _isSubmitting
                                        ? () {}
                                        : _handleUnlockWithPin,
                                  )
                                else if (_canUseBiometrics)
                                  _buildKeypadButton(
                                    content: Icon(
                                      LucideIcons.fingerprint,
                                      color: primary,
                                      size: 24,
                                    ),
                                    onTap: _handleUnlockWithBiometrics,
                                  )
                                else
                                  _buildKeypadButton(
                                    content: Icon(
                                      LucideIcons.rotateCcw,
                                      color: AppTokens.textSecondary(context),
                                      size: 20,
                                    ),
                                    onTap: _onKeypadClear,
                                  ),
                                // Digit 0
                                _buildKeypadButton(
                                  content: Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  onTap: () => _onKeypadDigit('0'),
                                ),
                                // Backspace button
                                _buildKeypadButton(
                                  content: Icon(
                                    LucideIcons.delete,
                                    color: AppTokens.textSecondary(context),
                                    size: 20,
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
                          labelText: 'Buat PIN (min. 4 digit)',
                          hintText: 'Minimal 4 digit angka',
                          prefixIcon: const Icon(LucideIcons.keyRound),
                          suffixIcon: IconButton(
                            tooltip: _obscurePin
                                ? 'Tampilkan PIN'
                                : 'Sembunyikan PIN',
                            icon: Icon(
                              _obscurePin
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                        ),
                      ),
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
                          labelText: 'Ulangi PIN',
                          hintText: 'Ulangi PIN yang sama',
                          prefixIcon: Icon(LucideIcons.shieldCheck),
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTokens.error(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: HubRadius.rSm,
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
                                  ? LucideIcons.lockOpen
                                  : LucideIcons.checkCircle,
                              size: 18,
                            ),
                      label: Text(
                        _hasPin ? 'Buka Brankas' : 'Simpan PIN & Buka',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_hasPin && _canUseBiometrics) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: HubRadius.rSm,
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : _handleUnlockWithBiometrics,
                        icon: const Icon(LucideIcons.fingerprint, size: 18),
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
