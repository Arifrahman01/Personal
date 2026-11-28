import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/backup/services/backup_crypto_service.dart';
import 'package:personal_hub/features/backup/services/backup_service.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/notes/providers/notes_providers.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Provides [BackupCryptoService] for PBKDF2 + AES-256-GCM `.phub` encryption.
final backupCryptoServiceProvider = Provider<BackupCryptoService>((ref) {
  return BackupCryptoService();
});

/// Provides [BackupService] wired to SQLite, [VaultRepository], [BackupCryptoService], and [SecureConfigStore].
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(vaultRepositoryProvider),
    ref.watch(backupCryptoServiceProvider),
    ref.watch(secureConfigStoreProvider),
  );
});

/// Invalidates all feature data providers so UI reflects restored SQLite state.
void invalidateAllFeatureProviders(WidgetRef ref) {
  ref.invalidate(notesListProvider);
  ref.invalidate(meetingsListProvider);
  ref.invalidate(vaultEntriesProvider);
  ref.invalidate(aiChatControllerProvider);
  ref.invalidate(prayerPrefsProvider);
  ref.invalidate(tasksProvider);
  ref.invalidate(habitsProvider);
  ref.invalidate(habitStatsProvider);
  ref.invalidate(monthlyTransactionsProvider);
  ref.invalidate(monthlySummaryProvider);
}
