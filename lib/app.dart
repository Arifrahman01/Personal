import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/home/ui/global_search_sheet.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/vault_gate_screen.dart';

/// Root Material 3 application widget for Personal Hub v3.0 ("Calm Clarity").
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

/// Adaptive 5-tab navigation shell with docked NavigationBar (< 600dp) and
/// NavigationRail (>= 600dp), plus Vault background auto-lock & Calm Clarity privacy shield.
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  /// Opens global search modal sheet.
  static void openSearch(BuildContext context) {
    GlobalSearchSheet.show(context);
  }

  /// Opens Samudra AI Copilot full-screen view.
  static void openAiChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiChatScreen()),
    );
  }

  /// Opens application settings.
  static void openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isObscured = false;

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
    final colors = HubColors.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;

    final screens = [
      HomeScreen(
        onSwitchTab: _selectTab,
        onPromoteActionItem: _promoteActionItem,
      ),
      AgendaHubScreen(
        onPromoteActionItem: _promoteActionItem,
      ),
      const NotesScreen(),
      const FinanceScreen(),
      const VaultTabView(),
    ];

    final bottomNavDestinations = const [
      NavigationDestination(
        icon: Icon(Icons.wb_sunny_outlined),
        selectedIcon: Icon(Icons.wb_sunny_rounded),
        label: 'Hari Ini',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Agenda',
      ),
      NavigationDestination(
        icon: Icon(Icons.edit_note_outlined),
        selectedIcon: Icon(Icons.edit_note_rounded),
        label: 'Catatan',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Keuangan',
      ),
      NavigationDestination(
        icon: Icon(Icons.verified_user_outlined),
        selectedIcon: Icon(Icons.verified_user_rounded),
        label: 'Vault',
      ),
    ];

    final railDestinations = const [
      NavigationRailDestination(
        icon: Icon(Icons.wb_sunny_outlined),
        selectedIcon: Icon(Icons.wb_sunny_rounded),
        label: Text('Hari Ini'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: Text('Agenda'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.edit_note_outlined),
        selectedIcon: Icon(Icons.edit_note_rounded),
        label: Text('Catatan'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: Text('Keuangan'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.verified_user_outlined),
        selectedIcon: Icon(Icons.verified_user_rounded),
        label: Text('Vault'),
      ),
    ];

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: _FadeThroughIndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
    );

    Widget shell;
    if (isWide) {
      shell = Scaffold(
        backgroundColor: colors.canvas,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: content),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        backgroundColor: colors.canvas,
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: bottomNavDestinations,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        shell,
        if (_isObscured) const _PrivacyShieldOverlay(),
      ],
    );
  }
}

/// Preserves offstage tab state via [IndexedStack] while adding a crisp
/// Material 3 fade-through transition when switching tabs.
class _FadeThroughIndexedStack extends StatefulWidget {
  const _FadeThroughIndexedStack({
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<_FadeThroughIndexedStack> createState() =>
      _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<_FadeThroughIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0.85, end: 1.0).animate(curved);
    _scale = Tween<double>(begin: 0.985, end: 1.0).animate(curved);
  }

  @override
  void didUpdateWidget(covariant _FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(
      index: widget.index,
      children: widget.children,
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      return stack;
    }

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: stack,
      ),
    );
  }
}

/// Full-screen tactile frosted glass overlay that obscures sensitive screen content during OS multitasking.
/// Styled according to Calm Clarity design tokens (HubColors).
class _PrivacyShieldOverlay extends StatelessWidget {
  const _PrivacyShieldOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final canvasColor = colors.canvas;
    final primaryColor = colors.primary;

    return Positioned.fill(
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: canvasColor.withValues(alpha: 0.90),
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
                      color: primaryColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      size: 38,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Personal Hub - Layar Terlindungi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data sensitif disembunyikan saat aplikasi tidak aktif',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
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
