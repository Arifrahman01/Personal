import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/core/theme/hub_widgets.dart';
import 'package:personal_hub/features/backup/providers/gfs_backup_providers.dart';
import 'package:personal_hub/features/backup/services/gfs_backup_service.dart';
import 'package:personal_hub/features/backup/ui/backup_section.dart';
import 'package:personal_hub/features/sync/providers/sync_providers.dart';

/// Modular sub-page for Backup & Cloud Synchronization:
/// Encrypted .phub export/import, GFS retention explained in human language
/// (7 Harian • 4 Mingguan • 3 Bulanan), and clean advanced E2EE Cloud Sync panel.
class BackupSyncSettingsPage extends ConsumerStatefulWidget {
  const BackupSyncSettingsPage({super.key});

  @override
  ConsumerState<BackupSyncSettingsPage> createState() =>
      _BackupSyncSettingsPageState();
}

class _BackupSyncSettingsPageState
    extends ConsumerState<BackupSyncSettingsPage> {
  String _syncProvider = 'WebDAV';
  final TextEditingController _syncUrlController = TextEditingController();
  final TextEditingController _syncUsernameController =
      TextEditingController();
  final TextEditingController _syncPasswordController =
      TextEditingController();
  final TextEditingController _syncPassphraseController =
      TextEditingController();
  bool _obscureSyncPassword = true;
  bool _obscureSyncPassphrase = true;

  @override
  void initState() {
    super.initState();
    _loadSyncConfig();
  }

  @override
  void dispose() {
    _syncUrlController.dispose();
    _syncUsernameController.dispose();
    _syncPasswordController.dispose();
    _syncPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _loadSyncConfig() async {
    final config = ref.read(secureConfigStoreProvider);
    final provider = await config.getSyncProvider();
    final url = await config.getSyncServerUrl();
    final user = await config.getSyncUsername();
    final pass = await config.getSyncPassword();
    final passphrase = await config.getSyncPassphrase();

    if (!mounted) return;
    setState(() {
      _syncProvider = provider;
      _syncUrlController.text = url;
      _syncUsernameController.text = user;
      _syncPasswordController.text = pass;
      _syncPassphraseController.text = passphrase;
    });
  }

  Future<void> _saveCloudSyncConfig() async {
    final config = ref.read(secureConfigStoreProvider);
    await config.setSyncProvider(_syncProvider);
    await config.setSyncServerUrl(_syncUrlController.text.trim());
    await config.setSyncUsername(_syncUsernameController.text.trim());
    await config.setSyncPassword(_syncPasswordController.text);
    await config.setSyncPassphrase(_syncPassphraseController.text);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi sinkronisasi cloud berhasil disimpan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSyncNow() async {
    await _saveCloudSyncConfig();
    try {
      final passphrase = _syncPassphraseController.text;
      await ref.read(syncNotifierProvider.notifier).syncNow(passphrase: passphrase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi cloud selesai tanpa kendala.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sinkronisasi gagal: $e'),
          backgroundColor: AppTokens.error(context),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _createGfsBackupNow() {
    final service = ref.read(gfsBackupServiceProvider);
    final now = DateTime.now();
    final tier = service.classifyTier(now);
    final fileName = service.generateSnapshotFileName(createdAt: now, tier: tier);
    final snapshot = BackupSnapshotInfo(
      fileName: fileName,
      createdAt: now,
      tier: tier,
      sizeBytes: 1024 * 64,
    );

    ref.read(gfsSnapshotsProvider.notifier).addSnapshot(snapshot);

    final allSnapshots = ref.read(gfsSnapshotsProvider);
    final eval = service.evaluateRetention(allSnapshots, now);
    if (eval.prune.isNotEmpty) {
      ref.read(gfsSnapshotsProvider.notifier).removeSnapshots(eval.prune);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snapshot cadangan ($fileName) berhasil dibuat.'),
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
    final syncStateAsync = ref.watch(syncNotifierProvider);

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Backup & Sinkronisasi'),
        backgroundColor: AppTokens.canvas(context),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Manual Backup & Restore Section (.phub)
          const BackupSection(),
          const SizedBox(height: 16),

          // 2. Automated GFS Backup (Human Language: 7 Harian • 4 Mingguan • 3 Bulanan)
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
                      child: const Icon(LucideIcons.history, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rotasi Backup Otomatis',
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
                  'Sistem secara cerdas mempertahankan riwayat cadangan tanpa memenuhi memori: 7 hari terakhir disimpan harian, 4 minggu terakhir disimpan mingguan, dan 3 bulan terakhir disimpan sebagai arsip bulanan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTokens.textSecondary(context),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                // 3 Stat Boxes in Human Terms
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
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  onPressed: _createGfsBackupNow,
                  icon: const Icon(LucideIcons.camera, size: 16),
                  label: const Text('Buat Snapshot Baru Sekarang'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Panel Lanjutan: Sinkronisasi Cloud E2EE (Clean Collapsible)
          HubCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: AppTokens.info(context).withValues(alpha: 0.15),
                foregroundColor: AppTokens.info(context),
                child: const Icon(LucideIcons.cloud, size: 20),
              ),
              title: const Text(
                'Sinkronisasi Cloud E2EE (Lanjutan)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                'WebDAV, Nextcloud, atau Google Drive dengan enkripsi end-to-end.',
                style: TextStyle(fontSize: 12, color: AppTokens.textSecondary(context)),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Provider Selector
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'WebDAV',
                        label: Text('WebDAV'),
                        icon: Icon(LucideIcons.folderSync, size: 14),
                      ),
                      ButtonSegment(
                        value: 'Nextcloud',
                        label: Text('Nextcloud'),
                        icon: Icon(LucideIcons.cloudRain, size: 14),
                      ),
                      ButtonSegment(
                        value: 'Google Drive AppData',
                        label: Text('Google Drive'),
                        icon: Icon(LucideIcons.hardDrive, size: 14),
                      ),
                    ],
                    selected: {_syncProvider},
                    onSelectionChanged: (selection) {
                      setState(() => _syncProvider = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Server URL
                TextField(
                  controller: _syncUrlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
                    hintText: _syncProvider == 'Nextcloud'
                        ? 'https://cloud.example.com/remote.php/dav/files/user/'
                        : 'https://dav.example.com/remote.php/webdav/',
                    prefixIcon: const Icon(LucideIcons.globe, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                // Username
                TextField(
                  controller: _syncUsernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Nama pengguna akun cloud',
                    prefixIcon: Icon(LucideIcons.user, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                // Password
                TextField(
                  controller: _syncPasswordController,
                  obscureText: _obscureSyncPassword,
                  decoration: InputDecoration(
                    labelText: 'Password / App Token',
                    hintText: 'Kata sandi atau token aplikasi cloud',
                    prefixIcon: const Icon(LucideIcons.lock, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSyncPassword
                            ? LucideIcons.eye
                            : LucideIcons.eyeOff,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _obscureSyncPassword = !_obscureSyncPassword,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // E2EE Passphrase
                TextField(
                  controller: _syncPassphraseController,
                  obscureText: _obscureSyncPassphrase,
                  decoration: InputDecoration(
                    labelText: 'Master Sync Passphrase (E2EE)',
                    hintText: 'Passphrase enkripsi end-to-end',
                    helperText:
                        'Kunci enkripsi zero-knowledge (server cloud tidak dapat membaca data).',
                    prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSyncPassphrase
                            ? LucideIcons.eye
                            : LucideIcons.eyeOff,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _obscureSyncPassphrase = !_obscureSyncPassphrase,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sync Status Box
                syncStateAsync.when(
                  data: (syncState) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.canvas(context),
                      borderRadius: HubRadius.rSm,
                      border: Border.all(color: AppTokens.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.clock, size: 16, color: primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                syncState.lastSyncTime != null
                                    ? 'Terakhir disinkronkan: ${DateFormat('dd MMM yyyy, HH:mm').format(syncState.lastSyncTime!.toLocal())}'
                                    : 'Status: Belum pernah disinkronkan',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            HubPill(
                              label: '${syncState.pendingCount} Tertunda',
                              isSelected: syncState.pendingCount > 0,
                            ),
                          ],
                        ),
                        if (syncState.isSyncing) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                        if (syncState.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${syncState.errorMessage}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTokens.error(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat status sinkronisasi: $e'),
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                        ),
                        onPressed: syncStateAsync.asData?.value.isSyncing == true
                            ? null
                            : _handleSyncNow,
                        icon: syncStateAsync.asData?.value.isSyncing == true
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Sinkronkan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                        ),
                        onPressed: _saveCloudSyncConfig,
                        icon: const Icon(LucideIcons.save, size: 16),
                        label: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
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
