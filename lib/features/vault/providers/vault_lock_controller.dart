import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

/// Abstraction over platform biometric authentication for testability.
abstract interface class BiometricAuthAdapter {
  Future<bool> canAuthenticate();
  Future<bool> authenticate(String reason);
}

/// Default [BiometricAuthAdapter] backed by [LocalAuthentication].
class LocalAuthBiometricAdapter implements BiometricAuthAdapter {
  LocalAuthBiometricAdapter([LocalAuthentication? localAuth])
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Manages lock/unlock state for the password vault with PIN and biometric gates.
class VaultLockController extends ChangeNotifier {
  VaultLockController(
    this._configStore,
    this._crypto,
    this._biometricAuth,
  );

  final SecureConfigStore _configStore;
  final VaultCryptoService _crypto;
  final BiometricAuthAdapter _biometricAuth;

  bool _isUnlocked = false;

  /// Whether the vault is currently unlocked in memory.
  bool get isUnlocked => _isUnlocked;

  /// Returns whether biometric or device authentication is available.
  Future<bool> canUseBiometrics() => _biometricAuth.canAuthenticate();

  /// Returns true if a vault PIN has already been configured.
  Future<bool> hasPin() async {
    final stored = await _configStore.getVaultPinHash();
    return stored != null && stored.isNotEmpty;
  }

  /// Configures a numeric PIN of at least 4 digits, hashing it with a random salt.
  Future<void> setupPin(String pin) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,}$').hasMatch(normalized)) {
      throw const ValidationException(
        'PIN brankas minimal terdiri dari 4 digit angka.',
      );
    }

    final salt = _crypto.generateSalt();
    final hash = await _crypto.hashPin(normalized, salt: salt);
    await _configStore.setVaultPinHash(hash);
  }

  /// Attempts to unlock the vault with [pin].
  Future<bool> unlockWithPin(String pin) async {
    final storedHash = await _configStore.getVaultPinHash();
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }

    final verified = await _crypto.verifyPin(pin.trim(), storedHash);
    if (!verified) {
      return false;
    }

    _isUnlocked = true;
    notifyListeners();
    return true;
  }

  /// Attempts to unlock the vault using platform biometrics.
  Future<bool> unlockWithBiometrics() async {
    final available = await _biometricAuth.canAuthenticate();
    if (!available) {
      return false;
    }

    final authenticated = await _biometricAuth.authenticate(
      'Autentikasi untuk membuka Brankas Kata Sandi',
    );
    if (!authenticated) {
      return false;
    }

    _isUnlocked = true;
    notifyListeners();
    return true;
  }

  /// Locks the vault immediately.
  void lock() {
    if (!_isUnlocked) return;
    _isUnlocked = false;
    notifyListeners();
  }

  /// Immediately locks the vault when the app leaves the foreground.
  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        lock();
      case AppLifecycleState.resumed:
        break;
    }
  }
}
