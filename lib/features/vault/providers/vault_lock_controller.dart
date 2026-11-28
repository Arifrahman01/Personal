import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Manages lock/unlock state for the password vault with PIN, Duress PIN,
/// KEK master-key wrapping, persistent anti-bruteforce lockout, and biometric gates.
class VaultLockController extends ChangeNotifier {
  VaultLockController(
    this._configStore,
    this._crypto,
    this._biometricAuth, {
    DateTime Function()? clock,
    AutoLockTimeout defaultTimeout = AutoLockTimeout.immediate,
  }) : _clock = clock ?? DateTime.now,
       _autoLockTimeout = defaultTimeout;

  static const int minPinLength = 4;
  static const int maxPinLength = 8;
  static const int maxFailedAttemptsBeforeLockout = 5;

  static final RegExp _pinFormatRegex = RegExp(r'^\d{4,8}$');

  final SecureConfigStore _configStore;
  final VaultCryptoService _crypto;
  final BiometricAuthAdapter _biometricAuth;
  DateTime Function() _clock;

  bool _isUnlocked = false;
  bool _isDecoyMode = false;
  AutoLockTimeout _autoLockTimeout;
  DateTime? _pausedAt;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  /// Whether the vault is currently unlocked in memory.
  bool get isUnlocked => _isUnlocked;

  /// Whether the vault was unlocked in decoy mode via Duress PIN.
  bool get isDecoyMode => _isDecoyMode;

  /// The active auto-lock timeout duration setting.
  AutoLockTimeout get autoLockTimeout => _autoLockTimeout;

  /// Number of consecutive failed primary PIN attempts.
  int get failedAttempts => _failedAttempts;

  /// UTC timestamp until which PIN verification is temporarily locked out.
  DateTime? get lockedUntil => _lockedUntil;

  /// Whether brute-force lockout is currently active.
  bool get isLockedOut =>
      _lockedUntil != null && _clock().toUtc().isBefore(_lockedUntil!);

  /// Remaining duration of active lockout, or [Duration.zero].
  Duration get remainingLockoutDuration {
    if (_lockedUntil == null) return Duration.zero;
    final diff = _lockedUntil!.difference(_clock().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

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
    try {
      final seconds = await _configStore.getAutoLockTimeoutSeconds();
      _autoLockTimeout = AutoLockTimeout.fromSeconds(seconds);
      notifyListeners();
    } on MissingPluginException {
      // Ignore in widget environments without registered secure storage plugin.
    } on UnimplementedError {
      // Ignore on unsupported test targets.
    }
  }

  /// Loads persisted brute-force attempt count and lockout timestamp.
  Future<void> loadBruteforceState() async {
    _failedAttempts = await _configStore.getVaultFailedAttempts();
    _lockedUntil = await _configStore.getVaultLockedUntil();
    if (_lockedUntil != null && !_clock().toUtc().isBefore(_lockedUntil!)) {
      _lockedUntil = null;
      await _configStore.setVaultLockedUntil(null);
    }
    notifyListeners();
  }

  /// Sets and persists auto-lock timeout preference.
  ///
  /// When a primary PIN already exists and the vault is locked (or in decoy mode),
  /// requires [currentPin] or [authenticatedViaBiometrics] to prevent bypasses.
  Future<void> setAutoLockTimeout(
    AutoLockTimeout timeout, {
    String? currentPin,
    bool authenticatedViaBiometrics = false,
  }) async {
    if (await hasPin() && (!_isUnlocked || _isDecoyMode)) {
      await _authorizeSensitiveAction(
        currentPin: currentPin,
        authenticatedViaBiometrics: authenticatedViaBiometrics,
        biometricReason: 'Autentikasi untuk mengubah penguncian otomatis',
        missingAuthMessage:
            'Verifikasi PIN utama atau biometrik diperlukan untuk mengubah penguncian otomatis.',
      );
    }
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

  /// Verifies [pin] against the primary PIN hash without altering unlock state.
  /// Enforces persistent anti-bruteforce lockout.
  Future<bool> verifyCurrentPin(String pin) async {
    await loadBruteforceState();
    if (isLockedOut) {
      notifyListeners();
      return false;
    }
    final normalized = pin.trim();
    final storedHash = await _configStore.getVaultPinHash();
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }
    final verified = await _crypto.verifyPin(normalized, storedHash);
    if (verified) {
      await _resetBruteforceState();
      notifyListeners();
      return true;
    }
    await _recordFailedAttempt();
    return false;
  }

  /// Configures or changes a 4–8 digit numeric PIN, hashing it with a random salt
  /// and wrapping the 256-bit Vault Master Key with a PIN-derived KEK.
  ///
  /// When changing an existing PIN, requires [currentPin] or [authenticatedViaBiometrics].
  Future<void> setupPin(
    String pin, {
    String? currentPin,
    bool authenticatedViaBiometrics = false,
  }) async {
    final normalized = pin.trim();
    if (!_pinFormatRegex.hasMatch(normalized)) {
      throw const ValidationException(
        'PIN brankas harus terdiri dari 4 sampai 8 digit angka.',
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

    final alreadyHasPin = await hasPin();
    List<int> masterKey;

    if (!alreadyHasPin) {
      final salt = _crypto.generateSalt();
      final hash = await _crypto.hashPin(normalized, salt: salt);
      await _configStore.setVaultPinHash(hash);
      masterKey = await _configStore.getOrCreateVaultMasterKey(pin: normalized);
    } else {
      await loadBruteforceState();
      if (isLockedOut) {
        throw const ValidationException(
          'Terlalu banyak percobaan salah. Tunggu beberapa saat sebelum mencoba lagi.',
        );
      }

      if (currentPin != null && currentPin.trim().isNotEmpty) {
        final trimmedCurrent = currentPin.trim();
        final storedHash = await _configStore.getVaultPinHash();
        if (storedHash == null ||
            !(await _crypto.verifyPin(trimmedCurrent, storedHash))) {
          await _recordFailedAttempt();
          throw const ValidationException('PIN lama tidak sesuai.');
        }
        masterKey = await _configStore.getOrCreateVaultMasterKey(
          pin: trimmedCurrent,
        );
      } else if (authenticatedViaBiometrics) {
        final available = await _biometricAuth.canAuthenticate();
        if (!available ||
            !(await _biometricAuth.authenticate(
              'Verifikasi identitas untuk mengubah PIN Brankas',
            ))) {
          throw const ValidationException(
            'Verifikasi biometrik gagal atau dibatalkan.',
          );
        }
        final unwrapped = await _configStore.unlockMasterKeyForBiometrics();
        if (unwrapped == null) {
          throw const ValidationException(
            'Masukkan PIN lama untuk memverifikasi perubahan PIN.',
          );
        }
        masterKey = unwrapped;
      } else {
        throw const ValidationException(
          'Autentikasi PIN lama atau biometrik diperlukan untuk mengubah PIN.',
        );
      }

      final salt = _crypto.generateSalt();
      final hash = await _crypto.hashPin(normalized, salt: salt);
      await _configStore.setVaultPinHash(hash);
      await _configStore.storeVaultMasterKey(masterKey, pin: normalized);
    }

    await _configStore.storeBiometricMasterKey(masterKey);
    await _resetBruteforceState();
    notifyListeners();
  }

  /// Configures or changes a 4–8 digit duress numeric PIN.
  ///
  /// When a primary PIN already exists, requires [currentPin] or [authenticatedViaBiometrics].
  Future<void> setupDuressPin(
    String pin, {
    String? currentPin,
    bool authenticatedViaBiometrics = false,
  }) async {
    final normalized = pin.trim();
    if (!_pinFormatRegex.hasMatch(normalized)) {
      throw const ValidationException(
        'Duress PIN brankas harus terdiri dari 4 sampai 8 digit angka.',
      );
    }

    final realPinHash = await _configStore.getVaultPinHash();
    if (realPinHash != null && realPinHash.isNotEmpty) {
      await _authorizeSensitiveAction(
        currentPin: currentPin,
        authenticatedViaBiometrics: authenticatedViaBiometrics,
        biometricReason: 'Verifikasi identitas untuk mengatur Duress PIN',
        missingAuthMessage:
            'Verifikasi PIN utama atau biometrik diperlukan untuk mengatur Duress PIN.',
      );

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
    notifyListeners();
  }

  /// Attempts to unlock the vault with [pin].
  ///
  /// Verifies against real PIN first (unwrapping the KEK-encrypted master key),
  /// then against Duress PIN (unlocking decoy mode while clearing real key memory).
  /// Enforces persistent exponential-style lockout after 5 wrong attempts.
  Future<bool> unlockWithPin(String pin) async {
    await loadBruteforceState();
    if (isLockedOut) {
      notifyListeners();
      return false;
    }

    final normalized = pin.trim();

    final storedHash = await _configStore.getVaultPinHash();
    if (storedHash != null && storedHash.isNotEmpty) {
      final verified = await _crypto.verifyPin(normalized, storedHash);
      if (verified) {
        final masterKey = await _configStore.getOrCreateVaultMasterKey(
          pin: normalized,
        );
        await _configStore.storeBiometricMasterKey(masterKey);
        await _resetBruteforceState();
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
        await _resetBruteforceState();
        _configStore.clearUnlockedMasterKey();
        _isUnlocked = true;
        _isDecoyMode = true;
        notifyListeners();
        return true;
      }
    }

    await _recordFailedAttempt();
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

    final masterKey = await _configStore.unlockMasterKeyForBiometrics();
    if (masterKey == null) {
      return false;
    }

    await _resetBruteforceState();
    _isUnlocked = true;
    _isDecoyMode = false;
    notifyListeners();
    return true;
  }

  /// Locks the vault immediately, scrubs in-memory master key, and resets decoy mode.
  void lock() {
    _pausedAt = null;
    _configStore.clearUnlockedMasterKey();
    if (!_isUnlocked) {
      _isDecoyMode = false;
      return;
    }
    _isUnlocked = false;
    _isDecoyMode = false;
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

  Future<void> _authorizeSensitiveAction({
    String? currentPin,
    required bool authenticatedViaBiometrics,
    required String biometricReason,
    required String missingAuthMessage,
  }) async {
    await loadBruteforceState();
    if (isLockedOut) {
      throw const ValidationException(
        'Terlalu banyak percobaan salah. Tunggu beberapa saat sebelum mencoba lagi.',
      );
    }

    if (currentPin != null && currentPin.trim().isNotEmpty) {
      final storedHash = await _configStore.getVaultPinHash();
      if (storedHash == null ||
          !(await _crypto.verifyPin(currentPin.trim(), storedHash))) {
        await _recordFailedAttempt();
        throw const ValidationException('PIN utama saat ini tidak sesuai.');
      }
      await _resetBruteforceState();
      return;
    }

    if (authenticatedViaBiometrics) {
      final available = await _biometricAuth.canAuthenticate();
      if (!available || !(await _biometricAuth.authenticate(biometricReason))) {
        throw const ValidationException(
          'Verifikasi biometrik gagal atau dibatalkan.',
        );
      }
      await _resetBruteforceState();
      return;
    }

    throw ValidationException(missingAuthMessage);
  }

  Duration _lockoutDurationForAttempts(int attempts) {
    if (attempts < maxFailedAttemptsBeforeLockout) return Duration.zero;
    if (attempts == 5) return const Duration(seconds: 30);
    if (attempts == 6) return const Duration(minutes: 2);
    if (attempts == 7) return const Duration(minutes: 5);
    return const Duration(minutes: 15);
  }

  Future<void> _recordFailedAttempt() async {
    _failedAttempts += 1;
    await _configStore.setVaultFailedAttempts(_failedAttempts);
    final lockout = _lockoutDurationForAttempts(_failedAttempts);
    if (lockout > Duration.zero) {
      _lockedUntil = _clock().toUtc().add(lockout);
      await _configStore.setVaultLockedUntil(_lockedUntil);
    }
    notifyListeners();
  }

  Future<void> _resetBruteforceState() async {
    _failedAttempts = 0;
    _lockedUntil = null;
    await _configStore.resetVaultBruteforceState();
  }
}
