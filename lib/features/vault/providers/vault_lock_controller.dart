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

/// Supported configurable auto-lock timeout durations.
enum AutoLockTimeout {
  immediate(0),
  seconds30(30),
  minute1(60),
  minutes5(300);

  const AutoLockTimeout(this.seconds);
  final int seconds;

  static AutoLockTimeout fromSeconds(int seconds) {
    for (final val in AutoLockTimeout.values) {
      if (val.seconds == seconds) return val;
    }
    return AutoLockTimeout.immediate;
  }
}

/// Manages lock/unlock state for the password vault with PIN, Duress PIN, and biometric gates.
class VaultLockController extends ChangeNotifier {
  VaultLockController(
    this._configStore,
    this._crypto,
    this._biometricAuth, {
    DateTime Function()? clock,
    AutoLockTimeout defaultTimeout = AutoLockTimeout.immediate,
  })  : _clock = clock ?? DateTime.now,
        _autoLockTimeout = defaultTimeout;

  final SecureConfigStore _configStore;
  final VaultCryptoService _crypto;
  final BiometricAuthAdapter _biometricAuth;
  DateTime Function() _clock;

  bool _isUnlocked = false;
  bool _isDecoyMode = false;
  AutoLockTimeout _autoLockTimeout;
  DateTime? _pausedAt;

  /// Whether the vault is currently unlocked in memory.
  bool get isUnlocked => _isUnlocked;

  /// Whether the vault was unlocked in decoy mode via Duress PIN.
  bool get isDecoyMode => _isDecoyMode;

  /// The active auto-lock timeout duration setting.
  AutoLockTimeout get autoLockTimeout => _autoLockTimeout;

  @visibleForTesting
  DateTime? get pausedAt => _pausedAt;

  @visibleForTesting
  void setClockForTesting(DateTime Function() clock) {
    _clock = clock;
  }

  /// Returns whether biometric or device authentication is available.
  Future<bool> canUseBiometrics() => _biometricAuth.canAuthenticate();

  /// Loads persisted auto-lock timeout preference.
  Future<void> loadAutoLockTimeout() async {
    final seconds = await _configStore.getAutoLockTimeoutSeconds();
    _autoLockTimeout = AutoLockTimeout.fromSeconds(seconds);
    notifyListeners();
  }

  /// Sets and persists auto-lock timeout preference.
  Future<void> setAutoLockTimeout(AutoLockTimeout timeout) async {
    _autoLockTimeout = timeout;
    await _configStore.setAutoLockTimeoutSeconds(timeout.seconds);
    notifyListeners();
  }

  /// Returns true if a vault PIN has already been configured.
  Future<bool> hasPin() async {
    return _configStore.hasPin();
  }

  /// Returns true if a duress PIN has already been configured.
  Future<bool> hasDuressPin() async {
    return _configStore.hasDuressPin();
  }

  /// Configures a numeric PIN of at least 4 digits, hashing it with a random salt.
  Future<void> setupPin(String pin) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,}$').hasMatch(normalized)) {
      throw const ValidationException(
        'PIN brankas minimal terdiri dari 4 digit angka.',
      );
    }

    final duressHash = await _configStore.getVaultDuressPinHash();
    if (duressHash != null && duressHash.isNotEmpty) {
      final matchesDuress = await _crypto.verifyPin(normalized, duressHash);
      if (matchesDuress) {
        throw const ValidationException(
          'PIN utama tidak boleh sama dengan Duress PIN.',
        );
      }
    }

    final salt = _crypto.generateSalt();
    final hash = await _crypto.hashPin(normalized, salt: salt);
    await _configStore.setVaultPinHash(hash);
  }

  /// Configures a duress numeric PIN of at least 4 digits, hashing it with a random salt.
  Future<void> setupDuressPin(String pin) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,}$').hasMatch(normalized)) {
      throw const ValidationException(
        'Duress PIN brankas minimal terdiri dari 4 digit angka.',
      );
    }

    final realPinHash = await _configStore.getVaultPinHash();
    if (realPinHash != null && realPinHash.isNotEmpty) {
      final matchesReal = await _crypto.verifyPin(normalized, realPinHash);
      if (matchesReal) {
        throw const ValidationException(
          'Duress PIN tidak boleh sama dengan PIN utama.',
        );
      }
    }

    final salt = _crypto.generateSalt();
    final hash = await _crypto.hashPin(normalized, salt: salt);
    await _configStore.setVaultDuressPinHash(hash);
  }

  /// Attempts to unlock the vault with [pin].
  ///
  /// Verifies against real PIN first (unlocking normal mode), then against Duress PIN (unlocking decoy mode).
  Future<bool> unlockWithPin(String pin) async {
    final normalized = pin.trim();

    final storedHash = await _configStore.getVaultPinHash();
    if (storedHash != null && storedHash.isNotEmpty) {
      final verified = await _crypto.verifyPin(normalized, storedHash);
      if (verified) {
        _isUnlocked = true;
        _isDecoyMode = false;
        notifyListeners();
        return true;
      }
    }

    final duressHash = await _configStore.getVaultDuressPinHash();
    if (duressHash != null && duressHash.isNotEmpty) {
      final verifiedDuress = await _crypto.verifyPin(normalized, duressHash);
      if (verifiedDuress) {
        _isUnlocked = true;
        _isDecoyMode = true;
        notifyListeners();
        return true;
      }
    }

    return false;
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
    _isDecoyMode = false;
    notifyListeners();
    return true;
  }

  /// Locks the vault immediately and resets decoy mode.
  void lock() {
    _pausedAt = null;
    if (!_isUnlocked) {
      _isDecoyMode = false;
      return;
    }
    _isUnlocked = false;
    _isDecoyMode = false;
    _configStore.clearUnlockedMasterKey();
    notifyListeners();
  }

  /// Handles app lifecycle state transitions to trigger auto-lock based on configured timeout.
  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_autoLockTimeout == AutoLockTimeout.immediate) {
          lock();
        } else {
          _pausedAt ??= _clock();
        }
      case AppLifecycleState.resumed:
        if (_autoLockTimeout != AutoLockTimeout.immediate && _pausedAt != null) {
          final elapsed = _clock().difference(_pausedAt!);
          _pausedAt = null;
          if (elapsed >= Duration(seconds: _autoLockTimeout.seconds)) {
            lock();
          }
        } else {
          _pausedAt = null;
        }
    }
  }
}
