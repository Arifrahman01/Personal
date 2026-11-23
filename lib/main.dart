import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
      child: const PersonalHubApp(),
    ),
  );
}
