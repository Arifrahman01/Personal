import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';
import 'package:personal_hub/core/constants/ai_constants.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/vault/providers/vault_lock_controller.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/clipboard_guard.dart';
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
  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

class _FakeClipboardAdapter implements ClipboardAdapter {
  String _text = '';

  @override
  Future<String?> getText() async => _text;

  @override
  Future<void> setText(String text) async {
    _text = text;
  }
}

class _FakeAiClient extends SamudraAiClient {
  _FakeAiClient()
    : super(http.Client(), SecureConfigStore(_InMemorySecureStorage()));

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    String? systemPrompt,
  }) async {
    return const AiResponse(
      content: 'Hari ini fokus selesaikan agenda penting dan jaga waktu sholat.',
      usedModel: AiConstants.freeModel,
      didFallback: false,
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
  });

  testWidgets(
    'PersonalHubApp renders Home dashboard, switches across 5 tabs, and opens Settings with AI priority info',
    (WidgetTester tester) async {
      final appDb = await AppDatabase.open(
        pathOverride: inMemoryDatabasePath,
        factoryOverride: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => appDb.close());

      final configStore = SecureConfigStore(_InMemorySecureStorage());
      final clipboardGuard = ClipboardGuard(_FakeClipboardAdapter());
      addTearDown(clipboardGuard.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(appDb),
            secureConfigStoreProvider.overrideWithValue(configStore),
            aiClientProvider.overrideWithValue(_FakeAiClient()),
            biometricAuthAdapterProvider.overrideWithValue(
              _FakeBiometricAdapter(),
            ),
            clipboardGuardProvider.overrideWithValue(clipboardGuard),
          ],
          child: const PersonalHubApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Home dashboard assertions
      expect(find.text('Personal Hub'), findsOneWidget);
      expect(find.text('Hari Ini'), findsWidgets);
      expect(find.text('Ringkasan Hari Ini (AI)'), findsOneWidget);
      expect(find.text('FOKUS HARI INI'), findsOneWidget);
      expect(find.text('Habit Hari Ini'), findsOneWidget);
      expect(find.textContaining('Saldo'), findsOneWidget);
      expect(find.text('Catat'), findsOneWidget);

      // Verify all 5 tabs in bottom nav
      for (final label in ['Hari Ini', 'Agenda', 'Catatan', 'Keuangan', 'Vault']) {
        expect(find.text(label), findsWidgets);
      }

      // Navigate across tabs
      await tester.tap(find.text('Agenda').last);
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsWidgets);

      await tester.tap(find.text('Catatan').last);
      await tester.pumpAndSettle();
      expect(find.text('Belum ada catatan'), findsOneWidget);

      await tester.tap(find.text('Keuangan').last);
      await tester.pumpAndSettle();
      expect(find.text('Keuangan'), findsWidgets);

      await tester.tap(find.text('Vault').last);
      await tester.pumpAndSettle();
      expect(find.text('Buat PIN Brankas'), findsOneWidget);

      // Return to Hari Ini and open Settings
      await tester.tap(find.text('Hari Ini').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.textContaining(AiConstants.freeModel), findsWidgets);
      expect(find.textContaining(AiConstants.fallbackModel), findsWidgets);

      // Back to Hari Ini
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Test AI Copilot 1-tap from AppBar
      await tester.tap(find.byTooltip('AI Copilot'));
      await tester.pumpAndSettle();
      expect(find.text('Asisten AI Samudra'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Test Global Search 1-tap from AppBar
      await tester.tap(find.byTooltip('Cari'));
      await tester.pumpAndSettle();
      expect(find.text('Cari catatan, meeting, tugas, transaksi...'), findsOneWidget);
    },
  );
}
