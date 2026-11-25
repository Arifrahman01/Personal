import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/agenda/ui/agenda_hub_screen.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';
import 'package:personal_hub/features/finance/ui/finance_screen.dart';
import 'package:personal_hub/features/finance/ui/widgets/zakat_tab.dart';
import 'package:personal_hub/features/home/ui/home_screen.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/meetings/services/meeting_ai_parser.dart';
import 'package:personal_hub/features/meetings/services/meeting_note_composer_service.dart';
import 'package:personal_hub/features/meetings/services/meeting_voice_recorder.dart';
import 'package:personal_hub/features/meetings/ui/live_meeting_recorder_screen.dart';
import 'package:personal_hub/features/meetings/ui/meeting_note_result_sheet.dart';
import 'package:personal_hub/features/notes/models/note.dart';
import 'package:personal_hub/features/notes/ui/note_editor_screen.dart';
import 'package:personal_hub/features/notes/ui/notes_screen.dart';
import 'package:personal_hub/features/notes/ui/widgets/unified_ai_sheet.dart';
import 'package:personal_hub/features/settings/ui/pages/backup_sync_settings_page.dart';
import 'package:personal_hub/features/settings/ui/settings_screen.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
import 'package:personal_hub/features/vault/services/vault_crypto_service.dart';
import 'package:personal_hub/features/vault/ui/vault_list_screen.dart';
import 'package:personal_hub/features/vault/ui/vault_tab_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemorySecureStorage implements KeyValueSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _FakeBiometricAdapter implements BiometricAuthAdapter {
  _FakeBiometricAdapter({this.available = false, this.succeed = false});

  final bool available;
  final bool succeed;

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<bool> authenticate(String reason) async => succeed;
}

class _FakeClipboardAdapter implements ClipboardAdapter {
  @override
  Future<String?> getText() async => '';

  @override
  Future<void> setText(String text) async {}
}

class _FakeSpeechRecognizerGateway implements SpeechRecognizerGateway {
  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(double level)? onSoundLevelChange,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}
}

class _AuditScreenCase {
  const _AuditScreenCase({
    required this.name,
    required this.builder,
    this.viewInsets = EdgeInsets.zero,
    this.setupPin = false,
    this.unlockVault = false,
  });

  final String name;
  final Widget Function() builder;
  final EdgeInsets viewInsets;
  final bool setupPin;
  final bool unlockVault;
}

ComposedMeetingResult _sampleMeetingResult() {
  final now = DateTime.utc(2026, 11, 24, 9, 0);
  final meeting = Meeting(
    id: 'm-audit-1',
    title: 'Sinkronisasi Mingguan Produk',
    scheduledAt: now,
    actionItems: const [
      MeetingActionItem(
        id: 'ai-1',
        text: 'Finalisasi desain layar brankas',
        isDone: false,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
  final note = Note(
    id: 'n-audit-1',
    title: 'Notulensi Sinkronisasi Mingguan Produk',
    content: 'Ringkasan rapat dan poin tindak lanjut.',
    tags: const ['meeting', 'notulensi'],
    isPinned: false,
    createdAt: now,
    updatedAt: now,
  );
  const structured = StructuredMeetingNote(
    title: 'Notulensi Sinkronisasi Mingguan Produk',
    summary: 'Membahas target rilis v3.0 dan audit aksesibilitas.',
    keyPoints: ['Perbaikan overflow 320px', 'Peningkatan target sentuh 48dp'],
    decisions: ['Seluruh komponen harus lulus skala teks 1.3x'],
    actionItems: ['Finalisasi desain layar brankas'],
  );
  return ComposedMeetingResult(
    meeting: meeting,
    savedNote: note,
    structuredNote: structured,
    aiSucceeded: true,
    usedModel: 'deepseek-free',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
  });

  final screens = <_AuditScreenCase>[
    _AuditScreenCase(
      name: 'MainNavigationShell',
      builder: () => const MainNavigationShell(),
    ),
    _AuditScreenCase(
      name: 'HomeScreen',
      builder: () => const HomeScreen(),
    ),
    _AuditScreenCase(
      name: 'AgendaHubScreen (Meeting)',
      builder: () => const AgendaHubScreen(initialSection: 0),
    ),
    _AuditScreenCase(
      name: 'AgendaHubScreen (Tugas & Habit)',
      builder: () => const AgendaHubScreen(initialSection: 1),
    ),
    _AuditScreenCase(
      name: 'AgendaHubScreen (Sholat & Kiblat)',
      builder: () => const AgendaHubScreen(initialSection: 2),
    ),
    _AuditScreenCase(
      name: 'NotesScreen',
      builder: () => const NotesScreen(),
    ),
    _AuditScreenCase(
      name: 'NoteEditorScreen',
      builder: () => const NoteEditorScreen(),
    ),
    _AuditScreenCase(
      name: 'UnifiedAiAssistantSheet (IME 240px)',
      viewInsets: const EdgeInsets.only(bottom: 240),
      builder: () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: UnifiedAiAssistantSheet(
            noteTitle: 'Catatan Rapat',
            noteContent: 'Poin penting rapat minggu ini dan target rilis.',
            onReplace: (_) {},
            onAppend: (_) {},
            onInsertTask: (_) {},
          ),
        ),
      ),
    ),
    _AuditScreenCase(
      name: 'FinanceScreen',
      builder: () => const FinanceScreen(),
    ),
    _AuditScreenCase(
      name: 'ZakatTab',
      builder: () => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ZakatTab(onDeclareAssets: () {}),
        ),
      ),
    ),
    _AuditScreenCase(
      name: 'VaultTabView (Setup PIN)',
      builder: () => const VaultTabView(),
    ),
    _AuditScreenCase(
      name: 'VaultTabView (Keypad Gate)',
      setupPin: true,
      builder: () => const VaultTabView(),
    ),
    _AuditScreenCase(
      name: 'VaultListScreen',
      unlockVault: true,
      builder: () => const VaultListScreen(),
    ),
    _AuditScreenCase(
      name: 'LiveMeetingRecorderScreen',
      builder: () => const LiveMeetingRecorderScreen(),
    ),
    _AuditScreenCase(
      name: 'AiChatScreen',
      builder: () => const AiChatScreen(),
    ),
    _AuditScreenCase(
      name: 'SettingsScreen',
      builder: () => const SettingsScreen(),
    ),
    _AuditScreenCase(
      name: 'BackupSyncSettingsPage',
      builder: () => const BackupSyncSettingsPage(),
    ),
    _AuditScreenCase(
      name: 'MeetingNoteResultSheet',
      builder: () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MeetingNoteResultSheet(result: _sampleMeetingResult()),
        ),
      ),
    ),
  ];

  final viewports = <(String label, Size size)>[
    ('320x600', const Size(320, 600)),
    ('768x1024', const Size(768, 1024)),
  ];

  final themes = <(String label, ThemeData Function() buildTheme)>[
    ('Light', () => AppTheme.light),
    ('Dark', () => AppTheme.dark),
  ];

  for (final screen in screens) {
    for (final viewport in viewports) {
      for (final themeEntry in themes) {
        testWidgets(
          '${screen.name} renders without overflow or FlutterError at ${viewport.$1} (${themeEntry.$1}, textScaler 1.3)',
          (tester) async {
            tester.view.physicalSize = Size(
              viewport.$2.width * 2,
              viewport.$2.height * 2,
            );
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final appDb = await AppDatabase.open(
              pathOverride: inMemoryDatabasePath,
              factoryOverride: databaseFactoryFfiNoIsolate,
            );
            addTearDown(() async => appDb.close());

            final configStore = SecureConfigStore(_InMemorySecureStorage());
            final biometricAdapter = _FakeBiometricAdapter(
              available: screen.unlockVault || screen.setupPin,
              succeed: screen.unlockVault,
            );
            final vaultLockController = VaultLockController(
              configStore,
              VaultCryptoService(),
              biometricAdapter,
            );
            addTearDown(vaultLockController.dispose);

            if (screen.setupPin) {
              await configStore.setVaultPinHash('audit_salt:audit_hash');
            }
            if (screen.unlockVault) {
              await vaultLockController.unlockWithBiometrics();
            }

            final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
            addTearDown(clipboardGuard.dispose);

            final capturedErrors = <FlutterErrorDetails>[];
            final oldOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              capturedErrors.add(details);
              oldOnError?.call(details);
            };
            addTearDown(() {
              FlutterError.onError = oldOnError;
            });

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(appDb),
                  secureConfigStoreProvider.overrideWithValue(configStore),
                  biometricAuthAdapterProvider.overrideWithValue(
                    biometricAdapter,
                  ),
                  vaultLockControllerProvider.overrideWithValue(
                    vaultLockController,
                  ),
                  clipboardGuardProvider.overrideWithValue(clipboardGuard),
                  speechRecognizerGatewayProvider.overrideWithValue(
                    _FakeSpeechRecognizerGateway(),
                  ),
                  backgroundRecordingGatewayProvider.overrideWithValue(
                    NoOpBackgroundRecordingGateway(),
                  ),
                  recordingWakelockGatewayProvider.overrideWithValue(
                    NoOpRecordingWakelockGateway(),
                  ),
                  meetingDraftStoreProvider.overrideWithValue(
                    InMemoryMeetingDraftStore(),
                  ),
                ],
                child: MaterialApp(
                  theme: themeEntry.$2(),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: const TextScaler.linear(1.3),
                        viewInsets: screen.viewInsets,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                  home: screen.builder(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              capturedErrors,
              isEmpty,
              reason:
                  'Expected zero FlutterErrors/overflows on ${screen.name} at ${viewport.$1} (${themeEntry.$1})',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
