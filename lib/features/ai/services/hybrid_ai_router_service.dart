import 'dart:async';

import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/models/hybrid_router_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';

/// Handler type signature for individual tier execution in the hybrid router.
typedef AiTierExecutionHandler =
    FutureOr<AiTierOutput> Function(AiQueryContext context);

/// Internal structured output produced by a tier handler.
class AiTierOutput {
  const AiTierOutput({required this.text, this.rawData});

  final String text;
  final dynamic rawData;
}

/// Hybrid 3-Tier AI Router & Fallback Orchestrator (F-13 Router).
///
/// Seamlessly distributes AI queries across three processing tiers:
/// - Tier 1: Regex & Heuristics (~10ms)
/// - Tier 2: Local SLM on-device (~200ms)
/// - Tier 3: Cloud Samudra AI (~1200ms)
///
/// Guarantees offline resilience, zero UI crashes via multi-tier fallback,
/// and tracks router metrics and hit distributions.
class HybridAiRouterService {
  HybridAiRouterService({
    this.cloudClient,
    this.cloudHandler,
    this.localSlmHandler,
    this.heuristicHandler,
    this.onStatsChanged,
  });

  final SamudraAiClient? cloudClient;
  final AiTierExecutionHandler? cloudHandler;
  final AiTierExecutionHandler? localSlmHandler;
  final AiTierExecutionHandler? heuristicHandler;

  /// Optional listener triggered whenever [stats] updates.
  void Function(AiRouterStats stats)? onStatsChanged;

  AiRouterStats _stats = const AiRouterStats();

  /// Current routing statistics and hit distribution.
  AiRouterStats get stats => _stats;

  /// Resets router performance metrics.
  void resetStats() {
    _stats = const AiRouterStats();
    onStatsChanged?.call(_stats);
  }

  // ===========================================================================
  // TIER 1 REGEX PATTERNS & HEURISTICS
  // ===========================================================================

  static final RegExp _expensePattern1 = RegExp(
    r'(?:beli|makan|bayar|ongkir|belanja|pesan|jajan|ngopi|isi|checkout)\s+(.+?)\s+(\d+(?:[.,]\d+)?)\s*(rb|k|ribu|jt|juta)?',
    caseSensitive: false,
  );

  static final RegExp _expensePattern2 = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(rb|k|ribu|jt|juta)?\s+(?:buat|untuk|beli|makan|bayar)?\s*(.+)',
    caseSensitive: false,
  );

  static final RegExp _taskPattern = RegExp(
    r'^(?:ingatkan|ingatkan saya|todo:?|tugas:?|catat:?|deadline:?)\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _greetingPattern = RegExp(
    r'^(?:halo|hai|hei|hello|hi|p|ping|assalamu\s*alaikum|selamat pagi|selamat siang|selamat malam|terima kasih|makasih|siapa kamu|apa kabar)[!?.]*$',
    caseSensitive: false,
  );

  /// Checks whether [context] can be solved directly by Tier 1 Heuristics.
  bool canHandleWithHeuristics(AiQueryContext context) {
    final text = context.text.trim();
    if (text.isEmpty) return true;

    switch (context.taskType) {
      case AiTaskType.financeExpense:
        return _expensePattern1.hasMatch(text) ||
            _expensePattern2.hasMatch(text);
      case AiTaskType.taskExtraction:
        return _taskPattern.hasMatch(text);
      case AiTaskType.openChat:
        return _greetingPattern.hasMatch(text);
      case AiTaskType.noteSummarization:
      case AiTaskType.meetingBriefing:
        // Tier 1 handles trivial short notes (< 40 chars)
        return text.length < 40;
    }
  }

  /// Evaluates query complexity: low, medium, or high.
  AiQueryComplexity assessComplexity(AiQueryContext context) {
    final text = context.text.trim();
    if (text.isEmpty) return AiQueryComplexity.low;

    // Check for Tier 1 match first
    if (canHandleWithHeuristics(context)) {
      return AiQueryComplexity.low;
    }

    // High complexity conditions
    if (text.length > 200) {
      return AiQueryComplexity.high;
    }

    final lower = text.toLowerCase();
    final hasComplexKeywords =
        lower.contains('analisis') ||
        lower.contains('mengapa') ||
        lower.contains('bagaimana') ||
        lower.contains('jelaskan secara detail') ||
        lower.contains('bandingkan');

    if (hasComplexKeywords) {
      return AiQueryComplexity.high;
    }

    if (context.taskType == AiTaskType.openChat &&
        (text.length > 45 || text.contains('?'))) {
      return AiQueryComplexity.high;
    }

    if (context.taskType == AiTaskType.meetingBriefing ||
        context.taskType == AiTaskType.noteSummarization) {
      if (text.length > 100) return AiQueryComplexity.high;
      return AiQueryComplexity.medium;
    }

    return AiQueryComplexity.medium;
  }

  // ===========================================================================
  // TIER ROUTING DECISION
  // ===========================================================================

  /// Intelligently determines the appropriate [AiTier] for [context].
  ///
  /// Routing Rules:
  /// 1. If offline (`!context.isDeviceOnline`) or privacy-forced (`context.forceLocal`):
  ///    - NEVER select [AiTier.tier3CloudSamudra].
  ///    - If simple regex match: Tier 1 (Heuristic).
  ///    - Otherwise: Tier 2 (Local SLM).
  /// 2. If online:
  ///    - If user specifies [userPreferredTier], respect it.
  ///    - If simple high-speed pattern ("beli kopi 25rb"): Tier 1 (10ms) or Tier 2 (200ms)
  ///      to save cloud quota and deliver instant UI response.
  ///    - If complex reasoning / openChat / high complexity: Tier 3 (Cloud Samudra AI).
  AiRoutingDecision determineRoutingTier(AiQueryContext context) {
    final isConstrainedLocal = !context.isDeviceOnline || context.forceLocal;

    // Rule 1: Offline or Force-Local constraint
    if (isConstrainedLocal) {
      if (context.userPreferredTier == AiTier.tier1Heuristic) {
        return const AiRoutingDecision(
          chosenTier: AiTier.tier1Heuristic,
          reason: 'Mode Offline/Lokal: Mengikuti preferensi pengguna Tier 1',
          expectedLatencyMs: 10,
        );
      }
      if (context.userPreferredTier == AiTier.tier2LocalSlm) {
        return const AiRoutingDecision(
          chosenTier: AiTier.tier2LocalSlm,
          reason: 'Mode Offline/Lokal: Mengikuti preferensi pengguna Tier 2',
          expectedLatencyMs: 200,
        );
      }

      // If user preferred Cloud but device is offline/forced local -> Downgrade safely!
      if (canHandleWithHeuristics(context)) {
        return const AiRoutingDecision(
          chosenTier: AiTier.tier1Heuristic,
          reason:
              'Mode Offline/Lokal: Pola cocok dengan aturan Tier 1 Heuristik',
          expectedLatencyMs: 10,
        );
      }

      return const AiRoutingDecision(
        chosenTier: AiTier.tier2LocalSlm,
        reason:
            'Mode Offline/Lokal: Kueri dialihkan ke Tier 2 Local SLM (Tier 3 tidak tersedia)',
        expectedLatencyMs: 200,
      );
    }

    // Rule 2: Online with user preferred tier
    if (context.userPreferredTier != null) {
      switch (context.userPreferredTier!) {
        case AiTier.tier1Heuristic:
          return const AiRoutingDecision(
            chosenTier: AiTier.tier1Heuristic,
            reason: 'Preferensi pengguna: Tier 1 Heuristik',
            expectedLatencyMs: 10,
          );
        case AiTier.tier2LocalSlm:
          return const AiRoutingDecision(
            chosenTier: AiTier.tier2LocalSlm,
            reason: 'Preferensi pengguna: Tier 2 Local SLM',
            expectedLatencyMs: 200,
          );
        case AiTier.tier3CloudSamudra:
          return const AiRoutingDecision(
            chosenTier: AiTier.tier3CloudSamudra,
            reason: 'Preferensi pengguna: Tier 3 Cloud Samudra AI',
            expectedLatencyMs: 1200,
          );
      }
    }

    // Rule 3: Online dynamic routing based on speed, pattern, and complexity
    final canUseHeuristic = canHandleWithHeuristics(context);
    final complexity = assessComplexity(context);

    // Fast-path: simple regex pattern (e.g. "beli kopi 25rb")
    if (canUseHeuristic && complexity == AiQueryComplexity.low) {
      return const AiRoutingDecision(
        chosenTier: AiTier.tier1Heuristic,
        reason:
            'Tugas berkecepatan tinggi dengan pola regex sederhana: Tier 1 Heuristik (~10ms) untuk menghemat kuota cloud',
        expectedLatencyMs: 10,
      );
    }

    // High-speed tasks with moderate complexity -> Tier 2 Local SLM
    if ((context.taskType == AiTaskType.financeExpense ||
            context.taskType == AiTaskType.taskExtraction) &&
        complexity != AiQueryComplexity.high) {
      return const AiRoutingDecision(
        chosenTier: AiTier.tier2LocalSlm,
        reason:
            'Tugas operasional cepat (Finansial/Tugas): Tier 2 Local SLM (~200ms) untuk menghemat kuota cloud',
        expectedLatencyMs: 200,
      );
    }

    // Complex reasoning, openChat, or deep briefing -> Tier 3 Cloud
    if (complexity == AiQueryComplexity.high ||
        context.taskType == AiTaskType.openChat ||
        context.taskType == AiTaskType.meetingBriefing) {
      return const AiRoutingDecision(
        chosenTier: AiTier.tier3CloudSamudra,
        reason:
            'Penalaran kompleks / obrolan bebas: Tier 3 Cloud Samudra AI (~1200ms)',
        expectedLatencyMs: 1200,
      );
    }

    // Default fallback tier for medium complexity
    return const AiRoutingDecision(
      chosenTier: AiTier.tier2LocalSlm,
      reason: 'Kueri tingkat menengah dialihkan ke Tier 2 Local SLM',
      expectedLatencyMs: 200,
    );
  }

  // ===========================================================================
  // FALLBACK ORCHESTRATOR
  // ===========================================================================

  /// Executes the query according to the chosen tier with automatic multi-tier fallback.
  ///
  /// Fallback Sequence:
  /// - Tier 3 Cloud error/timeout/quota -> Auto-fallback to Tier 2 (Local SLM).
  /// - Tier 2 Local SLM error -> Auto-fallback to Tier 1 (Heuristik).
  /// - Guaranteed non-crashing execution for the UI.
  Future<AiExecutionResult> executeWithFallback(AiQueryContext context) async {
    final decision = determineRoutingTier(context);
    final stopwatch = Stopwatch()..start();

    switch (decision.chosenTier) {
      case AiTier.tier3CloudSamudra:
        return _orchestrateFromTier3(context, stopwatch);
      case AiTier.tier2LocalSlm:
        return _orchestrateFromTier2(
          context,
          stopwatch,
          originallyCloud: false,
        );
      case AiTier.tier1Heuristic:
        return _orchestrateFromTier1(
          context,
          stopwatch,
          originallyHigherTier: false,
        );
    }
  }

  /// Attempts Tier 3 Cloud; if fails, cascades to Tier 2, then Tier 1.
  Future<AiExecutionResult> _orchestrateFromTier3(
    AiQueryContext context,
    Stopwatch stopwatch,
  ) async {
    try {
      final output = await _runCloud(context);
      stopwatch.stop();
      _recordSuccess(tier: AiTier.tier3CloudSamudra, isFallback: false);
      return AiExecutionResult(
        text: output.text,
        usedTier: AiTier.tier3CloudSamudra,
        isFallback: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        rawData: output.rawData,
      );
    } catch (_) {
      // Tier 3 Cloud failed (timeout, quota, or network exception).
      // Fallback to Tier 2 Local SLM.
      return _orchestrateFromTier2(context, stopwatch, originallyCloud: true);
    }
  }

  /// Attempts Tier 2 Local SLM; if fails, cascades to Tier 1.
  Future<AiExecutionResult> _orchestrateFromTier2(
    AiQueryContext context,
    Stopwatch stopwatch, {
    required bool originallyCloud,
  }) async {
    try {
      final output = await _runLocalSlm(context);
      stopwatch.stop();
      _recordSuccess(tier: AiTier.tier2LocalSlm, isFallback: originallyCloud);
      return AiExecutionResult(
        text: output.text,
        usedTier: AiTier.tier2LocalSlm,
        isFallback: originallyCloud,
        latencyMs: stopwatch.elapsedMilliseconds,
        rawData: output.rawData,
      );
    } catch (_) {
      // Tier 2 Local SLM failed. Fallback to Tier 1 Heuristics.
      return _orchestrateFromTier1(context, stopwatch, originallyHigherTier: true);
    }
  }

  /// Attempts Tier 1 Heuristic parser; if fails, returns graceful safe response.
  Future<AiExecutionResult> _orchestrateFromTier1(
    AiQueryContext context,
    Stopwatch stopwatch, {
    required bool originallyHigherTier,
  }) async {
    try {
      final output = await _runHeuristic(context);
      stopwatch.stop();
      _recordSuccess(
        tier: AiTier.tier1Heuristic,
        isFallback: originallyHigherTier,
      );
      return AiExecutionResult(
        text: output.text,
        usedTier: AiTier.tier1Heuristic,
        isFallback: originallyHigherTier,
        latencyMs: stopwatch.elapsedMilliseconds,
        rawData: output.rawData,
      );
    } catch (_) {
      // All higher tiers and heuristic parser failed: safe fallback to prevent UI crash.
      stopwatch.stop();
      _recordSuccess(
        tier: AiTier.tier1Heuristic,
        isFallback: true,
      );
      return AiExecutionResult(
        text: _buildSafeFallbackMessage(context),
        usedTier: AiTier.tier1Heuristic,
        isFallback: true,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  void _recordSuccess({required AiTier tier, required bool isFallback}) {
    _stats = _stats.copyWith(
      totalRequests: _stats.totalRequests + 1,
      tier1Hits: _stats.tier1Hits + (tier == AiTier.tier1Heuristic ? 1 : 0),
      tier2Hits: _stats.tier2Hits + (tier == AiTier.tier2LocalSlm ? 1 : 0),
      tier3Hits: _stats.tier3Hits + (tier == AiTier.tier3CloudSamudra ? 1 : 0),
      fallbackCount: _stats.fallbackCount + (isFallback ? 1 : 0),
    );
    onStatsChanged?.call(_stats);
  }

  // ===========================================================================
  // TIER EXECUTION RUNNERS
  // ===========================================================================

  Future<AiTierOutput> _runCloud(AiQueryContext context) async {
    if (cloudHandler != null) {
      return await cloudHandler!(context);
    }

    if (cloudClient != null) {
      final response = await cloudClient!.chat(
        messages: [AiMessage(role: 'user', content: context.text)],
      );
      return AiTierOutput(
        text: response.content,
        rawData: {
          'model': response.usedModel,
          'didFallback': response.didFallback,
        },
      );
    }

    // Default simulated cloud response when no client/handler provided
    return AiTierOutput(
      text: '[Cloud Samudra AI] Berhasil memproses: "${context.text}"',
      rawData: {'provider': 'SamudraCloud'},
    );
  }

  Future<AiTierOutput> _runLocalSlm(AiQueryContext context) async {
    if (localSlmHandler != null) {
      return await localSlmHandler!(context);
    }

    // Built-in lightweight local SLM inference simulation
    final text = context.text.trim();
    switch (context.taskType) {
      case AiTaskType.financeExpense:
        final parsed = _parseExpenseHeuristic(text);
        if (parsed != null) {
          return AiTierOutput(
            text:
                '[Local SLM] Transaksi dicatat: ${parsed['item']} (Rp ${parsed['amount']})',
            rawData: parsed,
          );
        }
        return AiTierOutput(
          text: '[Local SLM] Dicatat transaksi keuangan: "$text"',
          rawData: {'raw': text, 'type': 'expense'},
        );

      case AiTaskType.taskExtraction:
        return AiTierOutput(
          text: '[Local SLM] Tugas berhasil dibuat: "$text"',
          rawData: {'title': text, 'type': 'task'},
        );

      case AiTaskType.noteSummarization:
        return AiTierOutput(
          text: '[Local SLM Ringkasan]: $text',
          rawData: {'summary': text},
        );

      case AiTaskType.meetingBriefing:
        return AiTierOutput(
          text: '[Local SLM Notulensi]: Poin penting dari rapat: $text',
          rawData: {'briefing': text},
        );

      case AiTaskType.openChat:
        return AiTierOutput(
          text:
              '[Local SLM] Halo! Saya memproses permintaan Anda secara lokal: "$text"',
        );
    }
  }

  Future<AiTierOutput> _runHeuristic(AiQueryContext context) async {
    if (heuristicHandler != null) {
      return await heuristicHandler!(context);
    }

    final text = context.text.trim();
    switch (context.taskType) {
      case AiTaskType.financeExpense:
        final expense = _parseExpenseHeuristic(text);
        if (expense != null) {
          final amount = expense['amount'] as int;
          final item = expense['item'] as String;
          final category = expense['category'] as String;
          return AiTierOutput(
            text:
                'Pengeluaran Rp $amount untuk "$item" ($category) berhasil dicatat.',
            rawData: expense,
          );
        }
        throw FormatException('Tidak dapat mencocokkan pola pengeluaran: $text');

      case AiTaskType.taskExtraction:
        final match = _taskPattern.firstMatch(text);
        final title = (match != null ? match.group(1) : text)?.trim() ?? text;
        return AiTierOutput(
          text: 'Tugas berhasil dibuat: "$title"',
          rawData: {'title': title, 'type': 'task'},
        );

      case AiTaskType.openChat:
        final response = _resolveGreeting(text);
        return AiTierOutput(text: response);

      case AiTaskType.noteSummarization:
      case AiTaskType.meetingBriefing:
        return AiTierOutput(
          text: 'Ringkasan Cepat: $text',
          rawData: {'summary': text},
        );
    }
  }

  Map<String, dynamic>? _parseExpenseHeuristic(String text) {
    Match? match = _expensePattern1.firstMatch(text);
    String? item;
    String? rawAmount;
    String? unit;

    if (match != null) {
      item = match.group(1)?.trim();
      rawAmount = match.group(2);
      unit = match.group(3);
    } else {
      match = _expensePattern2.firstMatch(text);
      if (match != null) {
        rawAmount = match.group(1);
        unit = match.group(2);
        item = match.group(3)?.trim();
      }
    }

    if (rawAmount == null) return null;

    final cleanedNum = rawAmount.replaceAll('.', '').replaceAll(',', '.');
    final baseNumber = double.tryParse(cleanedNum);
    if (baseNumber == null) return null;

    int amount;
    final lowerUnit = unit?.toLowerCase();
    if (lowerUnit == 'rb' || lowerUnit == 'k' || lowerUnit == 'ribu') {
      amount = (baseNumber * 1000).round();
    } else if (lowerUnit == 'jt' || lowerUnit == 'juta') {
      amount = (baseNumber * 1000000).round();
    } else {
      amount = baseNumber.round();
    }

    final cleanItem = item ?? 'Pengeluaran';
    final category = _inferCategory(cleanItem);

    return {
      'amount': amount,
      'item': cleanItem,
      'category': category,
      'type': 'expense',
    };
  }

  String _inferCategory(String item) {
    final lower = item.toLowerCase();
    if (lower.contains('kopi') ||
        lower.contains('makan') ||
        lower.contains('minum') ||
        lower.contains('nasi') ||
        lower.contains('bakso') ||
        lower.contains('ayam') ||
        lower.contains('snack') ||
        lower.contains('sarapan') ||
        lower.contains('dinner')) {
      return 'Makanan & Minuman';
    }
    if (lower.contains('bensin') ||
        lower.contains('pertamax') ||
        lower.contains('pertalite') ||
        lower.contains('ojol') ||
        lower.contains('gojek') ||
        lower.contains('grab') ||
        lower.contains('parkir') ||
        lower.contains('tol')) {
      return 'Transportasi';
    }
    if (lower.contains('wifi') ||
        lower.contains('indihome') ||
        lower.contains('listrik') ||
        lower.contains('pln') ||
        lower.contains('air') ||
        lower.contains('pulsa') ||
        lower.contains('kuota')) {
      return 'Tagihan';
    }
    if (lower.contains('baju') ||
        lower.contains('sepatu') ||
        lower.contains('tas') ||
        lower.contains('belanja')) {
      return 'Belanja';
    }
    return 'Lainnya';
  }

  String _resolveGreeting(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('siapa kamu')) {
      return 'Saya Personal Hub AI Assistant yang siap membantu Anda kapan pun, online maupun offline.';
    }
    if (lower.contains('apa kabar')) {
      return 'Kabar baik! Sistem AI Router aktif dan siap memproses perintah Anda.';
    }
    if (lower.contains('terima kasih') || lower.contains('makasih')) {
      return 'Sama-sama! Senang bisa membantu Anda.';
    }
    if (lower.contains('ping') || lower == 'p') {
      return 'Pong! Sistem AI responsif.';
    }
    return 'Halo! Ada yang bisa saya bantu hari ini?';
  }

  String _buildSafeFallbackMessage(AiQueryContext context) {
    return 'Permintaan disimpan secara lokal. Mode darurat aktif untuk "${context.text}".';
  }
}
