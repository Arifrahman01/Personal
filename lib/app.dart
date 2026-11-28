import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/notifications/notification_bootstrap_service.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/providers/finance_providers.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/finance/ui/widgets/add_transaction_sheet.dart';
import 'package:personal_hub/features/home/providers/app_shortcuts_providers.dart';
import 'package:personal_hub/features/home/services/app_shortcuts_service.dart';
import 'package:personal_hub/features/home/ui/global_search_sheet.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
import 'package:personal_hub/features/home/ui/quick_capture_sheet.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/tasks/providers/tasks_providers.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/ui/vault_gate_screen.dart';

/// Root Material 3 application widget for Personal Hub v4.0 ("Sanctuary Luxe").
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

/// Adaptive 5-tab navigation shell with floating capsule dock (< 600dp) and
/// sculpted workspace sidebar NavigationRail (>= 600dp), plus Vault auto-lock & privacy shield.
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
  static const MethodChannel _shortcutChannel = MethodChannel(
    'personal_hub/app_shortcuts',
  );

  int _selectedIndex = 0;
  bool _isObscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shortcutChannel.setMethodCallHandler(_handleShortcutMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          ref
              .read(notificationBootstrapProvider)
              .syncAll(requestPermissions: true),
        );
      } catch (_) {
        // Ignore if widget tree was torn down immediately in widget tests.
      }
      unawaited(_checkInitialShortcut());
    });
  }

  Future<dynamic> _handleShortcutMethodCall(MethodCall call) async {
    if (call.method == 'onShortcutTriggered' && call.arguments is String) {
      if (mounted) {
        _applyShortcutIntent(call.arguments as String);
      }
    }
    return null;
  }

  Future<void> _checkInitialShortcut() async {
    try {
      final rawId = await _shortcutChannel.invokeMethod<String>(
        'getInitialShortcut',
      );
      if (rawId != null && rawId.trim().isNotEmpty && mounted) {
        _applyShortcutIntent(rawId);
      }
    } on MissingPluginException {
      // Unsupported on iOS/desktop/tests without Android host channel.
    } on PlatformException {
      // Ignore transient platform channel failures on startup.
    }
  }

  void _applyShortcutIntent(String rawShortcutId) {
    final result = ref
        .read(activeShortcutIntentProvider.notifier)
        .processShortcutIntent(rawShortcutId);
    _selectTab(result.tabIndex.clamp(0, 4));

    switch (result.shortcutId) {
      case AppShortcutIds.prayerSchedule:
        final section = (result.payload['agendaSection'] as num?)?.toInt() ?? 2;
        ref.read(agendaSelectedSectionProvider.notifier).setSection(section);
        break;
      case AppShortcutIds.quickCapture:
        QuickCaptureSheet.show(context);
        break;
      case AppShortcutIds.newNote:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NoteEditorScreen()),
        );
        break;
      case AppShortcutIds.newTransaction:
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => AddTransactionSheet(
            selectedMonth: ref.read(selectedFinanceMonthProvider),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _shortcutChannel.setMethodCallHandler(null);
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
        if (_isObscured) {
          setState(() {
            _isObscured = false;
          });
        }
        try {
          unawaited(
            ref
                .read(notificationBootstrapProvider)
                .syncAll(requestPermissions: false),
          );
        } catch (_) {}
        break;
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

  void _toggleThemeMode() {
    final current = ref.read(themeModeProvider);
    final isDark = current == ThemeMode.dark ||
        (current == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    ref
        .read(themeModeProvider.notifier)
        .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HubColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;
    final isExtended = screenWidth >= 920;

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

    const bottomNavDestinations = [
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

    const railDestinations = [
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
        constraints: const BoxConstraints(maxWidth: 1080),
        child: _FadeThroughIndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
    );

    Widget shell;
    if (isWide) {
      shell = Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceCard.withValues(alpha: isDark ? 0.94 : 0.96),
                border: Border(
                  right: BorderSide(color: colors.borderHairline, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
                    blurRadius: 18,
                    offset: const Offset(4, 0),
                  ),
                ],
              ),
              child: SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  extended: isExtended,
                  minWidth: 84,
                  minExtendedWidth: 236,
                  labelType: isExtended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isExtended ? 16 : 8,
                      10,
                      isExtended ? 16 : 8,
                      14,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isExtended
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LuxeBrandEmblem(size: 38),
                            if (isExtended) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primarySoft,
                                  borderRadius: HubRadius.rPill,
                                  border: Border.all(
                                    color: colors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  'Sanctuary',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isExtended)
                          SizedBox(
                            width: 204,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  MainNavigationShell.openSearch(context),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                backgroundColor: colors.surfaceSubtle
                                    .withValues(alpha: 0.55),
                                side: BorderSide(color: colors.borderHairline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: HubRadius.rPill,
                                ),
                              ),
                              icon: Icon(
                                Icons.search_rounded,
                                size: 17,
                                color: colors.textSecondary,
                              ),
                              label: Text(
                                'Pencarian cepat...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          LuxeHeaderIconButton(
                            tooltip: 'Pencarian Global',
                            icon: Icons.search_rounded,
                            onPressed: () =>
                                MainNavigationShell.openSearch(context),
                          ),
                      ],
                    ),
                  ),
                  trailing: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isExtended ? 16 : 8,
                      12,
                      isExtended ? 16 : 8,
                      12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isExtended)
                          SizedBox(
                            width: 204,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.accentAi, colors.primary],
                                ),
                                borderRadius: HubRadius.rSm,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        colors.accentAi.withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  borderRadius: HubRadius.rSm,
                                  onTap: () =>
                                      MainNavigationShell.openAiChat(context),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Samudra AI',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          LuxeHeaderIconButton(
                            tooltip: 'Buka Samudra AI',
                            icon: Icons.auto_awesome_rounded,
                            accentColor: colors.accentAi,
                            onPressed: () =>
                                MainNavigationShell.openAiChat(context),
                          ),
                        const SizedBox(height: 8),
                        LuxeHeaderIconButton(
                          tooltip: 'Ganti Tema',
                          icon: isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          accentColor: colors.accentGold,
                          onPressed: _toggleThemeMode,
                        ),
                      ],
                    ),
                  ),
                  destinations: railDestinations,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: content,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceElevated.withValues(
                  alpha: isDark ? 0.94 : 0.97,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.borderHairline,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  height: 66,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  destinations: bottomNavDestinations,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LuxeAmbientBackground(child: shell),
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
/// Styled according to Sanctuary Luxe design tokens (HubColors).
class _PrivacyShieldOverlay extends StatelessWidget {
  const _PrivacyShieldOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HubColors.of(context);
    final canvasColor = colors.canvas;
    final primaryColor = colors.primary;
    final goldColor = colors.accentGold;

    return Positioned.fill(
      child: AbsorbPointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: canvasColor.withValues(alpha: 0.92),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: goldColor.withValues(alpha: 0.08),
                      border: Border.all(
                        color: goldColor.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withValues(alpha: 0.24),
                            goldColor.withValues(alpha: 0.14),
                          ],
                        ),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.50),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 38,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Personal Hub - Layar Terlindungi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data sensitif disembunyikan saat aplikasi tidak aktif',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
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
