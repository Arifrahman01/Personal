import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/notifications/app_notification_center.dart';
import 'package:personal_hub/core/notifications/notification_bootstrap_service.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/home/providers/home_module_preferences.dart';
import 'package:personal_hub/features/prayer/ui/prayer_schedule_screen.dart';
import 'package:personal_hub/features/settings/ui/pages/ai_settings_page.dart';
import 'package:personal_hub/features/settings/ui/pages/backup_sync_settings_page.dart';
import 'package:personal_hub/features/settings/ui/pages/security_vault_settings_page.dart';

/// Modular Settings screen for Personal Hub v3.0 ("Calm Clarity").
/// Clean group menu navigating to specialized sub-pages.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = HubColors.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final primary = colors.primary;

    return LuxeAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Pengaturan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          actions: [
            LuxeHeaderIconButton(
              tooltip: 'Uji Notifikasi',
              icon: Icons.notifications_active_outlined,
              accentColor: primary,
              onPressed: () async {
                final summary = await ref
                    .read(notificationBootstrapProvider)
                    .syncAll(requestPermissions: true, force: true);
                final sent = await ref
                    .read(appNotificationCenterProvider)
                    .showTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent
                            ? 'Tes notifikasi dikirim! ${summary.totalCount} jadwal aktif disinkronkan.'
                            : 'Pengingat disinkronkan (${summary.totalCount} jadwal). Uji banner tersedia di Android/iOS/macOS.',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Signature Sanctuary Luxe Identity Banner
            LuxeHeroCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const LuxeBrandEmblem(size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Hub v4.0 ("Sanctuary Luxe")',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Terenkripsi Lokal • Siap Tanpa Internet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HubSpacing.lg),

            // 1. Tampilan (Tema) Segmented Button
            HubCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LuxeIconMedallion(
                        icon: Icons.palette_outlined,
                        color: primary,
                        size: 34,
                        iconSize: 18,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tampilan Antarmuka',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HubSpacing.lg),

          // Menu Sections Header
          const HubSectionHeader(
            title: 'PREFERENSI & MODUL',
            padding: EdgeInsets.symmetric(
              horizontal: HubSpacing.xs,
              vertical: HubSpacing.xs,
            ),
          ),
          const SizedBox(height: HubSpacing.xs),

          // 2. Tampilkan di Beranda
          _SettingsMenuTile(
            icon: Icons.grid_view_rounded,
            iconColor: colors.warning,
            title: 'Tampilkan di Beranda',
            subtitle: 'Atur kartu modul yang aktif di halaman Beranda Hari Ini.',
            onTap: () => _openHomeModulesSheet(context),
          ),
          const SizedBox(height: HubSpacing.md),

          // 3. Asisten AI
          _SettingsMenuTile(
            icon: Icons.smart_toy_outlined,
            iconColor: primary,
            title: 'Asisten AI',
            subtitle:
                'Model prioritas ${AiConstants.freeModel}, kunci akses & uji koneksi.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: HubSpacing.md),

          // 4. Keamanan & Brankas
          _SettingsMenuTile(
            icon: Icons.verified_user_outlined,
            iconColor: colors.success,
            title: 'Keamanan & Brankas',
            subtitle: 'PIN Utama, PIN Darurat, dan Kunci Otomatis.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecurityVaultSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: HubSpacing.md),

          // 5. Jadwal Sholat & Adzan
          _SettingsMenuTile(
            icon: Icons.notifications_outlined,
            iconColor: colors.info,
            title: 'Jadwal Sholat & Adzan',
            subtitle: '5 waktu sholat harian, notifikasi pengingat, hisab & kiblat.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrayerScheduleScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: HubSpacing.md),

          // 6. Backup & Sinkronisasi
          _SettingsMenuTile(
            icon: Icons.storage_rounded,
            iconColor: colorScheme.tertiary,
            title: 'Backup & Sinkronisasi',
            subtitle:
                'Cadangkan data (.phub), Simpan Otomatis: 7 Harian • 4 Mingguan • 3 Bulanan, & Sinkronisasi Cloud.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BackupSyncSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // App Footer Info
          const SizedBox(height: 24),
        ],
        ),
      ),
    ),
    );
  }

  void _openHomeModulesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final prefs = ref.watch(homeModulePreferencesProvider);
            final notifier = ref.read(homeModulePreferencesProvider.notifier);

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  HubSpacing.xl,
                  HubSpacing.xs,
                  HubSpacing.xl,
                  HubSpacing.xxl,
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tampilkan di Beranda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih modul kartu yang ingin Anda tampilkan pada halaman Hari Ini.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Jadwal Sholat'),
                    subtitle: const Text('Waktu sholat berikutnya & countdown'),
                    value: prefs.showPrayer,
                    onChanged: notifier.togglePrayer,
                  ),
                  SwitchListTile(
                    title: const Text('Fokus Hari Ini'),
                    subtitle: const Text('Agenda rapat & tugas prioritas'),
                    value: prefs.showFocus,
                    onChanged: notifier.toggleFocus,
                  ),
                  SwitchListTile(
                    title: const Text('Saldo Bulan Ini'),
                    subtitle: const Text('Arus kas pemasukan & pengeluaran'),
                    value: prefs.showFinance,
                    onChanged: notifier.toggleFinance,
                  ),
                  SwitchListTile(
                    title: const Text('Habit Hari Ini'),
                    subtitle: const Text('Target kebiasaan harian & streak'),
                    value: prefs.showHabits,
                    onChanged: notifier.toggleHabits,
                  ),
                  SwitchListTile(
                    title: const Text('Ringkasan AI Harian'),
                    subtitle: const Text('Ringkasan aktivitas & agenda harian'),
                    value: prefs.showAiBriefing,
                    onChanged: notifier.toggleAiBriefing,
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          LuxeIconMedallion(
            icon: icon,
            color: iconColor,
            size: 40,
            iconSize: 20,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.textSecondary(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppTokens.textSecondary(context),
          ),
        ],
      ),
    );
  }
}
