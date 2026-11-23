/// Hybrid 3-Tier AI Router Models (F-13 Router Architecture).
///
/// Models for routing queries across:
/// - Tier 1: Regex & Heuristics (~10ms)
/// - Tier 2: Local SLM (~200ms)
/// - Tier 3: Cloud Samudra AI (~1200ms)
library;

/// Represents the tier used or chosen for AI processing in the hybrid routing architecture.
enum AiTier {
  /// Tier 1: Regex & heuristic pattern matcher (~10ms). Zero network or SLM cost.
  tier1Heuristic,

  /// Tier 2: On-device Small Language Model (~200ms). Local, offline-capable inference.
  tier2LocalSlm,

  /// Tier 3: Cloud Samudra AI inference (~1200ms). High reasoning capability.
  tier3CloudSamudra;

  String get displayName {
    switch (this) {
      case AiTier.tier1Heuristic:
        return 'Tier 1 (Regex/Heuristik)';
      case AiTier.tier2LocalSlm:
        return 'Tier 2 (Local SLM)';
      case AiTier.tier3CloudSamudra:
        return 'Tier 3 (Cloud Samudra)';
    }
  }

  bool get isLocal => this != AiTier.tier3CloudSamudra;
}

/// Represents the classification or functional domain of the user's AI query.
enum AiTaskType {
  /// Extracting expenses or financial entries (e.g. "beli kopi 25rb").
  financeExpense,

  /// Extracting tasks, todos, deadlines (e.g. "ingatkan meeting jam 3").
  taskExtraction,

  /// Summarizing short or long user notes.
  noteSummarization,

  /// Generating meeting briefing or parsing action items from minutes.
  meetingBriefing,

  /// Open-ended conversation, Q&A, and broad assistance.
  openChat,
}

/// Represents the evaluated complexity of the user query.
enum AiQueryComplexity {
  /// Highly structured, short, regex-matchable, or trivial greeting.
  low,

  /// Moderate length or multi-clause sentence requiring local semantic understanding.
  medium,

  /// Complex reasoning, lengthy document/context, or creative deep Q&A.
  high,
}

/// Input context describing the user prompt and execution constraints.
class AiQueryContext {
  const AiQueryContext({
    required this.text,
    this.taskType = AiTaskType.openChat,
    this.isDeviceOnline = true,
    this.forceLocal = false,
    this.userPreferredTier,
  });

  /// The raw natural language query or prompt.
  final String text;

  /// The domain task type of the query.
  final AiTaskType taskType;

  /// Whether the host device currently has active network connectivity.
  final bool isDeviceOnline;

  /// Whether the user or privacy setting requires purely on-device execution.
  final bool forceLocal;

  /// Optional user-forced preference for a specific tier.
  final AiTier? userPreferredTier;

  AiQueryContext copyWith({
    String? text,
    AiTaskType? taskType,
    bool? isDeviceOnline,
    bool? forceLocal,
    AiTier? userPreferredTier,
  }) {
    return AiQueryContext(
      text: text ?? this.text,
      taskType: taskType ?? this.taskType,
      isDeviceOnline: isDeviceOnline ?? this.isDeviceOnline,
      forceLocal: forceLocal ?? this.forceLocal,
      userPreferredTier: userPreferredTier ?? this.userPreferredTier,
    );
  }

  @override
  String toString() =>
      'AiQueryContext(text: "$text", taskType: $taskType, online: $isDeviceOnline, forceLocal: $forceLocal, preferred: $userPreferredTier)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiQueryContext &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          taskType == other.taskType &&
          isDeviceOnline == other.isDeviceOnline &&
          forceLocal == other.forceLocal &&
          userPreferredTier == other.userPreferredTier;

  @override
  int get hashCode =>
      text.hashCode ^
      taskType.hashCode ^
      isDeviceOnline.hashCode ^
      forceLocal.hashCode ^
      userPreferredTier.hashCode;
}

/// The routing decision made by the router before execution.
class AiRoutingDecision {
  const AiRoutingDecision({
    required this.chosenTier,
    required this.reason,
    required this.expectedLatencyMs,
  });

  final AiTier chosenTier;
  final String reason;
  final int expectedLatencyMs;

  @override
  String toString() =>
      'AiRoutingDecision(chosenTier: $chosenTier, expectedLatency: ${expectedLatencyMs}ms, reason: "$reason")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiRoutingDecision &&
          runtimeType == other.runtimeType &&
          chosenTier == other.chosenTier &&
          reason == other.reason &&
          expectedLatencyMs == other.expectedLatencyMs;

  @override
  int get hashCode =>
      chosenTier.hashCode ^ reason.hashCode ^ expectedLatencyMs.hashCode;
}

/// The execution outcome returned by the hybrid router.
class AiExecutionResult {
  const AiExecutionResult({
    required this.text,
    required this.usedTier,
    required this.isFallback,
    required this.latencyMs,
    this.rawData,
  });

  /// The generated message or extracted summary.
  final String text;

  /// The tier that ultimately executed and produced this result.
  final AiTier usedTier;

  /// True if fallback was triggered from a higher or preferred tier.
  final bool isFallback;

  /// Real elapsed execution latency in milliseconds.
  final int latencyMs;

  /// Optional structured parsed data (e.g. `Map<String, dynamic>` or parsed objects).
  final dynamic rawData;

  @override
  String toString() =>
      'AiExecutionResult(usedTier: $usedTier, isFallback: $isFallback, latency: ${latencyMs}ms, text: "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiExecutionResult &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          usedTier == other.usedTier &&
          isFallback == other.isFallback &&
          latencyMs == other.latencyMs;

  @override
  int get hashCode =>
      text.hashCode ^
      usedTier.hashCode ^
      isFallback.hashCode ^
      latencyMs.hashCode;
}

/// Accumulative performance metrics and hit counts for the AI Router.
class AiRouterStats {
  const AiRouterStats({
    this.totalRequests = 0,
    this.tier1Hits = 0,
    this.tier2Hits = 0,
    this.tier3Hits = 0,
    this.fallbackCount = 0,
  });

  final int totalRequests;
  final int tier1Hits;
  final int tier2Hits;
  final int tier3Hits;
  final int fallbackCount;

  static const AiRouterStats empty = AiRouterStats();

  AiRouterStats copyWith({
    int? totalRequests,
    int? tier1Hits,
    int? tier2Hits,
    int? tier3Hits,
    int? fallbackCount,
  }) {
    return AiRouterStats(
      totalRequests: totalRequests ?? this.totalRequests,
      tier1Hits: tier1Hits ?? this.tier1Hits,
      tier2Hits: tier2Hits ?? this.tier2Hits,
      tier3Hits: tier3Hits ?? this.tier3Hits,
      fallbackCount: fallbackCount ?? this.fallbackCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'totalRequests': totalRequests,
    'tier1Hits': tier1Hits,
    'tier2Hits': tier2Hits,
    'tier3Hits': tier3Hits,
    'fallbackCount': fallbackCount,
  };

  @override
  String toString() =>
      'AiRouterStats(total: $totalRequests, tier1: $tier1Hits, tier2: $tier2Hits, tier3: $tier3Hits, fallbacks: $fallbackCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiRouterStats &&
          runtimeType == other.runtimeType &&
          totalRequests == other.totalRequests &&
          tier1Hits == other.tier1Hits &&
          tier2Hits == other.tier2Hits &&
          tier3Hits == other.tier3Hits &&
          fallbackCount == other.fallbackCount;

  @override
  int get hashCode =>
      totalRequests.hashCode ^
      tier1Hits.hashCode ^
      tier2Hits.hashCode ^
      tier3Hits.hashCode ^
      fallbackCount.hashCode;
}
