import 'package:personal_hub/features/finance/models/finance_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';

/// Unsaved finance transaction draft parsed from quick input.
class QuickFinanceDraft {
  const QuickFinanceDraft({
    this.type = TransactionType.expense,
    required this.amount,
    required this.category,
    required this.description,
  });

  final TransactionType type;
  final int amount;
  final String category;
  final String description;

  QuickFinanceDraft copyWith({
    TransactionType? type,
    int? amount,
    String? category,
    String? description,
  }) {
    return QuickFinanceDraft(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'amount': amount,
    'category': category,
    'description': description,
  };

  factory QuickFinanceDraft.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? 'expense';
    final parsedType =
        rawType == TransactionType.income.name
            ? TransactionType.income
            : TransactionType.expense;
    return QuickFinanceDraft(
      type: parsedType,
      amount: (map['amount'] as num).toInt(),
      category: map['category'] as String? ?? 'Lainnya',
      description: map['description'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickFinanceDraft &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          amount == other.amount &&
          category == other.category &&
          description == other.description;

  @override
  int get hashCode => Object.hash(type, amount, category, description);

  @override
  String toString() =>
      'QuickFinanceDraft(type: ${type.name}, amount: $amount, category: "$category", description: "$description")';
}

/// Unsaved task draft parsed from quick input.
class QuickTaskDraft {
  const QuickTaskDraft({
    required this.title,
    this.dueDate,
    this.priority = TaskPriority.medium,
  });

  final String title;
  final DateTime? dueDate;
  final TaskPriority priority;

  QuickTaskDraft copyWith({
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
  }) {
    return QuickTaskDraft(
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'due_date': dueDate?.toIso8601String(),
    'priority': priority.name,
  };

  factory QuickTaskDraft.fromMap(Map<String, dynamic> map) {
    final rawDate = map['due_date'] as String?;
    return QuickTaskDraft(
      title: map['title'] as String? ?? '',
      dueDate: rawDate != null ? DateTime.tryParse(rawDate) : null,
      priority: TaskPriority.fromName(map['priority'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickTaskDraft &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          dueDate == other.dueDate &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(title, dueDate, priority);

  @override
  String toString() =>
      'QuickTaskDraft(title: "$title", dueDate: $dueDate, priority: ${priority.name})';
}

/// Unsaved note draft parsed from quick input.
class QuickNoteDraft {
  const QuickNoteDraft({
    required this.title,
    required this.content,
    this.tags = const [],
  });

  final String title;
  final String content;
  final List<String> tags;

  QuickNoteDraft copyWith({
    String? title,
    String? content,
    List<String>? tags,
  }) {
    return QuickNoteDraft(
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'tags': tags,
  };

  factory QuickNoteDraft.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    final parsedTags =
        rawTags is List
            ? rawTags.map((e) => e.toString()).toList()
            : const <String>[];
    return QuickNoteDraft(
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      tags: parsedTags,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuickNoteDraft || runtimeType != other.runtimeType) {
      return false;
    }
    if (title != other.title || content != other.content) return false;
    if (tags.length != other.tags.length) return false;
    for (var i = 0; i < tags.length; i++) {
      if (tags[i] != other.tags[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(title, content, Object.hashAll(tags));

  @override
  String toString() =>
      'QuickNoteDraft(title: "$title", content: "$content", tags: $tags)';
}

/// Container batch collecting parsed items across Finance, Tasks, and Notes.
class QuickCaptureBatch {
  const QuickCaptureBatch({
    this.financeDrafts = const [],
    this.taskDrafts = const [],
    this.noteDrafts = const [],
  });

  final List<QuickFinanceDraft> financeDrafts;
  final List<QuickTaskDraft> taskDrafts;
  final List<QuickNoteDraft> noteDrafts;

  bool get isEmpty =>
      financeDrafts.isEmpty && taskDrafts.isEmpty && noteDrafts.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalCount =>
      financeDrafts.length + taskDrafts.length + noteDrafts.length;

  QuickCaptureBatch copyWith({
    List<QuickFinanceDraft>? financeDrafts,
    List<QuickTaskDraft>? taskDrafts,
    List<QuickNoteDraft>? noteDrafts,
  }) {
    return QuickCaptureBatch(
      financeDrafts: financeDrafts ?? this.financeDrafts,
      taskDrafts: taskDrafts ?? this.taskDrafts,
      noteDrafts: noteDrafts ?? this.noteDrafts,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuickCaptureBatch || runtimeType != other.runtimeType) {
      return false;
    }
    if (financeDrafts.length != other.financeDrafts.length ||
        taskDrafts.length != other.taskDrafts.length ||
        noteDrafts.length != other.noteDrafts.length) {
      return false;
    }
    for (var i = 0; i < financeDrafts.length; i++) {
      if (financeDrafts[i] != other.financeDrafts[i]) return false;
    }
    for (var i = 0; i < taskDrafts.length; i++) {
      if (taskDrafts[i] != other.taskDrafts[i]) return false;
    }
    for (var i = 0; i < noteDrafts.length; i++) {
      if (noteDrafts[i] != other.noteDrafts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(financeDrafts),
    Object.hashAll(taskDrafts),
    Object.hashAll(noteDrafts),
  );

  @override
  String toString() =>
      'QuickCaptureBatch(finance: ${financeDrafts.length}, tasks: ${taskDrafts.length}, notes: ${noteDrafts.length})';
}

/// Multi-intent parser for Indonesian speech-to-text and quick input.
class UniversalQuickCaptureService {
  const UniversalQuickCaptureService({DateTime Function()? clock})
    : _clock = clock ?? _defaultClock;

  final DateTime Function() _clock;

  static DateTime _defaultClock() => DateTime.now();

  /// Parses multi-intent natural language text into a [QuickCaptureBatch].
  QuickCaptureBatch parseMultiIntent(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const QuickCaptureBatch();
    }

    final segments = _splitSegments(normalized);
    final financeDrafts = <QuickFinanceDraft>[];
    final taskDrafts = <QuickTaskDraft>[];
    final noteDrafts = <QuickNoteDraft>[];

    for (final rawSegment in segments) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) continue;

      final classification = _classifySegment(segment);
      switch (classification) {
        case _IntentType.finance:
          final draft = _parseFinance(segment);
          if (draft != null) {
            financeDrafts.add(draft);
          }
          break;
        case _IntentType.task:
          final draft = _parseTask(segment);
          if (draft != null) {
            taskDrafts.add(draft);
          }
          break;
        case _IntentType.note:
          final draft = _parseNote(segment);
          if (draft != null) {
            noteDrafts.add(draft);
          }
          break;
      }
    }

    return QuickCaptureBatch(
      financeDrafts: List.unmodifiable(financeDrafts),
      taskDrafts: List.unmodifiable(taskDrafts),
      noteDrafts: List.unmodifiable(noteDrafts),
    );
  }

  /// Splits multi-intent text across newlines, punctuation, conjunctions, and voice transitions.
  List<String> _splitSegments(String input) {
    var working = input;

    // 1. Split across newlines and semicolons
    working = working.replaceAll(RegExp(r'[\r\n;]+'), '\u0000');

    // 2. Split across non-decimal commas (e.g. "beli makan, besok...") but not "1,5jt"
    working = working.replaceAll(RegExp(r'(?<!\d),(?!\d)'), '\u0000');
    // Also split commas followed by whitespace: "50rb, besok"
    working = working.replaceAll(RegExp(r',\s+'), '\u0000');

    // 3. Conjunction words that typically start a next action ("terus", "lalu", "kemudian", "habis itu", "setelah itu")
    working = working.replaceAll(
      RegExp(
        r'\b(?:terus|lalu|kemudian|habis itu|setelah itu)\b',
        caseSensitive: false,
      ),
      '\u0000',
    );

    // 4. "dan" or "sama" followed by an intent trigger
    working = working.replaceAll(
      RegExp(
        r'\b(?:dan|sama)\s+(?=(?:beli|bayar|jajan|transfer|bensin|gaji|kerjakan|kirim|meeting|rapat|buat|bikin|review|siapkan|ingatkan|jangan lupa|besok|lusa|ide|catat|catatan)\b)',
        caseSensitive: false,
      ),
      '\u0000',
    );

    // 5. Unpunctuated speech transitions:
    // e.g. amount followed by "besok", "lusa", "kerjakan", "kirim", "meeting", "ide", "catat"
    working = working.replaceAllMapped(
      RegExp(
        r'(\b\d+(?:[.,]\d+)?\s*(?:k|rb|ribu|jt|juta|m|miliar)?|\b\d{4,})\s+(?=(?:besok|lusa|kerjakan|kirim|meeting|rapat|buat|bikin|review|ide|catat|catatan|beli|bayar)\b)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}\u0000',
    );

    // 6. Transition before "ide" or "catat" if preceded by completed task phrase
    working = working.replaceAllMapped(
      RegExp(
        r'(\b(?:klien|kantor|bos|teman|sekolah|kampus|selesai|laporan|proposal|besok|hari ini))\s+(?=(?:ide\s+|catat\s+|catatan\s+))',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}\u0000',
    );

    return working
        .split('\u0000')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Classifies a segment into Finance, Task, or Note intent.
  _IntentType _classifySegment(String segment) {
    final lower = segment.toLowerCase();

    // Check for Note triggers early if it explicitly begins with note markers
    if (lower.startsWith('ide ') ||
        lower.startsWith('catatan ') ||
        lower.startsWith('catat ') ||
        lower.startsWith('note ') ||
        lower.startsWith('notes ') ||
        lower.startsWith('memo ') ||
        lower.startsWith('#')) {
      // Check if it's actually a task action despite starting with note, e.g. "catat jam meeting besok"
      final hasAmount = _extractAmount(segment) != null;
      if (!hasAmount) {
        return _IntentType.note;
      }
    }

    // 1. Finance: Check for monetary amount with finance context
    final amount = _extractAmount(segment);
    if (amount != null && amount > 0) {
      return _IntentType.finance;
    }

    // Strip hashtags before checking for task action verbs so #review isn't matched as a task
    final textWithoutHashtags = lower.replaceAll(RegExp(r'#[a-zA-Z0-9_\-]+'), '');

    // 2. Task: Action verbs or date/timing triggers
    final hasTaskAction = RegExp(
      r'\b(kerjakan|selesaikan|buat|bikin|kirim|email|meeting|rapat|hubungi|telepon|call|jadwalkan|follow up|followup|review|cek|periksa|siapkan|baca|pelajari|ingatkan|jangan lupa|pr|tugas|todo|agenda|diskusi|presentasi|laporan|proposal|submit|upload|download|urus|bereskan|beresin|ambil|antar|jemput|deadline)\b',
      caseSensitive: false,
    ).hasMatch(textWithoutHashtags);

    final hasDateOrTime = RegExp(
      r'\b(besok|lusa|nanti sore|nanti malam|hari ini|jam\s*\d|pukul\s*\d|senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b',
      caseSensitive: false,
    ).hasMatch(textWithoutHashtags);

    if (hasTaskAction || hasDateOrTime) {
      return _IntentType.task;
    }

    // 3. Fallback: Remaining thoughts or idea notes
    return _IntentType.note;
  }

  /// Parses a finance segment into [QuickFinanceDraft].
  QuickFinanceDraft? _parseFinance(String segment) {
    final amountResult = _extractAmountWithRange(segment);
    if (amountResult == null || amountResult.amount <= 0) {
      return null;
    }

    final lower = segment.toLowerCase();

    // Determine TransactionType
    final isIncome = RegExp(
      r'\b(gaji|payroll|bonus|thr|pendapatan|pemasukan|terima uang|uang masuk|transfer masuk|cair|jual|penjualan|dividen)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final type =
        isIncome ? TransactionType.income : TransactionType.expense;

    // Determine Category
    final category = _detectFinanceCategory(lower, type);

    // Build Description
    final description = _cleanFinanceDescription(
      segment,
      amountResult.startIndex,
      amountResult.endIndex,
      category,
    );

    return QuickFinanceDraft(
      type: type,
      amount: amountResult.amount,
      category: category,
      description: description,
    );
  }

  /// Extracts category for finance items with high specificity.
  String _detectFinanceCategory(String lower, TransactionType type) {
    if (type == TransactionType.income) {
      if (lower.contains('gaji') || lower.contains('payroll')) return 'Gaji';
      if (lower.contains('bonus') || lower.contains('thr')) return 'Bonus';
      if (lower.contains('investasi') ||
          lower.contains('dividen') ||
          lower.contains('crypto') ||
          lower.contains('saham')) {
        return 'Investasi';
      }
      return 'Pendapatan';
    }

    // Specific expense categories
    if (RegExp(
      r'\b(makan|sarapan|lunch|dinner|siang|jajan|minum|kopi|kafe|cafe|resto|restoran|warteg|bakso|nasi|sate|mie|ayam|snack|gofood|grabfood|shopeefood)\b',
    ).hasMatch(lower)) {
      return 'Makanan';
    }

    if (RegExp(
      r'\b(bensin|bbm|pertalite|pertamax|solar|parkir|tol|grab|gojek|goride|gocar|maxim|ojek|kereta|krl|mrt|lrt|bus|busway|transjakarta|tiket|servis|service)\b',
    ).hasMatch(lower)) {
      return 'Transportasi';
    }

    if (RegExp(
      r'\b(listrik|pln|token|pdam|air|wifi|indihome|biznet|internet|pulsa|kuota|paket data|bpjs|pbb|sewa|kontrakan|kos|kost|cicilan|tagihan|iuran)\b',
    ).hasMatch(lower)) {
      return 'Tagihan';
    }

    if (RegExp(
      r'\b(obat|apotek|apotik|dokter|rumah sakit|rs|vitamin|klinik|medis|lab|gigi)\b',
    ).hasMatch(lower)) {
      return 'Kesehatan';
    }

    if (RegExp(
      r'\b(nonton|bioskop|film|cinema|xxi|game|steam|netflix|spotify|youtube|karaoke|liburan|wisata)\b',
    ).hasMatch(lower)) {
      return 'Hiburan';
    }

    if (RegExp(
      r'\b(buku|kursus|les|kuliah|spp|sekolah|semester|seminar|webinar)\b',
    ).hasMatch(lower)) {
      return 'Pendidikan';
    }

    if (RegExp(
      r'\b(belanja|baju|celana|pakaian|sepatu|tas|indomaret|alfamart|supermarket|pasar|mall|shopee|tokped|tokopedia|lazada|minimarket|beli)\b',
    ).hasMatch(lower)) {
      return 'Belanja';
    }

    return 'Lainnya';
  }

  /// Cleans the finance description by removing the amount substring and punctuation.
  String _cleanFinanceDescription(
    String segment,
    int amountStart,
    int amountEnd,
    String categoryFallback,
  ) {
    final before = segment.substring(0, amountStart);
    final after = segment.substring(amountEnd);
    var cleaned = '$before $after'
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.;:-]+|[\s,.;:-]+$'), '')
        .trim();

    if (cleaned.isEmpty) {
      cleaned = categoryFallback;
    } else {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
  }

  /// Parses an amount value from string, returning null if no amount is found.
  int? _extractAmount(String text) {
    return _extractAmountWithRange(text)?.amount;
  }

  /// Extracts amount with start and end index for description cleaning.
  _AmountMatch? _extractAmountWithRange(String text) {
    final lower = text.toLowerCase();

    // 1. Suffixes: 35rb, 50k, 2jt, 1.5jt, 100 ribu
    final suffixRegex = RegExp(
      r'(?:rp\.?\s*)?(\d+(?:[.,]\d+)?)\s*(k|rb|ribu|jt|juta|m|miliar|milyar)\b',
      caseSensitive: false,
    );
    final suffixMatch = suffixRegex.firstMatch(lower);
    if (suffixMatch != null) {
      final numStr = suffixMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) {
        final unit = suffixMatch.group(2)!.toLowerCase();
        int multiplier = 1;
        if (unit == 'k' || unit == 'rb' || unit == 'ribu') {
          multiplier = 1000;
        } else if (unit == 'jt' || unit == 'juta') {
          multiplier = 1000000;
        } else if (unit == 'm' || unit == 'miliar' || unit == 'milyar') {
          multiplier = 1000000000;
        }
        final finalAmount = (val * multiplier).round();
        return _AmountMatch(
          amount: finalAmount,
          startIndex: suffixMatch.start,
          endIndex: suffixMatch.end,
        );
      }
    }

    // 2. Explicit Rp prefix: "Rp 150.000", "Rp 50000"
    final rpRegex = RegExp(
      r'(?:rp\.?\s*)(\d{1,3}(?:\.\d{3})+|\d+)\b',
      caseSensitive: false,
    );
    final rpMatch = rpRegex.firstMatch(lower);
    if (rpMatch != null) {
      final rawDigits = rpMatch.group(1)!.replaceAll('.', '');
      final val = int.tryParse(rawDigits);
      if (val != null && val > 0) {
        return _AmountMatch(
          amount: val,
          startIndex: rpMatch.start,
          endIndex: rpMatch.end,
        );
      }
    }

    // 3. Formatted thousands: e.g. "150.000"
    final formattedRegex = RegExp(r'\b(\d{1,3}(?:\.\d{3})+)\b');
    final formattedMatch = formattedRegex.firstMatch(lower);
    if (formattedMatch != null) {
      // Check if preceded by jam or pukul
      final prefix = lower.substring(0, formattedMatch.start);
      if (!RegExp(r'\b(?:jam|pukul|tahun|no|nomor)\s*$').hasMatch(prefix)) {
        final val = int.tryParse(formattedMatch.group(1)!.replaceAll('.', ''));
        if (val != null && val >= 1000) {
          return _AmountMatch(
            amount: val,
            startIndex: formattedMatch.start,
            endIndex: formattedMatch.end,
          );
        }
      }
    }

    // 4. Standalone plain integer with 4+ digits (e.g. "150000", "35000")
    final plainRegex = RegExp(r'\b(\d{4,})\b');
    final plainMatch = plainRegex.firstMatch(lower);
    if (plainMatch != null) {
      final prefix = lower.substring(0, plainMatch.start);
      final suffix = lower.substring(plainMatch.end);

      final isTime = RegExp(r'\b(?:jam|pukul|tahun|no|nomor)\s*$').hasMatch(prefix);
      final isNonMonetaryUnit = RegExp(
        r'^\s*(?:kata|halaman|meter|km|orang|peserta|hari|jam|menit|detik|persen|%)\b',
      ).hasMatch(suffix);

      if (!isTime && !isNonMonetaryUnit) {
        final val = int.tryParse(plainMatch.group(1)!);
        if (val != null && val >= 1000) {
          return _AmountMatch(
            amount: val,
            startIndex: plainMatch.start,
            endIndex: plainMatch.end,
          );
        }
      }
    }

    return null;
  }

  /// Parses a task segment into [QuickTaskDraft].
  QuickTaskDraft? _parseTask(String segment) {
    final lower = segment.toLowerCase();
    final now = _clock();

    // 1. Detect DueDate
    final dueDate = _detectTaskDueDate(lower, now);

    // 2. Detect Priority
    final priority = _detectTaskPriority(lower);

    // 3. Clean Title
    final title = _cleanTaskTitle(segment);

    return QuickTaskDraft(
      title: title,
      dueDate: dueDate,
      priority: priority,
    );
  }

  /// Detects due date and optional time from Indonesian text.
  DateTime? _detectTaskDueDate(String lower, DateTime now) {
    DateTime? targetDate;

    if (lower.contains('besok')) {
      targetDate = DateTime(now.year, now.month, now.day + 1);
    } else if (lower.contains('lusa')) {
      targetDate = DateTime(now.year, now.month, now.day + 2);
    } else if (lower.contains('hari ini') ||
        lower.contains('nanti sore') ||
        lower.contains('nanti malam')) {
      targetDate = DateTime(now.year, now.month, now.day);
    } else {
      // Weekdays: senin..minggu
      final weekdayMap = {
        'senin': 1,
        'selasa': 2,
        'rabu': 3,
        'kamis': 4,
        'jumat': 5,
        "jum'at": 5,
        'sabtu': 6,
        'minggu': 7,
        'ahad': 7,
      };

      for (final entry in weekdayMap.entries) {
        if (RegExp(r'\b' + entry.key + r'\b').hasMatch(lower)) {
          final targetWeekday = entry.value;
          var daysToAdd = targetWeekday - now.weekday;
          if (daysToAdd <= 0) {
            daysToAdd += 7;
          }
          targetDate = DateTime(now.year, now.month, now.day + daysToAdd);
          break;
        }
      }
    }

    // Time detection: "jam 10", "jam 10:30", "jam 10.30", "pukul 15:00"
    final timeMatch = RegExp(
      r'\b(?:jam|pukul)\s*(\d{1,2})(?:[:.](\d{2}))?',
      caseSensitive: false,
    ).firstMatch(lower);

    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute =
          timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;

      // Check context qualifiers
      if (lower.contains('malam') && hour < 12) {
        hour += 12;
      } else if (lower.contains('sore') && hour < 12 && hour >= 1) {
        hour += 12;
      } else if (lower.contains('siang') &&
          hour < 12 &&
          hour >= 1 &&
          hour <= 4) {
        hour += 12;
      }

      if (targetDate != null) {
        return DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );
      } else {
        // Time provided without specific day
        final todayCandidate = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        return todayCandidate.isAfter(now)
            ? todayCandidate
            : DateTime(now.year, now.month, now.day + 1, hour, minute);
      }
    }

    if (targetDate != null) {
      // Default to 09:00 AM on the target date
      return DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
    }

    return null;
  }

  /// Detects task priority.
  TaskPriority _detectTaskPriority(String lower) {
    if (RegExp(
      r'\b(urgent|segera|asap|penting|prioritas tinggi|darurat|wajib|secepatnya)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return TaskPriority.high;
    }
    if (RegExp(
      r'\b(santai|kapan-kapan|bila sempat|kalau sempat|prioritas rendah|low priority)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return TaskPriority.low;
    }
    return TaskPriority.medium;
  }

  /// Cleans task title removing date tokens, priority flags, and filler words.
  String _cleanTaskTitle(String segment) {
    var cleaned = segment;

    // Strip date and time markers
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:besok|lusa|hari ini|nanti sore|nanti malam)\b',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:jam|pukul)\s*\d{1,2}(?:[:.]\d{2})?(?:\s*(?:pagi|siang|sore|malam))?\b',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:senin|selasa|rabu|kamis|jumat|jum\x27at|sabtu|minggu|ahad)\b',
        caseSensitive: false,
      ),
      '',
    );

    // Strip priority words
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:urgent|segera|asap|penting|prioritas tinggi|prioritas rendah|santai|wajib)\b',
        caseSensitive: false,
      ),
      '',
    );

    // Strip common filler prefixes
    cleaned = cleaned.replaceAll(
      RegExp(
        r'^(?:ingatkan\s+(?:untuk\s+)?|jangan\s+lupa\s+(?:untuk\s+)?|tolong\s+|tugas:?\s+|todo:?\s+|agenda:?\s+)',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.;:-]+|[\s,.;:-]+$'), '')
        .trim();

    if (cleaned.length < 2) {
      cleaned = segment.trim();
    }

    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
  }

  /// Parses a note segment into [QuickNoteDraft].
  QuickNoteDraft? _parseNote(String segment) {
    final lower = segment.toLowerCase();

    // 1. Title and Content Extraction
    String title;
    String content;

    if (segment.contains(':')) {
      final parts = segment.split(':');
      title = parts[0].trim();
      content = parts.sublist(1).join(':').trim();
      if (content.isEmpty) {
        content = segment.trim();
      }
    } else {
      content = segment.trim();
      if (content.length <= 60) {
        title = content;
      } else {
        // Take up to 50 characters or first clause
        final firstClause = content.split(RegExp(r'[,.\n]')).first.trim();
        title = firstClause.length <= 50 ? firstClause : '${firstClause.substring(0, 47)}...';
      }
    }

    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    } else {
      title = 'Catatan';
    }

    // 2. Extract Tags
    final tags = _extractNoteTags(segment, lower);

    return QuickNoteDraft(
      title: title,
      content: content,
      tags: tags,
    );
  }

  /// Extracts hashtags and inferred keywords for note tags.
  List<String> _extractNoteTags(String segment, String lower) {
    final tags = <String>{};

    // Extract hashtags like #ai, #flutter
    final hashMatches = RegExp(r'#([a-zA-Z0-9_\-]+)').allMatches(segment);
    for (final match in hashMatches) {
      final tag = match.group(1)?.toLowerCase();
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }

    // Inferred topic tags
    if (lower.contains('ide') || lower.contains('idea')) {
      tags.add('ide');
    }
    if (lower.contains('riset') || lower.contains('penelitian')) {
      tags.add('riset');
    }
    if (RegExp(r'\b(ai|artificial intelligence|machine learning|llm)\b').hasMatch(lower)) {
      tags.add('ai');
    }
    if (lower.contains('skripsi') ||
        lower.contains('kuliah') ||
        lower.contains('kampus')) {
      tags.add('skripsi');
    }
    if (lower.contains('buku') || lower.contains('bacaan')) {
      tags.add('buku');
    }
    if (lower.contains('bisnis') || lower.contains('usaha')) {
      tags.add('bisnis');
    }
    if (lower.contains('catatan') || lower.contains('catat')) {
      tags.add('catatan');
    }

    return List.unmodifiable(tags.toList());
  }
}

enum _IntentType {
  finance,
  task,
  note,
}

class _AmountMatch {
  const _AmountMatch({
    required this.amount,
    required this.startIndex,
    required this.endIndex,
  });

  final int amount;
  final int startIndex;
  final int endIndex;
}
