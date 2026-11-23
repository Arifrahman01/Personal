import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  HomeModulePreferences build() => const HomeModulePreferences();

  void togglePrayer(bool value) => state = state.copyWith(showPrayer: value);
  void toggleFocus(bool value) => state = state.copyWith(showFocus: value);
  void toggleFinance(bool value) => state = state.copyWith(showFinance: value);
  void toggleHabits(bool value) => state = state.copyWith(showHabits: value);
  void toggleAiBriefing(bool value) =>
      state = state.copyWith(showAiBriefing: value);
}

/// Provides reactive [HomeModulePreferences] to toggle home cards.
final homeModulePreferencesProvider =
    NotifierProvider<HomeModulePreferencesNotifier, HomeModulePreferences>(
  HomeModulePreferencesNotifier.new,
);
