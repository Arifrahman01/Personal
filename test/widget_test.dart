import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/features/ai/data/chat_repository.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/providers/ai_providers.dart';

class _InMemoryChatRepository implements ChatRepository {
  final List<ChatThreadMessage> _messages = [];

  @override
  Future<void> clearHistory() async {
    _messages.clear();
  }

  @override
  Future<List<ChatThreadMessage>> getMessages() async {
    return List<ChatThreadMessage>.unmodifiable(_messages);
  }

  @override
  Future<void> saveMessage(ChatThreadMessage message) async {
    _messages.add(message);
  }
}

void main() {
  testWidgets('PersonalHubApp renders 5-tab Indonesian NavigationBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(_InMemoryChatRepository()),
        ],
        child: const PersonalHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    for (final label in ['Beranda', 'Catatan', 'Meeting', 'Vault', 'AI']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.descendant(of: navBar, matching: find.text('Vault')));
    await tester.pumpAndSettle();

    expect(find.text('Modul Vault siap digunakan.'), findsOneWidget);

    await tester.tap(find.descendant(of: navBar, matching: find.text('AI')));
    await tester.pumpAndSettle();

    expect(find.text('Asisten AI'), findsOneWidget);
    expect(find.text('Asisten AI Samudra'), findsOneWidget);
  });
}
