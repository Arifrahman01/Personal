import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
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
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    _loadGateState();
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _pinController.dispose();
    _confirmPinController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _syncLockoutTicker(VaultLockController controller) {
    if (controller.isLockedOut) {
      _lockoutTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final ctrl = ref.read(vaultLockControllerProvider);
        if (!ctrl.isLockedOut) {
          _lockoutTicker?.cancel();
          _lockoutTicker = null;
          setState(() {
            _errorMessage = null;
          });
        } else {
          setState(() {});
        }
      });
    } else {
      _lockoutTicker?.cancel();
      _lockoutTicker = null;
    }
  }

  String _formatRemainingLockout(Duration remaining) {
    final totalSeconds = remaining.inSeconds.clamp(1, 3600);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes menit $seconds detik';
    }
    return '$seconds detik';
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
    await controller.loadBruteforceState();
    if (!mounted) return;
    _syncLockoutTicker(controller);
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
    final controller = ref.read(vaultLockControllerProvider);
    if (controller.isLockedOut) {
      _syncLockoutTicker(controller);
      setState(() {
        _errorMessage =
            'Terlalu banyak percobaan salah. Coba lagi dalam ${_formatRemainingLockout(controller.remainingLockoutDuration)}.';
      });
      return;
    }

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
      final ok = await controller.unlockWithPin(pin);
      if (!mounted) return;

      if (ok) {
        _lockoutTicker?.cancel();
        _lockoutTicker = null;
        _pinController.clear();
      } else {
        _pinController.clear();
        _syncLockoutTicker(controller);
        final remainingAttempts =
            VaultLockController.maxFailedAttemptsBeforeLockout -
            controller.failedAttempts;
        setState(() {
          if (controller.isLockedOut) {
            _errorMessage =
                'Terlalu banyak percobaan salah. Brankas dikunci sementara (${_formatRemainingLockout(controller.remainingLockoutDuration)}).';
          } else if (remainingAttempts > 0 && remainingAttempts <= 3) {
            _errorMessage =
                'PIN salah. Sisa $remainingAttempts percobaan sebelum dikunci sementara.';
          } else {
            _errorMessage = 'PIN salah. Silakan coba lagi.';
          }
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
    final controller = ref.read(vaultLockControllerProvider);
    if (controller.isLockedOut || _isSubmitting) return;
    if (_pinController.text.length < VaultLockController.maxPinLength) {
      setState(() {
        _pinController.text = '${_pinController.text}$digit';
        _errorMessage = null;
      });
    }
  }

  void _onKeypadBackspace() {
    if (ref.read(vaultLockControllerProvider).isLockedOut || _isSubmitting) {
      return;
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = HubColors.of(context);
    final cardBg = backgroundColor ?? colors.surfaceCard;
    final border = borderColor ?? colors.borderHairline;
    final primary = colors.primary;

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
                color: theme.colorScheme.shadow.withValues(
                  alpha: isDark ? 0.35 : 0.06,
                ),
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
    final colorScheme = theme.colorScheme;
    final colors = HubColors.of(context);
    final primary = colors.primary;
    final textPrimary = colors.textPrimary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTokens.canvas(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pinLength = _pinController.text.length;
    final dotCount = pinLength > 4 ? pinLength : 4;
    final gold = colors.accentGold;
    final lockController = ref.watch(vaultLockControllerProvider);
    final isLockedOut = lockController.isLockedOut;
    final lockoutMessage = isLockedOut
        ? 'Terlalu banyak percobaan salah. Coba lagi dalam ${_formatRemainingLockout(lockController.remainingLockoutDuration)}.'
        : null;

    return LuxeAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              LuxeIconMedallion(
                icon: Icons.verified_user_rounded,
                color: primary,
                size: 34,
                iconSize: 18,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              const Text(
                'Brankas Kata Sandi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          actions: [
            LuxeHeaderIconButton(
              tooltip: 'AI Copilot',
              icon: Icons.auto_awesome_rounded,
              accentColor: colors.accentAi,
              onPressed: () => MainNavigationShell.openAiChat(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: KeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: _hasPin ? _handleKeyEvent : null,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: HubCard(
                    elevationGlowColor: primary,
                    borderColor: primary.withValues(alpha: 0.25),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Concentric Sanctuary Shield Emblem
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: gold.withValues(alpha: 0.08),
                              border: Border.all(
                                color: gold.withValues(alpha: 0.30),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primary.withValues(alpha: 0.24),
                                    gold.withValues(alpha: 0.14),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Icon(
                                _hasPin
                                    ? Icons.lock_outline_rounded
                                    : Icons.verified_user_outlined,
                                size: 24,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Security Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: HubRadius.rPill,
                              border: Border.all(
                                color: primary.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 12,
                                  color: primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Terkunci Aman',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
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
                          ? 'Masukkan PIN (4–8 digit) atau gunakan biometrik.'
                          : 'Atur PIN 4–8 digit angka untuk melindungi brankas.',
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
                        padding: const EdgeInsets.symmetric(
                          vertical: HubSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(dotCount, (index) {
                            final isFilled = index < pinLength;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: isFilled ? 16 : 14,
                              height: isFilled ? 16 : 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? primary : colors.surfaceSubtle,
                                border: Border.all(
                                  color: isFilled
                                      ? primary
                                      : colors.textSecondary
                                          .withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.40),
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
                      const SizedBox(height: HubSpacing.md),
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
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: HubSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['4', '5', '6'])
                                  _buildKeypadButton(
                                    content: Text(
                                      d,
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: HubSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final d in ['7', '8', '9'])
                                  _buildKeypadButton(
                                    content: Text(
                                      d,
                                      style: HubTypography.tabular(
                                        TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _onKeypadDigit(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: HubSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Action / Confirm / Biometric button on left
                                if (pinLength > 0)
                                  _buildKeypadButton(
                                    backgroundColor: primary.withValues(alpha: 0.15),
                                    borderColor: primary.withValues(alpha: 0.5),
                                    content: Icon(
                                      Icons.check_rounded,
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
                                      Icons.fingerprint_rounded,
                                      color: primary,
                                      size: 24,
                                    ),
                                    onTap: _handleUnlockWithBiometrics,
                                  )
                                else
                                  _buildKeypadButton(
                                    content: Icon(
                                      Icons.refresh_rounded,
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
                                    Icons.backspace_outlined,
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            VaultLockController.maxPinLength,
                          ),
                        ],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Buat PIN (4–8 digit)',
                          hintText: '4 sampai 8 digit angka',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            VaultLockController.maxPinLength,
                          ),
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isSubmitting) {
                            _handleSetupPin();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Ulangi PIN',
                          hintText: 'Ulangi PIN yang sama',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ],
                    if (lockoutMessage != null || _errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        lockoutMessage ?? _errorMessage!,
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
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: HubRadius.rSm,
                        ),
                      ),
                      onPressed: (_isSubmitting || (_hasPin && isLockedOut))
                          ? null
                          : (_hasPin
                              ? _handleUnlockWithPin
                              : _handleSetupPin),
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              _hasPin
                                  ? Icons.lock_open_rounded
                                  : Icons.check_circle_outline_rounded,
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
                        icon: const Icon(Icons.fingerprint_rounded, size: 18),
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
    ),
  );
}
}
