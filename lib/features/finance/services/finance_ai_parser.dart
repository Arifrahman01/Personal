import 'dart:convert';

import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/finance/models/finance_models.dart';

/// Builds AI prompts and parses structured transaction drafts for personal finance.
abstract final class FinanceAiParser {
  static final RegExp _fencePattern = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  );

  /// Builds chat messages instructing the AI to extract transactions from [naturalInput].
  static List<AiMessage> buildParsePrompt(String naturalInput) {
    return [
      const AiMessage(
        role: 'system',
        content:
            'Kamu adalah asisten pencatat keuangan pribadi berbahasa Indonesia. '
            'Ekstrak transaksi dari teks pengguna dan balas HANYA dengan JSON array valid tanpa penjelasan tambahan. '
            'Setiap elemen harus berupa objek dengan field: '
            '"type" ("expense" atau "income"), '
            '"amount" (bilangan bulat positif dalam Rupiah), '
            '"category" (kategori singkat dalam Bahasa Indonesia seperti Makanan, Transportasi, Belanja, Tagihan, Hiburan, Kesehatan, Gaji, Bonus, Lainnya), '
            'dan "note" (catatan singkat).',
      ),
      AiMessage(
        role: 'user',
        content:
            'Contoh:\n'
            'Input: "makan siang 35rb, bensin 50rb"\n'
            'Output: [{"type":"expense","amount":35000,"category":"Makanan","note":"Makan siang"},{"type":"expense","amount":50000,"category":"Transportasi","note":"Bensin"}]\n\n'
            'Input pengguna:\n$naturalInput',
      ),
    ];
  }

  /// Parses raw AI output into valid positive [ParsedFinanceDraft] entries.
  static List<ParsedFinanceDraft> parseResponse(String rawContent) {
    final decoded = _decodeJsonPayload(rawContent);
    if (decoded == null) {
      return const [];
    }

    final List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final nested = decoded['transactions'] ?? decoded['items'];
      items = nested is List ? nested : [decoded];
    } else {
      return const [];
    }

    final drafts = <ParsedFinanceDraft>[];
    for (final item in items) {
      if (item is! Map) continue;
      final draft = _parseSingleEntry(item);
      if (draft != null) {
        drafts.add(draft);
      }
    }
    return drafts;
  }

  /// Builds chat messages asking the AI for a Bahasa Indonesia insight on [summary].
  static List<AiMessage> buildMonthlyInsightPrompt(
    MonthlySummary summary,
    int year,
    int month,
  ) {
    final monthLabel = '${FinanceMonth.monthName(month)} $year'.trim();
    final categoryLines = summary.expenseByCategory.isEmpty
        ? '- Belum ada pengeluaran tercatat'
        : summary.expenseByCategory.entries
              .map((entry) => '- ${entry.key}: Rp ${entry.value}')
              .join('\n');

    return [
      const AiMessage(
        role: 'system',
        content:
            'Kamu adalah penasihat keuangan pribadi yang praktis dan suportif. '
            'Berikan analisa ringkas dalam Bahasa Indonesia dengan poin jelas dan saran penghematan yang realistis.',
      ),
      AiMessage(
        role: 'user',
        content:
            'Analisa arus kas bulan $monthLabel:\n'
            '- Total Pemasukan: ${summary.totalIncome} (${formatRupiah(summary.totalIncome)})\n'
            '- Total Pengeluaran: ${summary.totalExpense} (${formatRupiah(summary.totalExpense)})\n'
            '- Saldo Bersih: ${summary.netBalance} (${formatRupiah(summary.netBalance)})\n'
            'Pengeluaran per kategori:\n'
            '$categoryLines\n\n'
            'Berikan evaluasi singkat kondisi keuangan bulan ini dan 2-3 saran langkah berikutnya.',
      ),
    ];
  }

  static dynamic _decodeJsonPayload(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return null;

    final candidates = <String>[];

    final fenceMatch = _fencePattern.firstMatch(trimmed);
    if (fenceMatch != null) {
      final fenced = fenceMatch.group(1)?.trim();
      if (fenced != null && fenced.isNotEmpty) {
        candidates.add(fenced);
      }
    }

    candidates.add(trimmed);

    final arrayStart = trimmed.indexOf('[');
    final arrayEnd = trimmed.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd > arrayStart) {
      candidates.add(trimmed.substring(arrayStart, arrayEnd + 1));
    }

    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static ParsedFinanceDraft? _parseSingleEntry(Map<dynamic, dynamic> rawMap) {
    final amount = _parseAmount(rawMap['amount']);
    if (amount == null || amount <= 0) {
      return null;
    }

    final rawCategory = rawMap['category'];
    if (rawCategory is! String || rawCategory.trim().isEmpty) {
      return null;
    }

    final type = _parseTransactionType(rawMap['type']);
    if (type == null) {
      return null;
    }

    final rawNote = rawMap['note'];
    final note = rawNote is String ? rawNote.trim() : '';

    return ParsedFinanceDraft(
      type: type,
      amount: amount,
      category: rawCategory.trim(),
      note: note,
    );
  }

  static TransactionType? _parseTransactionType(dynamic rawType) {
    if (rawType == null) {
      return TransactionType.expense;
    }
    if (rawType is! String) {
      return null;
    }
    switch (rawType.trim().toLowerCase()) {
      case 'income':
      case 'pemasukan':
      case 'masuk':
        return TransactionType.income;
      case 'expense':
      case 'pengeluaran':
      case 'keluar':
        return TransactionType.expense;
      default:
        return null;
    }
  }

  static int? _parseAmount(dynamic rawAmount) {
    if (rawAmount is int) {
      return rawAmount > 0 ? rawAmount : null;
    }
    if (rawAmount is num) {
      final rounded = rawAmount.round();
      return rounded > 0 ? rounded : null;
    }
    if (rawAmount is! String) {
      return null;
    }

    var text = rawAmount.trim().toLowerCase();
    if (text.isEmpty) return null;

    text = text
        .replaceAll(RegExp(r'\b(rp\.?|idr)\b'), '')
        .replaceAll('rp', '')
        .replaceAll(RegExp(r'\s+'), '');

    if (text.isEmpty) return null;

    var multiplier = 1;
    final suffixMatch = RegExp(r'(juta|jt|m|ribu|rb|k)$').firstMatch(text);
    if (suffixMatch != null) {
      final suffix = suffixMatch.group(1)!;
      text = text.substring(0, suffixMatch.start);
      if (suffix == 'juta' || suffix == 'jt' || suffix == 'm') {
        multiplier = 1000000;
      } else {
        multiplier = 1000;
      }
    }

    if (text.isEmpty) return null;

    if (multiplier > 1) {
      final normalized = _normalizeDecimalNumber(text);
      final value = double.tryParse(normalized);
      if (value == null || !value.isFinite) return null;
      final total = (value * multiplier).round();
      return total > 0 ? total : null;
    }

    final normalizedInt = _normalizePlainNumber(text);
    final parsed = num.tryParse(normalizedInt)?.round();
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static String _normalizeDecimalNumber(String text) {
    if (text.contains('.') && text.contains(',')) {
      return text.replaceAll('.', '').replaceAll(',', '.');
    }
    if (text.contains(',')) {
      return text.replaceAll(',', '.');
    }
    return text;
  }

  static String _normalizePlainNumber(String text) {
    if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(text)) {
      return text.replaceAll('.', '');
    }
    if (RegExp(r'^-?\d{1,3}(,\d{3})+$').hasMatch(text)) {
      return text.replaceAll(',', '');
    }
    return text.replaceAll(',', '');
  }
}
