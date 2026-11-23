import 'package:flutter/material.dart';
import 'package:personal_hub/core/theme/app_theme.dart';

/// Root Material 3 application widget for Personal Hub.
class PersonalHubApp extends StatelessWidget {
  const PersonalHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const MainNavigationShell(),
    );
  }
}

/// Primary 5-tab navigation shell in Bahasa Indonesia.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  static const List<_TabConfig> _tabs = [
    _TabConfig(
      label: 'Beranda',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      subtitle: 'Ringkasan harian, jadwal sholat, dan pencarian global',
    ),
    _TabConfig(
      label: 'Catatan',
      icon: Icons.note_alt_outlined,
      selectedIcon: Icons.note_alt_rounded,
      subtitle: 'Catatan pribadi, tugas, dan ide cepat',
    ),
    _TabConfig(
      label: 'Meeting',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      subtitle: 'Notulensi rapat dan tindak lanjut otomatis',
    ),
    _TabConfig(
      label: 'Vault',
      icon: Icons.lock_outline,
      selectedIcon: Icons.lock_rounded,
      subtitle: 'Brankas kata sandi terenkripsi lokal',
    ),
    _TabConfig(
      label: 'AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      subtitle: 'Asisten AI pribadi dengan kontrol konteks lokal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (final tab in _tabs) _TabPlaceholderPage(tab: tab),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _TabConfig {
  const _TabConfig({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String subtitle;
}

class _TabPlaceholderPage extends StatelessWidget {
  const _TabPlaceholderPage({required this.tab});

  final _TabConfig tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tab.label,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tab.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(tab.selectedIcon),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Modul ${tab.label} siap digunakan.',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
