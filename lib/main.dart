import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/app.dart';
import 'package:personal_hub/core/database/app_database.dart';
import 'package:personal_hub/core/theme/app_theme.dart';
import 'package:personal_hub/core/theme/glass_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final appDatabase = await AppDatabase.open();
    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
        child: const PersonalHubApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Gagal memulai Personal Hub: $error\n$stackTrace');
    runApp(_StartupErrorApp(error: error.toString()));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: GlassScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal Memulai Personal Hub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Aplikasi tidak dapat membuka basis data lokal. Pastikan penyimpanan perangkat atau browser tersedia lalu muat ulang aplikasi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
