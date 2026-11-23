import 'package:intl/intl.dart';
import 'package:personal_hub/features/ai/models/ai_models.dart';
import 'package:personal_hub/features/ai/services/samudra_ai_client.dart';
import 'package:personal_hub/features/meetings/data/meetings_repository.dart';
import 'package:personal_hub/features/tasks/data/tasks_repository.dart';

/// Generates an AI daily briefing from today's meetings and active tasks.
///
/// Explicitly never touches or accesses Password Vault records.
class DailyBriefingService {
  DailyBriefingService(
    this._aiClient,
    this._meetingsRepository,
    this._tasksRepository,
  );

  final SamudraAiClient _aiClient;
  final MeetingsRepository _meetingsRepository;
  final TasksRepository _tasksRepository;

  /// Summarizes today's agenda and pending tasks via [SamudraAiClient].
  Future<AiResponse> generateBriefing({required DateTime today}) async {
    final localToday = today.toLocal();
    final startOfDay = DateTime(
      localToday.year,
      localToday.month,
      localToday.day,
    );
    final endOfDay = DateTime(
      localToday.year,
      localToday.month,
      localToday.day,
      23,
      59,
      59,
    );

    final meetingsRaw = await _meetingsRepository.getMeetings(
      from: startOfDay,
      to: endOfDay,
    );
    final todaysMeetings = meetingsRaw
        .where((m) {
          final dt = m.scheduledAt.toLocal();
          return dt.year == localToday.year &&
              dt.month == localToday.month &&
              dt.day == localToday.day;
        })
        .toList(growable: false);

    final pendingTasks = (await _tasksRepository.getTasks(includeDone: false))
        .where((t) => !t.isDone)
        .toList(growable: false);

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer()
      ..writeln('Tanggal: ${dateFmt.format(localToday)}')
      ..writeln()
      ..writeln('Jadwal Meeting Hari Ini (${todaysMeetings.length}):');

    if (todaysMeetings.isEmpty) {
      buffer.writeln('- Tidak ada meeting hari ini.');
    } else {
      for (final meeting in todaysMeetings) {
        final localTime = timeFmt.format(meeting.scheduledAt.toLocal());
        final loc = meeting.location.isNotEmpty ? ' di ${meeting.location}' : '';
        buffer.writeln('- [$localTime] ${meeting.title}$loc');
      }
    }

    buffer
      ..writeln()
      ..writeln('Tugas Aktif (${pendingTasks.length}):');
    if (pendingTasks.isEmpty) {
      buffer.writeln('- Semua tugas aktif sudah selesai.');
    } else {
      for (final task in pendingTasks.take(15)) {
        final due = task.dueDate != null
            ? ' (tenggat ${dateFmt.format(task.dueDate!.toLocal())})'
            : '';
        buffer.writeln('- [${task.priority.label}] ${task.title}$due');
      }
    }

    const systemPrompt =
        'Kamu adalah asisten produktivitas pribadi Personal Hub. '
        'Buat ringkasan harian singkat dalam Bahasa Indonesia yang terstruktur (maksimal 4 poin fokus utama, prioritas tugas, persiapan rapat, dan pengingat menjaga waktu sholat). '
        'Jawab langsung dengan nada suportif dan jelas.';

    return _aiClient.chat(
      messages: [AiMessage(role: 'user', content: buffer.toString())],
      systemPrompt: systemPrompt,
    );
  }
}
