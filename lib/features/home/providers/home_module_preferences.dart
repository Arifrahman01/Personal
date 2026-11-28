import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/storage/app_preferences_repository.dart';

/// User preference toggle settings for which module cards appear on the 'Hari Ini' home dashboard.
class HomeModulePreferences {
  const HomeModulePreferences({
    this.showPrayer = true,
    this.showFocus = true,
    this.showFinance = true,
    this.showHabits = true,
    this.showAiBriefing = true,
  });

  final bool showPrayer;
  final bool showFocus;
  final bool showFinance;
  final bool showHabits;
  final bool showAiBriefing;

  Map<String, dynamic> toJson() => {
    'showPrayer': showPrayer,
    'showFocus': showFocus,
    'showFinance': showFinance,
    'showHabits': showHabits,
    'showAiBriefing': showAiBriefing,
  };

  factory HomeModulePreferences.fromJson(Map<String, dynamic> json) {
    return HomeModulePreferences(
      showPrayer: json['showPrayer'] as bool? ?? true,
      showFocus: json['showFocus'] as bool? ?? true,
      showFinance: json['showFinance'] as bool? ?? true,
      showHabits: json['showHabits'] as bool? ?? true,
      showAiBriefing: json['showAiBriefing'] as bool? ?? true,
    );
  }

  HomeModulePreferences copyWith({
    bool? showPrayer,
    bool? showFocus,
    bool? showFinance,
    bool? showHabits,
    bool? showAiBriefing,
  }) {
    return HomeModulePreferences(
      showPrayer: showPrayer ?? this.showPrayer,
      showFocus: showFocus ?? this.showFocus,
      showFinance: showFinance ?? this.showFinance,
      showHabits: showHabits ?? this.showHabits,
      showAiBriefing: showAiBriefing ?? this.showAiBriefing,
    );
  }
}

class HomeModulePreferencesNotifier extends Notifier<HomeModulePreferences> {
  @override
  HomeModulePreferences build() =>
      ref.watch(initialHomeModulePreferencesProvider);

  void _update(HomeModulePreferences next) {
    state = next;
    unawaited(
      ref
          .read(appPreferencesStoreProvider)
          .setString(
            AppPreferenceKeys.homeModuleVisibility,
            jsonEncode(next.toJson()),
          )
          .catchError((_) {}),
    );
  }

  void togglePrayer(bool value) => _update(state.copyWith(showPrayer: value));
  void toggleFocus(bool value) => _update(state.copyWith(showFocus: value));
  void toggleFinance(bool value) => _update(state.copyWith(showFinance: value));
  void toggleHabits(bool value) => _update(state.copyWith(showHabits: value));
  void toggleAiBriefing(bool value) =>
      _update(state.copyWith(showAiBriefing: value));
}

/// Provides reactive [HomeModulePreferences] to toggle home cards.
final homeModulePreferencesProvider =
    NotifierProvider<HomeModulePreferencesNotifier, HomeModulePreferences>(
  HomeModulePreferencesNotifier.new,
);
