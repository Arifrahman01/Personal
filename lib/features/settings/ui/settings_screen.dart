import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
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

    return Scaffold(
      backgroundColor: AppTokens.canvas(context),
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: AppTokens.canvas(context),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Tampilan (Tema) Segmented Button
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Text(
                      'Tampilan Antarmuka',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
          Center(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 20, color: primary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Personal Hub v3.0 ("Calm Clarity")',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terenkripsi Lokal • Siap Tanpa Internet',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
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
          CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            foregroundColor: iconColor,
            child: Icon(icon, size: 20),
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
