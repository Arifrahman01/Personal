import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/app.dart';

void main() {
  testWidgets('PersonalHubApp renders 5-tab Indonesian NavigationBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PersonalHubApp()));

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
  });
}
