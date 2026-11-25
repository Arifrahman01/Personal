import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/config/secure_config_store.dart';

/// User preference toggle settings for which module cards appear on the 'Hari Ini' home dashboard.
class HomeModulePreferences {
  const HomeModulePreferences({
    this.showPrayer = true,
    this.showFocus = true,
    this.showFinance = true,
    this.showHabits = true,
    this.showAiBriefing = true,
    this.firstRunDismissed = false,
    this.isLoaded = false,
  });

  final bool showPrayer;
  final bool showFocus;
  final bool showFinance;
  final bool showHabits;
  final bool showAiBriefing;
  final bool firstRunDismissed;
  final bool isLoaded;

  HomeModulePreferences copyWith({
    bool? showPrayer,
    bool? showFocus,
    bool? showFinance,
    bool? showHabits,
    bool? showAiBriefing,
    bool? firstRunDismissed,
    bool? isLoaded,
  }) {
    return HomeModulePreferences(
      showPrayer: showPrayer ?? this.showPrayer,
      showFocus: showFocus ?? this.showFocus,
      showFinance: showFinance ?? this.showFinance,
      showHabits: showHabits ?? this.showHabits,
      showAiBriefing: showAiBriefing ?? this.showAiBriefing,
      firstRunDismissed: firstRunDismissed ?? this.firstRunDismissed,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showPrayer': showPrayer,
      'showFocus': showFocus,
      'showFinance': showFinance,
      'showHabits': showHabits,
      'showAiBriefing': showAiBriefing,
      'firstRunDismissed': firstRunDismissed,
    };
  }

  factory HomeModulePreferences.fromJson(Map<String, dynamic> json) {
    return HomeModulePreferences(
      showPrayer: json['showPrayer'] as bool? ?? true,
      showFocus: json['showFocus'] as bool? ?? true,
      showFinance: json['showFinance'] as bool? ?? true,
      showHabits: json['showHabits'] as bool? ?? true,
      showAiBriefing: json['showAiBriefing'] as bool? ?? true,
      firstRunDismissed: json['firstRunDismissed'] as bool? ?? false,
    );
  }
}

class HomeModulePreferencesNotifier extends Notifier<HomeModulePreferences> {
  bool _mutatedByUser = false;
  bool _disposed = false;

  @override
  HomeModulePreferences build() {
    _mutatedByUser = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_loadFromStore());
    return const HomeModulePreferences();
  }

  Future<void> _loadFromStore() async {
    try {
      final store = ref.read(secureConfigStoreProvider);
      final rawJson = await store.getHomeModulePrefsJson();
      final dismissed = await store.isFirstRunDismissed();
      if (_disposed || _mutatedByUser) return;

      var loaded = const HomeModulePreferences();
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          loaded = HomeModulePreferences.fromJson(decoded);
        }
      }
      state = loaded.copyWith(
        firstRunDismissed: loaded.firstRunDismissed || dismissed,
        isLoaded: true,
      );
    } catch (_) {
      if (!_disposed && !_mutatedByUser) {
        state = state.copyWith(isLoaded: true);
      }
    }
  }

  Future<void> _persistToStore() async {
    try {
      final store = ref.read(secureConfigStoreProvider);
      await store.setHomeModulePrefsJson(jsonEncode(state.toJson()));
      await store.setFirstRunDismissed(state.firstRunDismissed);
    } catch (_) {
      // Ignore persistence write errors safely.
    }
  }

  void togglePrayer(bool value) {
    _mutatedByUser = true;
    state = state.copyWith(showPrayer: value, isLoaded: true);
    unawaited(_persistToStore());
  }

  void toggleFocus(bool value) {
    _mutatedByUser = true;
    state = state.copyWith(showFocus: value, isLoaded: true);
    unawaited(_persistToStore());
  }

  void toggleFinance(bool value) {
    _mutatedByUser = true;
    state = state.copyWith(showFinance: value, isLoaded: true);
    unawaited(_persistToStore());
  }

  void toggleHabits(bool value) {
    _mutatedByUser = true;
    state = state.copyWith(showHabits: value, isLoaded: true);
    unawaited(_persistToStore());
  }

  void toggleAiBriefing(bool value) {
    _mutatedByUser = true;
    state = state.copyWith(showAiBriefing: value, isLoaded: true);
    unawaited(_persistToStore());
  }

  void dismissFirstRun() {
    _mutatedByUser = true;
    state = state.copyWith(firstRunDismissed: true, isLoaded: true);
    unawaited(_persistToStore());
  }
}

/// Provides reactive [HomeModulePreferences] to toggle home cards.
final homeModulePreferencesProvider =
    NotifierProvider<HomeModulePreferencesNotifier, HomeModulePreferences>(
  HomeModulePreferencesNotifier.new,
);
