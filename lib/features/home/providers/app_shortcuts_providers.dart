import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/features/home/services/app_shortcuts_service.dart';

/// Menyediakan singleton stateless [AppShortcutsService].
final appShortcutsServiceProvider = Provider<AppShortcutsService>((ref) {
  return const AppShortcutsService();
});

/// Menyediakan daftar semua shortcut aplikasi yang tersedia.
final availableShortcutsProvider = Provider<List<AppShortcutItem>>((ref) {
  return ref.watch(appShortcutsServiceProvider).getAvailableShortcuts();
});

/// Menyediakan shortcut tertentu berdasarkan ID.
final shortcutByIdProvider =
    Provider.family<AppShortcutItem?, String>((ref, id) {
      return ref.watch(appShortcutsServiceProvider).getShortcutById(id);
    });

/// Menyediakan daftar shortcut statis yang terdaftar di Android `shortcuts.xml`.
final staticShortcutsProvider = Provider<List<AppShortcutItem>>((ref) {
  return ref.watch(appShortcutsServiceProvider).getStaticShortcuts();
});

/// Menyediakan daftar shortcut dinamis yang diperbarui saat runtime.
final dynamicShortcutsProvider = Provider<List<AppShortcutItem>>((ref) {
  return ref.watch(appShortcutsServiceProvider).getDynamicShortcuts();
});

/// Notifier yang mengelola status shortcut intent aktif yang diterima dari platform OS
/// (Android App Shortcuts, Quick Settings Tiles, atau URI Deep Links).
class ActiveShortcutIntentNotifier extends Notifier<AppShortcutIntentResult?> {
  @override
  AppShortcutIntentResult? build() => null;

  /// Memproses shortcut intent mentah dari platform dan memperbarui state.
  AppShortcutIntentResult processShortcutIntent(String rawShortcutId) {
    final service = ref.read(appShortcutsServiceProvider);
    final result = service.handleShortcutIntent(rawShortcutId);
    state = result;
    return result;
  }

  /// Menyetel hasil shortcut intent secara langsung (mis. untuk pengujian atau custom routing).
  void setIntentResult(AppShortcutIntentResult? result) {
    state = result;
  }

  /// Mengosongkan shortcut intent yang sudah selesai ditangani oleh UI navigasi.
  void clear() {
    state = null;
  }
}

/// Menyediakan state shortcut intent aktif saat ini.
final activeShortcutIntentProvider =
    NotifierProvider<ActiveShortcutIntentNotifier, AppShortcutIntentResult?>(
      ActiveShortcutIntentNotifier.new,
    );

/// Menyediakan indeks tab tujuan (0..4) dari shortcut intent aktif, atau null jika tidak ada.
final activeShortcutDestinationTabIndexProvider = Provider<int?>((ref) {
  return ref.watch(activeShortcutIntentProvider)?.tabIndex;
});

/// Menyediakan rute tujuan dari shortcut intent aktif, atau null jika tidak ada.
final activeShortcutRouteProvider = Provider<String?>((ref) {
  return ref.watch(activeShortcutIntentProvider)?.route;
});
