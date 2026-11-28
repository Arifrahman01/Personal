import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Identifier unik untuk shortcut bawaan sistem.
abstract final class AppShortcutIds {
  static const String quickCapture = 'quick_capture';
  static const String prayerSchedule = 'prayer_schedule';
  static const String newNote = 'new_note';
  static const String newTransaction = 'new_transaction';

  /// Daftar semua shortcut ID bawaan yang valid.
  static const List<String> all = [
    quickCapture,
    prayerSchedule,
    newNote,
    newTransaction,
  ];
}

/// Rute navigasi target untuk masing-masing shortcut.
abstract final class AppShortcutRoutes {
  static const String quickCapture = '/quick_capture';
  static const String prayerSchedule = '/prayer_schedule';
  static const String newNote = '/notes/new';
  static const String newTransaction = '/finance/new';
  static const String home = '/';
}

/// Model representasi item shortcut aplikasi Android / iOS.
@immutable
class AppShortcutItem {
  const AppShortcutItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.targetRoute,
    this.targetTabIndex = 0,
    this.payload = const {},
    this.isEnabled = true,
    this.order = 0,
  });

  /// ID unik shortcut (mis. 'quick_capture', 'prayer_schedule').
  final String id;

  /// Label utama shortcut (maks ~25 karakter untuk launcher Android).
  final String title;

  /// Keterangan atau label panjang shortcut.
  final String subtitle;

  /// Nama resource ikon (mis. 'mic', 'compass', 'notebook_pen', 'receipt').
  final String iconName;

  /// Rute tujuan aplikasi (mis. '/quick_capture', '/prayer_schedule').
  final String targetRoute;

  /// Indeks tab di MainNavigationShell (0: Hari Ini, 1: Agenda, 2: Catatan, 3: Keuangan, 4: Vault).
  final int targetTabIndex;

  /// Metadata tambahan untuk payload intent saat shortcut dipicu.
  final Map<String, dynamic> payload;

  /// Status aktif atau non-aktif shortcut.
  final bool isEnabled;

  /// Urutan prioritas tampilan shortcut di launcher.
  final int order;

  /// Membuat salinan objek dengan modifikasi bidang tertentu.
  AppShortcutItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconName,
    String? targetRoute,
    int? targetTabIndex,
    Map<String, dynamic>? payload,
    bool? isEnabled,
    int? order,
  }) {
    return AppShortcutItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      targetRoute: targetRoute ?? this.targetRoute,
      targetTabIndex: targetTabIndex ?? this.targetTabIndex,
      payload: payload ?? this.payload,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
    );
  }

  /// Serialisasi ke Map JSON.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'iconName': iconName,
    'targetRoute': targetRoute,
    'targetTabIndex': targetTabIndex,
    'payload': payload,
    'isEnabled': isEnabled,
    'order': order,
  };

  /// Deserialisasi dari Map JSON.
  factory AppShortcutItem.fromMap(Map<String, dynamic> map) {
    return AppShortcutItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      iconName: map['iconName'] as String? ?? '',
      targetRoute: map['targetRoute'] as String? ?? '/',
      targetTabIndex: (map['targetTabIndex'] as num?)?.toInt() ?? 0,
      payload:
          map['payload'] is Map
              ? Map<String, dynamic>.from(map['payload'] as Map)
              : const {},
      isEnabled: map['isEnabled'] as bool? ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serialisasi ke string JSON.
  String toJson() => jsonEncode(toMap());

  /// Deserialisasi dari string JSON.
  factory AppShortcutItem.fromJson(String source) =>
      AppShortcutItem.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppShortcutItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          iconName == other.iconName &&
          targetRoute == other.targetRoute &&
          targetTabIndex == other.targetTabIndex &&
          mapEquals(payload, other.payload) &&
          isEnabled == other.isEnabled &&
          order == other.order;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    subtitle,
    iconName,
    targetRoute,
    targetTabIndex,
    Object.hashAll(payload.keys),
    Object.hashAll(payload.values),
    isEnabled,
    order,
  );

  @override
  String toString() =>
      'AppShortcutItem(id: $id, title: "$title", route: $targetRoute, tabIndex: $targetTabIndex)';
}

/// Hasil resolusi dari penanganan shortcut intent platform Android / iOS.
@immutable
class AppShortcutIntentResult {
  const AppShortcutIntentResult({
    required this.shortcutId,
    required this.tabIndex,
    required this.route,
    this.payload = const {},
    this.isRecognized = true,
    this.isFallback = false,
  });

  /// ID shortcut yang teridentifikasi atau di-fallback.
  final String shortcutId;

  /// Indeks tab tujuan di navigasi utama aplikasi (0: Beranda, 1: Catatan, dll).
  final int tabIndex;

  /// Rute navigasi tujuan aplikasi.
  final String route;

  /// Payload data / aksi terkait shortcut intent.
  final Map<String, dynamic> payload;

  /// Apakah intent dikenali dalam daftar shortcut terdaftar.
  final bool isRecognized;

  /// Apakah hasil ini merupakan fallback dari input tidak valid / tidak dikenal.
  final bool isFallback;

  /// Factory untuk menghasilkan fallback yang aman (navigasi ke Beranda).
  factory AppShortcutIntentResult.fallback([String? shortcutId]) {
    final effectiveId =
        (shortcutId != null && shortcutId.trim().isNotEmpty)
            ? shortcutId.trim()
            : 'unknown';
    return AppShortcutIntentResult(
      shortcutId: effectiveId,
      tabIndex: 0,
      route: AppShortcutRoutes.home,
      payload: const {
        'action': 'none',
        'isFallback': true,
      },
      isRecognized: false,
      isFallback: true,
    );
  }

  Map<String, dynamic> toMap() => {
    'shortcutId': shortcutId,
    'tabIndex': tabIndex,
    'route': route,
    'payload': payload,
    'isRecognized': isRecognized,
    'isFallback': isFallback,
  };

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppShortcutIntentResult &&
          runtimeType == other.runtimeType &&
          shortcutId == other.shortcutId &&
          tabIndex == other.tabIndex &&
          route == other.route &&
          mapEquals(payload, other.payload) &&
          isRecognized == other.isRecognized &&
          isFallback == other.isFallback;

  @override
  int get hashCode => Object.hash(
    shortcutId,
    tabIndex,
    route,
    Object.hashAll(payload.keys),
    Object.hashAll(payload.values),
    isRecognized,
    isFallback,
  );

  @override
  String toString() =>
      'AppShortcutIntentResult(id: $shortcutId, tabIndex: $tabIndex, route: $route, isRecognized: $isRecognized, isFallback: $isFallback)';
}

/// Service untuk mengelola enumerasi dan resolusi App Shortcuts dan Android Quick Settings.
class AppShortcutsService {
  const AppShortcutsService();

  /// Daftar pre-defined shortcuts resmi aplikasi Personal Hub.
  static const List<AppShortcutItem> _predefinedShortcuts = [
    AppShortcutItem(
      id: AppShortcutIds.quickCapture,
      title: 'Catat Cepat (Voice/Teks)',
      subtitle: 'Input suara atau ketik cepat',
      iconName: 'mic',
      targetRoute: AppShortcutRoutes.quickCapture,
      targetTabIndex: 0,
      payload: {
        'action': 'quick_capture',
        'mode': 'voice_text',
        'shortcutId': AppShortcutIds.quickCapture,
      },
      order: 1,
    ),
    AppShortcutItem(
      id: AppShortcutIds.prayerSchedule,
      title: 'Jadwal Sholat & Kiblat',
      subtitle: 'Jadwal sholat harian & arah kiblat',
      iconName: 'compass',
      targetRoute: AppShortcutRoutes.prayerSchedule,
      targetTabIndex: 1, // Tab Agenda -> sub-bagian 2 (Sholat & Kiblat)
      payload: {
        'action': 'prayer_schedule',
        'agendaSection': 2,
        'shortcutId': AppShortcutIds.prayerSchedule,
      },
      order: 2,
    ),
    AppShortcutItem(
      id: AppShortcutIds.newNote,
      title: 'Catatan Baru',
      subtitle: 'Buat catatan teks atau checklist baru',
      iconName: 'notebook_pen',
      targetRoute: AppShortcutRoutes.newNote,
      targetTabIndex: 2, // Tab Catatan di MainNavigationShell
      payload: {
        'action': 'new_note',
        'shortcutId': AppShortcutIds.newNote,
      },
      order: 3,
    ),
    AppShortcutItem(
      id: AppShortcutIds.newTransaction,
      title: 'Catat Pengeluaran',
      subtitle: 'Catat transaksi & pengeluaran baru',
      iconName: 'receipt',
      targetRoute: AppShortcutRoutes.newTransaction,
      targetTabIndex: 3, // Tab Keuangan di MainNavigationShell
      payload: {
        'action': 'new_transaction',
        'type': 'expense',
        'shortcutId': AppShortcutIds.newTransaction,
      },
      order: 4,
    ),
  ];

  /// Mengembalikan daftar semua shortcut yang tersedia (unmodifiable list).
  List<AppShortcutItem> getAvailableShortcuts() {
    return UnmodifiableListView<AppShortcutItem>(_predefinedShortcuts);
  }

  /// Mengembalikan shortcut spesifik berdasarkan ID, atau `null` jika tidak ditemukan.
  AppShortcutItem? getShortcutById(String shortcutId) {
    final normalized = normalizeShortcutId(shortcutId);
    if (normalized.isEmpty) return null;

    for (final item in _predefinedShortcuts) {
      if (item.id == normalized) {
        return item;
      }
    }
    return null;
  }

  /// Memeriksa apakah suatu shortcut ID didukung oleh sistem.
  bool isSupportedShortcut(String shortcutId) {
    return getShortcutById(shortcutId) != null;
  }

  /// Membersihkan dan menormalisasi identifier shortcut mentah dari platform Android intent / URI.
  ///
  /// Mendukung parsing format:
  /// - Direct ID: `'quick_capture'`
  /// - Package prefixed: `'id.personal.hub.personal_hub.quick_capture'`
  /// - Action prefixed: `'android.intent.action.quick_capture'`, `'action_quick_capture'`
  /// - Shortcut prefixed: `'shortcut_quick_capture'`
  /// - URI deep link: `'personalhub://shortcut/quick_capture'`, `'app://shortcut?id=quick_capture'`
  /// - Quick settings tile: `'quick_settings_tile'`, `'quick_settings_quick_capture'` -> `'quick_capture'`
  String normalizeShortcutId(String? rawShortcutId) {
    if (rawShortcutId == null) return '';
    var cleaned = rawShortcutId.trim();
    if (cleaned.isEmpty) return '';

    // 1. Ekstraksi URI jika berupa skema deep link
    if (cleaned.contains('://')) {
      final uri = Uri.tryParse(cleaned);
      if (uri != null) {
        // Cek query parameter `id` (mis. ?id=quick_capture)
        final paramId = uri.queryParameters['id'] ?? uri.queryParameters['shortcut_id'];
        if (paramId != null && paramId.trim().isNotEmpty) {
          cleaned = paramId.trim();
        } else if (uri.pathSegments.isNotEmpty) {
          // Ambil path segment terakhir (mis. /shortcut/quick_capture -> quick_capture)
          cleaned = uri.pathSegments.last;
        } else if (uri.host.isNotEmpty && uri.host != 'shortcut') {
          cleaned = uri.host;
        }
      }
    }

    // 2. Pembersihan prefix Android umum
    cleaned = cleaned.toLowerCase();

    // Mapping Android Quick Settings Tile ke shortcut yang sesuai
    if (cleaned == 'quick_settings_tile' ||
        cleaned == 'quick_settings_tile_capture' ||
        cleaned == 'quick_settings_capture' ||
        cleaned == 'qs_capture') {
      return AppShortcutIds.quickCapture;
    }
    if (cleaned == 'quick_settings_prayer' || cleaned == 'qs_prayer') {
      return AppShortcutIds.prayerSchedule;
    }

    // Hapus prefix package Android
    const packagePrefix = 'id.personal.hub.personal_hub.';
    if (cleaned.startsWith(packagePrefix)) {
      cleaned = cleaned.substring(packagePrefix.length);
    }

    // Hapus prefix action Android
    const intentActionPrefix = 'android.intent.action.';
    if (cleaned.startsWith(intentActionPrefix)) {
      cleaned = cleaned.substring(intentActionPrefix.length);
    }

    const actionPrefix = 'action_';
    if (cleaned.startsWith(actionPrefix)) {
      cleaned = cleaned.substring(actionPrefix.length);
    }

    const shortcutPrefix = 'shortcut_';
    if (cleaned.startsWith(shortcutPrefix)) {
      cleaned = cleaned.substring(shortcutPrefix.length);
    }

    // Cocokkan dengan pre-defined IDs
    for (final id in AppShortcutIds.all) {
      if (cleaned == id || cleaned.endsWith(id)) {
        return id;
      }
    }

    return cleaned;
  }

  /// Menangani intent shortcut dari platform Android/iOS.
  ///
  /// Mengembalikan [AppShortcutIntentResult] yang berisi tab index navigasi tujuan,
  /// rute target, dan payload aksi. Jika shortcut ID tidak dikenali atau kosong,
  /// mengembalikan hasil fallback yang aman menuju Beranda (tab index 0).
  AppShortcutIntentResult handleShortcutIntent(String shortcutId) {
    final normalized = normalizeShortcutId(shortcutId);

    if (normalized.isEmpty) {
      return AppShortcutIntentResult.fallback(shortcutId);
    }

    final matched = getShortcutById(normalized);
    if (matched == null) {
      return AppShortcutIntentResult.fallback(shortcutId);
    }

    return AppShortcutIntentResult(
      shortcutId: matched.id,
      tabIndex: matched.targetTabIndex,
      route: matched.targetRoute,
      payload: Map<String, dynamic>.unmodifiable(matched.payload),
      isRecognized: true,
      isFallback: false,
    );
  }

  /// Mengembalikan subset shortcut yang didaftarkan secara statis di Android `shortcuts.xml`.
  List<AppShortcutItem> getStaticShortcuts() {
    return _predefinedShortcuts
        .where(
          (s) =>
              s.id == AppShortcutIds.quickCapture ||
              s.id == AppShortcutIds.prayerSchedule ||
              s.id == AppShortcutIds.newNote,
        )
        .toList(growable: false);
  }

  /// Mengembalikan subset shortcut dinamis yang dapat diatur saat runtime.
  List<AppShortcutItem> getDynamicShortcuts() {
    return _predefinedShortcuts
        .where((s) => s.id == AppShortcutIds.newTransaction)
        .toList(growable: false);
  }
}
