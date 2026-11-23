import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    final themeMode = ref.watch(themeModeProvider);
    final primary = AppTokens.primary(context);

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
                    Icon(LucideIcons.palette, size: 20, color: primary),
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
                        icon: Icon(LucideIcons.sunMoon, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Terang'),
                        icon: Icon(LucideIcons.sun, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Gelap'),
                        icon: Icon(LucideIcons.moon, size: 16),
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
          const SizedBox(height: 16),

          // Menu Sections Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'PREFERENSI & MODUL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTokens.textSecondary(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 2. Tampilkan di Beranda
          _SettingsMenuTile(
            icon: LucideIcons.layoutGrid,
            iconColor: const Color(0xFFF59E0B),
            title: 'Tampilkan di Beranda',
            subtitle: 'Atur kartu modul yang aktif di halaman Beranda Hari Ini.',
            onTap: () => _openHomeModulesSheet(context),
          ),
          const SizedBox(height: 10),

          // 3. Asisten AI
          _SettingsMenuTile(
            icon: LucideIcons.bot,
            iconColor: primary,
            title: 'Asisten AI',
            subtitle: 'Model deepseek-v4.1-flash:free, API Key & uji koneksi.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // 4. Keamanan & Brankas
          _SettingsMenuTile(
            icon: LucideIcons.shieldCheck,
            iconColor: AppTokens.success(context),
            title: 'Keamanan & Brankas',
            subtitle: 'PIN Utama, Duress PIN (anti-pemaksaan), dan Kunci Otomatis.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecurityVaultSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // 5. Jadwal Sholat & Adzan
          _SettingsMenuTile(
            icon: LucideIcons.bell,
            iconColor: AppTokens.info(context),
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
          const SizedBox(height: 10),

          // 6. Backup & Sinkronisasi
          _SettingsMenuTile(
            icon: LucideIcons.hardDrive,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Backup & Sinkronisasi',
            subtitle: 'Ekspor .phub, Simpan Otomatis: 7 Harian • 4 Mingguan • 3 Bulanan, & Cloud Sync.',
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
                  child: Icon(LucideIcons.sparkles, size: 20, color: primary),
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
                  'Enkripsi AES-256-GCM Lokal • Offline-First',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.textSecondary(context),
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
      backgroundColor: AppTokens.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HubRadius.lg)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final prefs = ref.watch(homeModulePreferencesProvider);
            final notifier = ref.read(homeModulePreferencesProvider.notifier);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTokens.border(context),
                        borderRadius: HubRadius.rPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    subtitle: const Text('Executive summary harian'),
                    value: prefs.showAiBriefing,
                    onChanged: notifier.toggleAiBriefing,
                  ),
                ],
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
            LucideIcons.chevronRight,
            size: 18,
            color: AppTokens.textSecondary(context),
          ),
        ],
      ),
    );
  }
}
