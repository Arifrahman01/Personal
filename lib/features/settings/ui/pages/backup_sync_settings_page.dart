import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/backup/providers/backup_providers.dart';
import 'package:personal_hub/features/backup/providers/gfs_backup_providers.dart';
import 'package:personal_hub/features/backup/ui/backup_section.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';

/// Modular sub-page for Backup & Synchronization:
/// Encrypted .phub manual export/import, real on-disk GFS snapshot rotation
/// (7 Harian • 4 Mingguan • 3 Bulanan), and honest Cloud Sync roadmap status.
class BackupSyncSettingsPage extends ConsumerStatefulWidget {
  const BackupSyncSettingsPage({super.key});

  @override
  ConsumerState<BackupSyncSettingsPage> createState() =>
      _BackupSyncSettingsPageState();
}

class _BackupSyncSettingsPageState
    extends ConsumerState<BackupSyncSettingsPage> {
  bool _isCreatingSnapshot = false;

  @override
  void initState() {
    super.initState();
    _loadDiskSnapshots();
  }

  Future<void> _loadDiskSnapshots() async {
    if (kIsWeb) return;
    try {
      final storage = ref.read(localGfsBackupStorageProvider);
      final service = ref.read(gfsBackupServiceProvider);
      await ref
          .read(gfsSnapshotsProvider.notifier)
          .loadFromDisk(storage, service);
    } catch (_) {
      // Tolerate unavailable storage directories in isolated test environments.
    }
  }

  Future<void> _createGfsBackupNow() async {
    if (kIsWeb) {
      _showSnack(
        'Penyimpanan snapshot lokal ke folder tidak tersedia di Web. Gunakan Ekspor Backup (.phub) di atas.',
        isError: true,
      );
      return;
    }

    final auth = await ensureVaultAuthorizedForBackup(context, ref);
    if (!auth.authorized || !mounted) return;

    try {
      final passphrase = await showBackupPassphraseDialog(
        context,
        isExport: true,
      );
      if (passphrase == null || !mounted) return;

      setState(() => _isCreatingSnapshot = true);

      final backupService = ref.read(backupServiceProvider);
      final gfsService = ref.read(gfsBackupServiceProvider);
      final storage = ref.read(localGfsBackupStorageProvider);

      final bytes = await backupService.exportEncryptedBytes(
        passphrase: passphrase,
      );
      final now = DateTime.now();
      final snapshot = await storage.writeSnapshot(
        bytes: bytes,
        createdAt: now,
        gfsService: gfsService,
      );

      await ref
          .read(gfsSnapshotsProvider.notifier)
          .loadFromDisk(storage, gfsService);

      if (!mounted) return;
      _showSnack(
        'Snapshot terenkripsi (${snapshot.fileName}, ${snapshot.formattedSize}) tersimpan.',
      );
    } on ValidationException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, isError: true);
    } on VaultDecryptionException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Gagal membuat snapshot cadangan: $error', isError: true);
    } finally {
      if (auth.unlockedTemporarily) {
        ref.read(vaultLockControllerProvider).lock();
      }
      if (mounted) {
        setState(() => _isCreatingSnapshot = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTokens.error(context) : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppTokens.primary(context);
    final gfsService = ref.watch(gfsBackupServiceProvider);
    final summary = ref.watch(gfsRetentionSummaryProvider);
    final policy = gfsService.policy;

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Backup & Sinkronisasi'),
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: HubSpacing.lg,
            vertical: HubSpacing.lg,
          ),
          children: [
            const HubSectionHeader(
              title: 'CADANGKAN & PULIHKAN',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),
            const BackupSection(),
            const SizedBox(height: HubSpacing.lg),

            const HubSectionHeader(
              title: 'PENYIMPANAN SNAPSHOT LOKAL',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),

            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        foregroundColor: primary,
                        child: const Icon(Icons.history_rounded, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rotasi Backup Lokal (.phub)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '7 Harian • 4 Mingguan • 3 Bulanan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Menulis arsip .phub terenkripsi asli ke folder dokumen aplikasi dan otomatis menghapus file lama di luar batas retensi (7 harian, 4 mingguan, 3 bulanan).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTokens.textSecondary(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGfsStatCard(
                          title: 'Harian',
                          count: summary.keptDailyCount,
                          max: policy.maxDaily,
                          subtitle: '7 Hari Terakhir',
                          color: AppTokens.info(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGfsStatCard(
                          title: 'Mingguan',
                          count: summary.keptWeeklyCount,
                          max: policy.maxWeekly,
                          subtitle: '4 Minggu Terakhir',
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGfsStatCard(
                          title: 'Bulanan',
                          count: summary.keptMonthlyCount,
                          max: policy.maxMonthly,
                          subtitle: '3 Bulan Terakhir',
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  if (_isCreatingSnapshot) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                    ),
                    onPressed: _isCreatingSnapshot ? null : _createGfsBackupNow,
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: Text(
                      _isCreatingSnapshot
                          ? 'Menyimpan Snapshot...'
                          : 'Buat Snapshot Baru Sekarang',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HubSpacing.lg),
            const HubSectionHeader(
              title: 'SINKRONISASI CLOUD',
              padding: EdgeInsets.symmetric(
                horizontal: HubSpacing.xs,
                vertical: HubSpacing.xs,
              ),
            ),
            const SizedBox(height: HubSpacing.xs),

            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTokens.warning(
                          context,
                        ).withValues(alpha: 0.15),
                        foregroundColor: AppTokens.warning(context),
                        child: const Icon(Icons.cloud_off_rounded, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sinkronisasi Cloud E2EE',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            HubPill(
                              label: 'Dalam Pengembangan',
                              color: AppTokens.warning(context),
                              isSelected: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Transport sinkronisasi otomatis ke server WebDAV, Nextcloud, atau Google Drive belum tersedia pada versi ini. Untuk memindahkan data antar perangkat secara aman, gunakan Ekspor & Impor Backup (.phub) terenkripsi di atas.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTokens.textSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGfsStatCard({
    required String title,
    required int count,
    required int max,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count / $max',
            style: HubTypography.tabular(
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: AppTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
