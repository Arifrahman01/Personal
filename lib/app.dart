import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/home/ui/global_search_sheet.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/providers/meetings_providers.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_detail_screen.dart';
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
  StreamSubscription<String>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final reminderService = ref.read(meetingReminderServiceProvider);
    _notificationTapSubscription = reminderService.onNotificationTap.listen(
      _openMeetingDetailFromNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialNotificationLaunch();
    });
  }

  Future<void> _checkInitialNotificationLaunch() async {
    final meetingId = await ref
        .read(meetingReminderServiceProvider)
        .getInitialNotificationMeetingId();
    if (meetingId != null && mounted) {
      _openMeetingDetailFromNotification(meetingId);
    }
  }

  void _openMeetingDetailFromNotification(String meetingId) {
    final id = meetingId.trim();
    if (id.isEmpty || !mounted) return;
    _selectTab(1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meetingId: id,
          onPromoteActionItem: _promoteActionItem,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
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
        icon: Icon(LucideIcons.sun),
        selectedIcon: Icon(LucideIcons.sun),
        label: 'Hari Ini',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.calendar),
        selectedIcon: Icon(LucideIcons.calendar),
        label: 'Agenda',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.notebookPen),
        selectedIcon: Icon(LucideIcons.notebookPen),
        label: 'Catatan',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.walletCards),
        selectedIcon: Icon(LucideIcons.walletCards),
        label: 'Keuangan',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.shieldCheck),
        selectedIcon: Icon(LucideIcons.shieldCheck),
        label: 'Vault',
      ),
    ];

    final railDestinations = const [
      NavigationRailDestination(
        icon: Icon(LucideIcons.sun),
        selectedIcon: Icon(LucideIcons.sun),
        label: Text('Hari Ini'),
      ),
      NavigationRailDestination(
        icon: Icon(LucideIcons.calendar),
        selectedIcon: Icon(LucideIcons.calendar),
        label: Text('Agenda'),
      ),
      NavigationRailDestination(
        icon: Icon(LucideIcons.notebookPen),
        selectedIcon: Icon(LucideIcons.notebookPen),
        label: Text('Catatan'),
      ),
      NavigationRailDestination(
        icon: Icon(LucideIcons.walletCards),
        selectedIcon: Icon(LucideIcons.walletCards),
        label: Text('Keuangan'),
      ),
      NavigationRailDestination(
        icon: Icon(LucideIcons.shieldCheck),
        selectedIcon: Icon(LucideIcons.shieldCheck),
        label: Text('Vault'),
      ),
    ];

    final recorder = ref.watch(meetingVoiceRecorderProvider);

    final mainBody = Column(
      children: [
        ListenableBuilder(
          listenable: recorder,
          builder: (context, _) {
            if (!recorder.state.isActiveSession &&
                !recorder.state.isTranscribing) {
              return const SizedBox.shrink();
            }
            return _ActiveRecordingMiniBar(
              recorder: recorder,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveMeetingRecorderScreen(
                      onPromoteActionItem: _promoteActionItem,
                    ),
                  ),
                );
              },
            );
          },
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: IndexedStack(
                index: _selectedIndex,
                children: screens,
              ),
            ),
          ),
        ),
      ],
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
            Expanded(child: mainBody),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        backgroundColor: colors.canvas,
        body: mainBody,
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

/// Full-screen tactile frosted glass overlay that obscures sensitive screen content during OS multitasking.
/// Styled according to Calm Clarity design tokens (HubColors).
class _PrivacyShieldOverlay extends StatelessWidget {
  const _PrivacyShieldOverlay();

  @override
  Widget build(BuildContext context) {
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
                      LucideIcons.shieldCheck,
                      size: 38,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Personal Hub - Layar Terlindungi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data sensitif disembunyikan saat aplikasi tidak aktif',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
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

class _ActiveRecordingMiniBar extends StatelessWidget {
  const _ActiveRecordingMiniBar({
    required this.recorder,
    required this.onTap,
  });

  final MeetingVoiceRecorder recorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sessionState = recorder.state;
    final isRecording = sessionState.isRecording;
    final isTranscribing = sessionState.isTranscribing;
    final accent = isTranscribing
        ? AppTokens.info(context)
        : (isRecording ? AppTokens.danger(context) : AppTokens.warning(context));
    final fg = AppTokens.tonalForeground(context, accent);
    final statusLabel = isTranscribing
        ? 'Transkrip Offline (${(sessionState.transcriptionProgress * 100).round()}%)'
        : isRecording
        ? (sessionState.mode == MeetingRecordingMode.silentAudioOffline
              ? 'Audio Senyap'
              : 'Merekam Meeting')
        : 'Rekaman Dijeda';

    return Material(
      color: accent.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          key: const Key('active_recording_mini_bar'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: accent.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: recorder.elapsedListenable,
                    builder: (context, elapsed, _) {
                      final formatted =
                          MeetingVoiceSessionState.formatDurationHhMmSs(elapsed);
                      final detail =
                          sessionState.mode ==
                              MeetingRecordingMode.silentAudioOffline
                          ? '$statusLabel • $formatted'
                          : '$statusLabel • $formatted • ${sessionState.wordCount} kata';
                      return Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HubTypography.tabular(
                          TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.textPrimary(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: HubRadius.rPill,
                  ),
                  child: Text(
                    'Buka',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
