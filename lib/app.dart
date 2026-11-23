import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/ui/meetings_screen.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/vault_gate_screen.dart';

/// Root Material 3 application widget for Personal Hub.
class PersonalHubApp extends ConsumerWidget {
  const PersonalHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Personal Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const MainNavigationShell(),
    );
  }
}

/// Primary 5-tab Glassmorphism navigation shell with Vault background auto-lock.
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isObscured = false;

  static const List<GlassNavDestination> _destinations = [
    GlassNavDestination(
      label: 'Beranda',
      icon: LucideIcons.house,
      selectedIcon: LucideIcons.house,
    ),
    GlassNavDestination(
      label: 'Catatan',
      icon: LucideIcons.notebookPen,
      selectedIcon: LucideIcons.notebookPen,
    ),
    GlassNavDestination(
      label: 'Meeting',
      icon: LucideIcons.calendarClock,
      selectedIcon: LucideIcons.calendarClock,
    ),
    GlassNavDestination(
      label: 'Vault',
      icon: LucideIcons.shieldCheck,
      selectedIcon: LucideIcons.shieldCheck,
    ),
    GlassNavDestination(
      label: 'AI',
      icon: LucideIcons.sparkles,
      selectedIcon: LucideIcons.sparkles,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(vaultLockControllerProvider).handleAppLifecycle(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!_isObscured) {
          setState(() {
            _isObscured = true;
          });
        }
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        if (_isObscured) {
          setState(() {
            _isObscured = false;
          });
        }
        break;
    }
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _promoteActionItem(
    Meeting meeting,
    MeetingActionItem item,
  ) async {
    await ref
        .read(tasksProvider.notifier)
        .createTask(title: item.text, sourceMeetingId: meeting.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Action item "${item.text}" ditambahkan ke Tugas.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassScaffold(
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              HomeScreen(
                onSwitchTab: _selectTab,
                onPromoteActionItem: _promoteActionItem,
              ),
              const NotesScreen(),
              MeetingsScreen(onPromoteActionItem: _promoteActionItem),
              const VaultTabView(),
              const AiChatScreen(),
            ],
          ),
          bottomNavigationBar: GlassBottomNavBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: _destinations,
          ),
        ),
        if (_isObscured)
          const _PrivacyShieldOverlay(),
      ],
    );
  }
}

/// Full-screen frosted glass overlay that obscures sensitive screen content during OS multitasking.
class _PrivacyShieldOverlay extends StatelessWidget {
  const _PrivacyShieldOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: (isDark ? const Color(0xFF061114) : const Color(0xFFEAF6F4))
                  .withValues(alpha: 0.88),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E))
                          .withValues(alpha: 0.15),
                      border: Border.all(
                        color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF14B8A6))
                            .withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 38,
                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Personal Hub - Layar Terlindungi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data sensitif disembunyikan saat aplikasi tidak aktif',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
