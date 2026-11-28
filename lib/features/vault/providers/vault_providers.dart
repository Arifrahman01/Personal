import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

/// Generates realistic decoy entries with recent timestamps when the vault is
/// unlocked in decoy mode (via Duress PIN).
List<VaultEntry> createDefaultDecoyEntries([DateTime? nowUtc]) {
  final now = (nowUtc ?? DateTime.now()).toUtc();
  return [
    VaultEntry(
      id: 'decoy-1',
      title: 'Wi-Fi Tamu',
      username: 'Tamu-Rumah-5G',
      password: 'KopiHangatPagi123!',
      url: '',
      notes: 'Koneksi Wi-Fi ruang tamu',
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 12)),
    ),
    VaultEntry(
      id: 'decoy-2',
      title: 'Akun Media Sosial Baca',
      username: 'bacaan_harian',
      password: 'AmanSandi@2025',
      url: 'https://instagram.com',
      notes: 'Akun publik untuk browsing artikel dan buku',
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 7)),
    ),
    VaultEntry(
      id: 'decoy-3',
      title: 'Wi-Fi Kafe Langganan',
      username: 'KopiSantai_Guest',
      password: 'ManualBrew2025!',
      url: '',
      notes: 'Password Wi-Fi kafe sudut jalan',
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

List<VaultEntry> filterDecoyEntries(
  String query, {
  List<VaultEntry>? entries,
}) {
  final source = entries ?? createDefaultDecoyEntries();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return List.unmodifiable(source);
  }
  return source
      .where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.username.toLowerCase().contains(q) ||
            e.url.toLowerCase().contains(q),
      )
      .toList();
}

/// Provides [VaultCryptoService] for AES-256-GCM encryption and PIN hashing.
final vaultCryptoServiceProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

/// Provides [VaultRepository] backed by SQLite and [SecureConfigStore].
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureConfigStoreProvider),
    ref.watch(vaultCryptoServiceProvider),
  );
});

/// Provides [ClipboardAdapter] for system clipboard access.
final clipboardAdapterProvider = Provider<ClipboardAdapter>((ref) {
  return FlutterClipboardAdapter();
});

/// Provides [ClipboardGuard] with automatic timer cleanup on disposal.
final clipboardGuardProvider = Provider<ClipboardGuard>((ref) {
  final guard = ClipboardGuard(ref.watch(clipboardAdapterProvider));
  ref.onDispose(guard.dispose);
  return guard;
});

/// Provides [BiometricAuthAdapter] backed by `local_auth`.
final biometricAuthAdapterProvider = Provider<BiometricAuthAdapter>((ref) {
  return LocalAuthBiometricAdapter();
});

/// Provides [VaultLockController] managing PIN/biometric gate and lifecycle auto-lock.
final vaultLockControllerProvider = Provider<VaultLockController>((ref) {
  final controller = VaultLockController(
    ref.watch(secureConfigStoreProvider),
    ref.watch(vaultCryptoServiceProvider),
    ref.watch(biometricAuthAdapterProvider),
  );
  controller.loadAutoLockTimeout();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Holds the current search query for [VaultListScreen].
class VaultSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

/// Provides the search filter query for vault entries.
final vaultSearchQueryProvider =
    NotifierProvider<VaultSearchQueryNotifier, String>(
      VaultSearchQueryNotifier.new,
    );

class _VaultDecoySessionStore {
  List<VaultEntry>? _entries;

  List<VaultEntry> get entries =>
      _entries ??= List<VaultEntry>.from(createDefaultDecoyEntries());

  void clear() {
    _entries = null;
  }

  void addEntry(VaultEntry entry) {
    entries.add(entry);
  }

  void updateEntry(VaultEntry entry) {
    final list = entries;
    final idx = list.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      list[idx] = entry.copyWith(updatedAt: DateTime.now().toUtc());
    }
  }

  void deleteEntry(String id) {
    entries.removeWhere((e) => e.id == id);
  }
}

final _vaultDecoySessionStoreProvider = Provider<_VaultDecoySessionStore>((
  ref,
) {
  final store = _VaultDecoySessionStore();
  ref.onDispose(store.clear);
  return store;
});

/// Manages decrypted [VaultEntry] items while the vault is unlocked.
class VaultEntriesNotifier extends AsyncNotifier<List<VaultEntry>> {
  VaultLockController? _subscribedLockController;
  VoidCallback? _lockListener;
  bool _disposeRegistered = false;

  void _onLockChanged() {
    final lockController = _subscribedLockController;
    if (lockController == null) return;
    if (!lockController.isUnlocked) {
      ref.read(_vaultDecoySessionStoreProvider).clear();
      state = const AsyncData([]);
    } else {
      if (!lockController.isDecoyMode) {
        ref.read(_vaultDecoySessionStoreProvider).clear();
      }
      ref.invalidateSelf();
    }
  }

  void _ensureLockListener(VaultLockController controller) {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(_cleanupLockListener);
    }
    if (_subscribedLockController == controller) return;

    _removeLockListener();
    _subscribedLockController = controller;
    _lockListener = _onLockChanged;
    controller.addListener(_onLockChanged);
  }

  void _removeLockListener() {
    if (_subscribedLockController != null && _lockListener != null) {
      _subscribedLockController!.removeListener(_lockListener!);
      _subscribedLockController = null;
      _lockListener = null;
    }
  }

  void _cleanupLockListener() {
    _removeLockListener();
    _disposeRegistered = false;
  }

  @override
  Future<List<VaultEntry>> build() async {
    final lockController = ref.watch(vaultLockControllerProvider);
    _ensureLockListener(lockController);

    if (!lockController.isUnlocked) {
      return const [];
    }

    if (lockController.isDecoyMode) {
      final query = ref.watch(vaultSearchQueryProvider);
      final decoyEntries = ref.read(_vaultDecoySessionStoreProvider).entries;
      return filterDecoyEntries(query, entries: decoyEntries);
    }

    final query = ref.watch(vaultSearchQueryProvider);
    final entries = await ref
        .watch(vaultRepositoryProvider)
        .getEntries(query: query);
    if (!lockController.isUnlocked || lockController.isDecoyMode) {
      return const [];
    }
    return entries;
  }

  /// Reloads entries from encrypted SQLite storage or decoy list.
  Future<void> refresh() async {
    final lockController = ref.read(vaultLockControllerProvider);
    if (!lockController.isUnlocked) {
      ref.read(_vaultDecoySessionStoreProvider).clear();
      state = const AsyncData([]);
      return;
    }
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // State already holds AsyncError when build() fails.
    }
  }

  /// Encrypts and inserts a new vault entry, then refreshes the list.
  /// In decoy mode, updates only ephemeral in-memory decoy entries without touching SQLite.
  Future<void> createEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
  }) async {
    final lockController = ref.read(vaultLockControllerProvider);
    if (lockController.isDecoyMode) {
      final now = DateTime.now().toUtc();
      ref.read(_vaultDecoySessionStoreProvider).addEntry(
            VaultEntry(
              id: 'decoy-${now.microsecondsSinceEpoch}',
              title: title.trim(),
              username: username.trim(),
              password: password,
              url: url.trim(),
              notes: notes,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await refresh();
      return;
    }
    await ref
        .read(vaultRepositoryProvider)
        .createEntry(
          title: title,
          username: username,
          password: password,
          url: url,
          notes: notes,
        );
    await refresh();
  }

  /// Encrypts and updates an existing vault entry, then refreshes the list.
  /// In decoy mode, updates only ephemeral in-memory decoy entries without touching SQLite.
  Future<void> updateEntry(VaultEntry entry) async {
    final lockController = ref.read(vaultLockControllerProvider);
    if (lockController.isDecoyMode) {
      ref.read(_vaultDecoySessionStoreProvider).updateEntry(entry);
      await refresh();
      return;
    }
    await ref.read(vaultRepositoryProvider).updateEntry(entry);
    await refresh();
  }

  /// Deletes a vault entry by [id], then refreshes the list.
  /// In decoy mode, updates only ephemeral in-memory decoy entries without touching SQLite.
  Future<void> deleteEntry(String id) async {
    final lockController = ref.read(vaultLockControllerProvider);
    if (lockController.isDecoyMode) {
      ref.read(_vaultDecoySessionStoreProvider).deleteEntry(id);
      await refresh();
      return;
    }
    await ref.read(vaultRepositoryProvider).deleteEntry(id);
    await refresh();
  }
}

/// Provides decrypted [VaultEntry] list and CRUD operations while unlocked.
final vaultEntriesProvider =
    AsyncNotifierProvider<VaultEntriesNotifier, List<VaultEntry>>(
      VaultEntriesNotifier.new,
    );
