import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/core/notifications/notification_bootstrap_service.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/prayer/providers/prayer_providers.dart';
import 'package:personal_hub/features/prayer/services/firebase_adzan_service.dart';

/// Bottom Sheet 'Pengaturan Adzan & Lanjutan' (Hisab, Notifikasi, Pre-adzan, FCM).
class AdzanSettingsSheet extends ConsumerWidget {
  const AdzanSettingsSheet({
    super.key,
    required this.prefs,
    required this.fcmStatus,
    required this.onSyncFcm,
    required this.onCopyToken,
  });

  final PrayerAlarmPrefs prefs;
  final FirebaseAdzanStatus fcmStatus;
  final Future<FirebaseAdzanStatus> Function() onSyncFcm;
  final Future<void> Function(String token) onCopyToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(prayerPrefsProvider.notifier);
    final topicName = FirebaseAdzanService.cityTopicName(prefs.cityName);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pengaturan Adzan & Lanjutan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Mode Notifikasi Adzan',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AdzanNotificationMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AdzanNotificationMode.firebaseFcm,
                  label: Text(
                    'FCM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: Icon(Icons.cloud_outlined, size: 16),
                ),
                ButtonSegment(
                  value: AdzanNotificationMode.localOffline,
                  label: Text(
                    'Lokal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: Icon(Icons.notifications_outlined, size: 16),
                ),
                ButtonSegment(
                  value: AdzanNotificationMode.both,
                  label: Text(
                    'Keduanya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: Icon(Icons.sync_rounded, size: 16),
                ),
              ],
              selected: {prefs.notificationMode},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  notifier.setNotificationMode(selection.first);
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.card(context),
                borderRadius: HubRadius.rSm,
                border: Border.all(color: AppTokens.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Notifikasi Server',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: Icon(
                          fcmStatus.isConfigured
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: fcmStatus.isConfigured
                              ? AppTokens.success(context)
                              : AppTokens.textSecondary(context),
                        ),
                        label: Text(
                          fcmStatus.isConfigured
                              ? 'FCM Aktif'
                              : 'FCM Belum Dikonfigurasi',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.tag_rounded, size: 14),
                        label: Text(
                          topicName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (fcmStatus.message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      fcmStatus.message!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTokens.textSecondary(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onSyncFcm,
                        icon: const Icon(Icons.sync_rounded, size: 14),
                        label: const Text('Sinkronkan FCM'),
                      ),
                      if (fcmStatus.fcmToken != null &&
                          fcmStatus.fcmToken!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => onCopyToken(fcmStatus.fcmToken!),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Salin Token'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pengaturan Hisab & Pengingat',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DropdownMenu<PrayerMethod>(
              initialSelection: prefs.method,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Metode Hisab'),
              dropdownMenuEntries: [
                for (final m in PrayerMethod.values)
                  DropdownMenuEntry(value: m, label: m.label),
              ],
              onSelected: (value) {
                if (value != null) {
                  notifier.setMethod(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownMenu<int>(
              initialSelection: prefs.preReminderMinutes,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Pengingat Sebelum Adzan'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 0, label: 'Tidak ada'),
                DropdownMenuEntry(value: 5, label: '5 menit sebelum'),
                DropdownMenuEntry(value: 10, label: '10 menit sebelum'),
                DropdownMenuEntry(value: 15, label: '15 menit sebelum'),
              ],
              onSelected: (value) {
                if (value != null) {
                  notifier.setPreReminderMinutes(value);
                }
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suara Adzan / Notifikasi'),
              subtitle: const Text(
                'Putar suara notifikasi saat waktu sholat tiba',
              ),
              value: prefs.soundEnabled,
              onChanged: notifier.setSoundEnabled,
            ),
            const SizedBox(height: 16),
            const _NotificationDiagnosticCard(),
          ],
        ),
      ),
    );
  }
}

class _NotificationDiagnosticCard extends ConsumerWidget {
  const _NotificationDiagnosticCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagAsync = ref.watch(notificationDiagnosticProvider);
    final colors = HubColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.card(context),
        borderRadius: HubRadius.rSm,
        border: Border.all(color: AppTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status & Uji Notifikasi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          diagAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(minHeight: 3),
            ),
            error: (_, _) => Text(
              'Status izin tidak tersedia di platform ini.',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
            data: (diag) => Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(
                    diag.notificationsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                    size: 15,
                    color: diag.notificationsEnabled
                        ? colors.success
                        : colors.warning,
                  ),
                  label: Text(
                    diag.isSupportedPlatform
                        ? (diag.notificationsEnabled
                            ? 'Izin Aktif'
                            : 'Izin Belum Aktif')
                        : 'Platform Web/Desktop',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
                if (diag.isSupportedPlatform)
                  Chip(
                    avatar: Icon(
                      diag.exactAlarmsAllowed
                          ? Icons.alarm_on_rounded
                          : Icons.alarm_outlined,
                      size: 15,
                      color: diag.exactAlarmsAllowed
                          ? colors.primary
                          : colors.warning,
                    ),
                    label: Text(
                      diag.exactAlarmsAllowed
                          ? 'Alarm Tepat Waktu'
                          : 'Mode Inexact',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                Chip(
                  avatar: const Icon(Icons.public_rounded, size: 14),
                  label: Text(
                    'Zona: ${diag.timeZoneName}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.event_available_rounded, size: 14),
                  label: Text(
                    '${diag.pendingPrayerCount} Adzan • ${diag.pendingMeetingCount} Meeting • ${diag.pendingTaskCount} Tugas',
                    style: HubTypography.tabular(
                      const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final center = ref.read(appNotificationCenterProvider);
                  final granted = await center.requestAllPermissions();
                  final summary = await ref
                      .read(notificationBootstrapProvider)
                      .syncAll(requestPermissions: true, force: true);
                  ref.invalidate(notificationDiagnosticProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? 'Izin aktif & ${summary.totalCount} pengingat dijadwalkan.'
                              : 'Silakan aktifkan izin notifikasi di pengaturan perangkat.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.security_rounded, size: 15),
                label: const Text('Aktifkan Izin'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final sent = await ref
                      .read(appNotificationCenterProvider)
                      .showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          sent
                              ? 'Notifikasi uji coba dikirim ke perangkat.'
                              : 'Notifikasi uji coba hanya tersedia di Android/iOS/macOS.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 15),
                label: const Text('Tes Notifikasi'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final summary = await ref
                      .read(notificationBootstrapProvider)
                      .syncAll(requestPermissions: true, force: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${summary.prayerCount} Adzan, ${summary.meetingCount} Meeting, ${summary.taskCount} Tugas dijadwalkan ulang.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Jadwalkan Ulang'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
