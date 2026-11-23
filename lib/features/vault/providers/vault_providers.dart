import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/vault/data/vault_repository.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';

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

/// Manages decrypted [VaultEntry] items while the vault is unlocked.
class VaultEntriesNotifier extends AsyncNotifier<List<VaultEntry>> {
  @override
  Future<List<VaultEntry>> build() async {
    final lockController = ref.watch(vaultLockControllerProvider);
    void onLockChanged() {
      if (!lockController.isUnlocked) {
        state = const AsyncData([]);
      } else {
        ref.invalidateSelf();
      }
    }

    lockController.addListener(onLockChanged);
    ref.onDispose(() => lockController.removeListener(onLockChanged));

    if (!lockController.isUnlocked) {
      return const [];
    }
    final query = ref.watch(vaultSearchQueryProvider);
    final entries = await ref
        .watch(vaultRepositoryProvider)
        .getEntries(query: query);
    if (!lockController.isUnlocked) {
      return const [];
    }
    return entries;
  }

  /// Reloads entries from encrypted SQLite storage.
  Future<void> refresh() async {
    final lockController = ref.read(vaultLockControllerProvider);
    if (!lockController.isUnlocked) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final query = ref.read(vaultSearchQueryProvider);
      return ref.read(vaultRepositoryProvider).getEntries(query: query);
    });
  }

  /// Encrypts and inserts a new vault entry, then refreshes the list.
  Future<void> createEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
  }) async {
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
  Future<void> updateEntry(VaultEntry entry) async {
    await ref.read(vaultRepositoryProvider).updateEntry(entry);
    await refresh();
  }

  /// Deletes a vault entry by [id], then refreshes the list.
  Future<void> deleteEntry(String id) async {
    await ref.read(vaultRepositoryProvider).deleteEntry(id);
    await refresh();
  }
}

/// Provides decrypted [VaultEntry] list and CRUD operations while unlocked.
final vaultEntriesProvider =
    AsyncNotifierProvider<VaultEntriesNotifier, List<VaultEntry>>(
      VaultEntriesNotifier.new,
    );
