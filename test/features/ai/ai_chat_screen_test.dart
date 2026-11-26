import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';
import 'package:personal_hub/features/ai/ui/ai_chat_screen.dart';

class _FakeAiChatController extends AiChatController {
  String? lastSentMessage;
  String? activeContext;

  @override
  Future<AiChatState> build() async {
    return const AiChatState(messages: []);
  }

  @override
  Future<void> sendMessage(String text) async {
    lastSentMessage = text;
    final current = state.asData?.value ?? const AiChatState(messages: []);
    final userMsg = ChatThreadMessage(
      id: 'msg-1',
      role: 'user',
      content: text,
      didFallback: false,
      createdAt: DateTime.now(),
    );
    state = AsyncData(current.copyWith(messages: [...current.messages, userMsg]));
  }

  @override
  void setSystemContext(String? context) {
    activeContext = context;
    super.setSystemContext(context);
  }
}

void main() {
  testWidgets(
    'AiChatScreen displays 4 starter prompts on empty state and sends upon tap',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiChatControllerProvider.overrideWith(_FakeAiChatController.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AiChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 4 starter prompts are visible
      expect(find.text('Ringkas agenda hari ini'), findsOneWidget);
      expect(find.text('Cek anomali keuangan'), findsOneWidget);
      expect(find.text('Ide catatan baru'), findsOneWidget);
      expect(find.text('Tugas prioritas'), findsOneWidget);

      // Tap on 'Ringkas agenda hari ini'
      await tester.tap(find.text('Ringkas agenda hari ini'));
      await tester.pumpAndSettle();

      expect(find.text('Ringkas agenda hari ini'), findsOneWidget);
    },
  );

  testWidgets(
    'AiChatScreen context attachment sheet enforces privacy wall without any Vault entries',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiChatControllerProvider.overrideWith(_FakeAiChatController.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AiChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Lampirkan Konteks'
      await tester.tap(find.byTooltip('Lampirkan Konteks').first);
      await tester.pumpAndSettle();

      expect(find.text('Lampirkan Konteks ke AI'), findsOneWidget);
      expect(
        find.textContaining('Dinding Privasi: Data Vault diisolasi 100%'),
        findsOneWidget,
      );

      // Permitted contexts exist
      expect(find.text('Ringkasan Keuangan Bulan Ini'), findsOneWidget);
      expect(find.text('Agenda & Jadwal Pertemuan'), findsOneWidget);
      expect(find.text('Catatan Pribadi Terbaru'), findsOneWidget);

      // STRICT PRIVACY CHECK: Vault options MUST NOT exist as selectable items!
      expect(find.text('Kata Sandi'), findsNothing);
      expect(find.text('Brankas'), findsNothing);
      expect(find.text('Akun Brankas'), findsNothing);

      // Tap on 'Ringkasan Keuangan Bulan Ini'
      await tester.tap(find.text('Ringkasan Keuangan Bulan Ini'));
      await tester.pumpAndSettle();

      // Sheet is closed and active context banner is displayed
      expect(find.byIcon(Icons.attach_file_rounded), findsWidgets);
      expect(find.textContaining('Konteks aktif:'), findsOneWidget);
    },
  );
}
