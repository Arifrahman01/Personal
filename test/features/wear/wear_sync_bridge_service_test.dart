import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_hub/features/meetings/models/meeting.dart';
import 'package:personal_hub/features/prayer/models/prayer_models.dart';
import 'package:personal_hub/features/tasks/models/task_models.dart';
import 'package:personal_hub/features/wear/models/wear_models.dart';
import 'package:personal_hub/features/wear/providers/wear_providers.dart';
import 'package:personal_hub/features/wear/services/wear_sync_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WearSyncBridgeService bridgeService;

  setUp(() {
    bridgeService = WearSyncBridgeService();
  });

  group('WearModels Serialization & Equality Tests', () {
    test('WearComplicationData serialize & deserialize matches exactly', () {
      final now = DateTime.utc(2026, 11, 23, 14, 30);
      final complication = WearComplicationData(
        id: 'comp-prayer-1',
        type: WearComplicationType.prayer,
        title: 'Ashar',
        subtitle: '15:15',
        iconKey: 'ic_prayer_ashar',
        remainingMinutes: 45,
        targetTimestamp: now,
      );

      final json = complication.toJson();
      expect(json['id'], 'comp-prayer-1');
      expect(json['type'], 'prayer');
      expect(json['title'], 'Ashar');
      expect(json['subtitle'], '15:15');
      expect(json['iconKey'], 'ic_prayer_ashar');
      expect(json['remainingMinutes'], 45);
      expect(json['targetTimestamp'], now.toIso8601String());

      final deserialized = WearComplicationData.fromJson(json);
      expect(deserialized, equals(complication));
      expect(deserialized.hashCode, equals(complication.hashCode));
      expect(deserialized.toString(), contains('comp-prayer-1'));

      final modified = complication.copyWith(remainingMinutes: 30);
      expect(modified.remainingMinutes, 30);
      expect(modified, isNot(equals(complication)));
    });

    test('WearTileData serialize & deserialize matches exactly with all nested data', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0);
      final tileData = WearTileData(
        activePrayer: const WearPrayerTileInfo(
          name: 'Dzuhur',
          time: '12:05',
          remainingMinutes: 5,
        ),
        upcomingMeeting: const WearMeetingTileInfo(
          title: 'Sprint Planning',
          time: '13:00',
          location: 'https://meet.google.com/abc-defg-hij',
        ),
        topTasks: const [
          WearTaskTileItem(id: 't-1', title: 'Review PR Personal Hub', isCompleted: false),
          WearTaskTileItem(id: 't-2', title: 'Kirim invoice klien', isCompleted: false),
          WearTaskTileItem(id: 't-3', title: 'Standup engineering', isCompleted: true),
        ],
        lastSyncedAt: now,
      );

      final serializedString = bridgeService.serializePayload(tileData);
      expect(serializedString, isNotEmpty);

      final decoded = bridgeService.deserializePayload(serializedString);
      expect(decoded.activePrayer?.name, 'Dzuhur');
      expect(decoded.activePrayer?.time, '12:05');
      expect(decoded.activePrayer?.remainingMinutes, 5);

      expect(decoded.upcomingMeeting?.title, 'Sprint Planning');
      expect(decoded.upcomingMeeting?.time, '13:00');
      expect(decoded.upcomingMeeting?.location, contains('meet.google.com'));

      expect(decoded.topTasks.length, 3);
      expect(decoded.topTasks[0].id, 't-1');
      expect(decoded.topTasks[0].isCompleted, false);
      expect(decoded.topTasks[2].isCompleted, true);

      expect(decoded.lastSyncedAt, now);
      expect(decoded, equals(tileData));
      expect(decoded.hashCode, equals(tileData.hashCode));
      expect(decoded.toString(), contains('Dzuhur'));
    });

    test('WearActionPayload serialize and deserialize test', () {
      final now = DateTime.utc(2026, 11, 23, 10, 0);
      final payload = WearActionPayload(
        type: WearActionType.toggleTask,
        payload: const {'taskId': 'task-99'},
        timestamp: now,
      );

      final json = payload.toJson();
      expect(json['type'], 'toggle_task');
      expect(json['payload'], {'taskId': 'task-99'});

      final fromJson = WearActionPayload.fromJson(json);
      expect(fromJson, equals(payload));
      expect(fromJson.hashCode, equals(payload.hashCode));
      expect(fromJson.toString(), contains('toggle_task'));

      final modified = payload.copyWith(type: WearActionType.logQuickExpense);
      expect(modified.type, WearActionType.logQuickExpense);
    });

    test('WearActionResult serialize and deserialize test', () {
      final now = DateTime.utc(2026, 11, 23, 10, 0);
      final tile = WearTileData(
        topTasks: const [WearTaskTileItem(id: '1', title: 'Task 1', isCompleted: true)],
        lastSyncedAt: now,
      );

      final result = WearActionResult(
        success: true,
        message: 'Action completed',
        updatedTileData: tile,
      );

      final json = result.toJson();
      expect(json['success'], true);
      expect(json['message'], 'Action completed');
      expect(json['updatedTileData'], isNotNull);

      final fromJson = WearActionResult.fromJson(json);
      expect(fromJson, equals(result));
      expect(fromJson.hashCode, equals(result.hashCode));
      expect(fromJson.toString(), contains('hasTile: true'));

      final cleared = result.copyWith(clearUpdatedTileData: true);
      expect(cleared.updatedTileData, isNull);
    });
  });

  group('WearSyncBridgeService Snapshot Generation', () {
    test('Uji pembuatan snapshot ketika ada jadwal sholat & meeting terisi', () {
      final fixedNow = DateTime(2026, 11, 23, 11, 30);

      final nextPrayer = NextPrayerInfo(
        name: PrayerName.dzuhur,
        time: DateTime(2026, 11, 23, 12, 10),
        remaining: const Duration(minutes: 40),
      );

      final meeting = Meeting(
        id: 'meet-101',
        title: 'Weekly Sync Product',
        scheduledAt: DateTime(2026, 11, 23, 14, 00),
        location: 'Ruang Rapat Utama & Zoom',
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );

      final tasks = [
        PersonalTask(
          id: 't-1',
          title: 'Implement F-12 Wear OS',
          priority: TaskPriority.high,
          isDone: false,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        PersonalTask(
          id: 't-2',
          title: 'Testing SQLite Sync',
          priority: TaskPriority.medium,
          isDone: false,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        PersonalTask(
          id: 't-3',
          title: 'Code review',
          priority: TaskPriority.low,
          isDone: false,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        PersonalTask(
          id: 't-4',
          title: 'Tugas yang sudah selesai',
          priority: TaskPriority.low,
          isDone: true,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
      ];

      final snapshot = bridgeService.generateTileSnapshot(
        nextPrayer: nextPrayer,
        upcomingMeeting: meeting,
        tasks: tasks,
        currentTime: fixedNow,
      );

      // Verifikasi Sholat
      expect(snapshot.activePrayer, isNotNull);
      expect(snapshot.activePrayer!.name, 'Dzuhur');
      expect(snapshot.activePrayer!.time, '12:10');
      expect(snapshot.activePrayer!.remainingMinutes, 40);

      // Verifikasi Meeting
      expect(snapshot.upcomingMeeting, isNotNull);
      expect(snapshot.upcomingMeeting!.title, 'Weekly Sync Product');
      expect(snapshot.upcomingMeeting!.time, '14:00');
      expect(snapshot.upcomingMeeting!.location, 'Ruang Rapat Utama & Zoom');

      // Verifikasi Tasks (Maksimal 3 tugas diambil)
      expect(snapshot.topTasks.length, 3);
      expect(snapshot.topTasks.map((t) => t.id).toList(), ['t-1', 't-2', 't-3']);
      expect(snapshot.topTasks.every((t) => !t.isCompleted), true);
      expect(snapshot.lastSyncedAt, fixedNow);
    });

    test('Uji pembuatan snapshot menggunakan DailyPrayerTimes & daftar upcomingMeetings', () {
      final fixedNow = DateTime(2026, 11, 23, 14, 45);

      final dailyPrayers = DailyPrayerTimes(
        date: fixedNow,
        subuh: DateTime(2026, 11, 23, 4, 30),
        syuruq: DateTime(2026, 11, 23, 5, 45),
        dzuhur: DateTime(2026, 11, 23, 12, 5),
        ashar: DateTime(2026, 11, 23, 15, 25), // Ini sholat berikutnya (+40 menit)
        maghrib: DateTime(2026, 11, 23, 18, 10),
        isya: DateTime(2026, 11, 23, 19, 20),
      );

      final meetings = [
        Meeting(
          id: 'meet-past',
          title: 'Morning Daily Standup',
          scheduledAt: DateTime(2026, 11, 23, 9, 0), // Lewat
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        Meeting(
          id: 'meet-soon',
          title: 'Review Sprint Bersama PO',
          scheduledAt: DateTime(2026, 11, 23, 16, 0), // Mendatang pertama
          location: 'https://zoom.us/j/999111',
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        Meeting(
          id: 'meet-later',
          title: '1-on-1 Mentoring',
          scheduledAt: DateTime(2026, 11, 23, 17, 30),
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
      ];

      final snapshot = bridgeService.generateTileSnapshot(
        dailyPrayers: dailyPrayers,
        upcomingMeetings: meetings,
        currentTime: fixedNow,
      );

      // Verifikasi Sholat terdekat yang otomatis dihitung
      expect(snapshot.activePrayer, isNotNull);
      expect(snapshot.activePrayer!.name, 'Ashar');
      expect(snapshot.activePrayer!.time, '15:25');
      expect(snapshot.activePrayer!.remainingMinutes, 40);

      // Verifikasi Meeting terdekat dari list yang belum lewat
      expect(snapshot.upcomingMeeting, isNotNull);
      expect(snapshot.upcomingMeeting!.title, 'Review Sprint Bersama PO');
      expect(snapshot.upcomingMeeting!.time, '16:00');
      expect(snapshot.upcomingMeeting!.location, 'https://zoom.us/j/999111');
    });

    test('Uji snapshot saat tidak ada meeting atau task kosong', () {
      final fixedNow = DateTime(2026, 11, 23, 20, 0);

      final snapshot = bridgeService.generateTileSnapshot(
        nextPrayer: null,
        upcomingMeeting: null,
        upcomingMeetings: [],
        tasks: [],
        currentTime: fixedNow,
      );

      expect(snapshot.activePrayer, isNull);
      expect(snapshot.upcomingMeeting, isNull);
      expect(snapshot.topTasks, isEmpty);
      expect(snapshot.lastSyncedAt, fixedNow);
    });

    test('Uji snapshot saat tasks null atau berisi task selesai dan belum selesai', () {
      final fixedNow = DateTime(2026, 11, 23, 8, 0);

      final tasks = [
        PersonalTask(
          id: 't-done-1',
          title: 'Tugas Selesai 1',
          priority: TaskPriority.low,
          isDone: true,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
        PersonalTask(
          id: 't-pending-1',
          title: 'Tugas Belum Selesai',
          priority: TaskPriority.high,
          isDone: false,
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
      ];

      final snapshot = bridgeService.generateTileSnapshot(
        tasks: tasks,
        currentTime: fixedNow,
      );

      expect(snapshot.topTasks.length, 2);
      // Prioritas yang belum selesai harus ditempatkan lebih dahulu
      expect(snapshot.topTasks.first.id, 't-pending-1');
      expect(snapshot.topTasks.first.isCompleted, false);
      expect(snapshot.topTasks.last.id, 't-done-1');
      expect(snapshot.topTasks.last.isCompleted, true);
    });
  });

  group('WearSyncBridgeService Action Handler Tests', () {
    test('Uji eksekusi handleWearAction untuk toggle_task berhasil', () async {
      String? toggledTaskId;

      final action = WearActionPayload(
        type: WearActionType.toggleTask,
        payload: const {'taskId': 'task-abc-123'},
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onToggleTask: (taskId) {
          toggledTaskId = taskId;
        },
      );

      expect(result.success, true);
      expect(result.message, contains('task-abc-123'));
      expect(toggledTaskId, 'task-abc-123');
    });

    test('Uji eksekusi toggle_task dengan key id alternatif', () async {
      String? toggledTaskId;

      final action = WearActionPayload(
        type: WearActionType.toggleTask,
        payload: const {'id': 'task-alt-id'},
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onToggleTask: (taskId) => toggledTaskId = taskId,
      );

      expect(result.success, true);
      expect(toggledTaskId, 'task-alt-id');
    });

    test('Uji eksekusi toggle_task gagal jika taskId kosong atau hilang', () async {
      bool called = false;

      final action = WearActionPayload(
        type: WearActionType.toggleTask,
        payload: const {},
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onToggleTask: (_) => called = true,
      );

      expect(result.success, false);
      expect(result.message, contains('taskId'));
      expect(called, false);
    });

    test('Uji eksekusi handleWearAction untuk log_quick_expense berhasil', () async {
      int? recordedAmount;
      String? recordedCategory;

      final action = WearActionPayload(
        type: WearActionType.logQuickExpense,
        payload: const {
          'amount': 25000,
          'category': 'Makan Siang',
        },
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onQuickExpense: (amount, category) {
          recordedAmount = amount;
          recordedCategory = category;
        },
      );

      expect(result.success, true);
      expect(result.message, contains('25000'));
      expect(result.message, contains('Makan Siang'));
      expect(recordedAmount, 25000);
      expect(recordedCategory, 'Makan Siang');
    });

    test('Uji eksekusi log_quick_expense dengan parsing amount bertipe string numerik', () async {
      int? recordedAmount;

      final action = WearActionPayload(
        type: WearActionType.logQuickExpense,
        payload: const {'amount': '15000'},
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onQuickExpense: (amount, category) => recordedAmount = amount,
      );

      expect(result.success, true);
      expect(recordedAmount, 15000);
    });

    test('Uji eksekusi log_quick_expense gagal jika amount tidak valid atau <= 0', () async {
      bool called = false;

      final action = WearActionPayload(
        type: WearActionType.logQuickExpense,
        payload: const {'amount': -500},
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(
        action,
        onQuickExpense: (amount, category) => called = true,
      );

      expect(result.success, false);
      expect(result.message, contains('tidak valid'));
      expect(called, false);
    });

    test('Uji eksekusi handleWearAction untuk prayer_acknowledged dan snooze_prayer', () async {
      bool prayerAck = false;
      bool prayerSnooze = false;

      final ackAction = WearActionPayload(
        type: WearActionType.prayerAcknowledged,
        timestamp: DateTime.now(),
      );

      final ackResult = await bridgeService.handleWearAction(
        ackAction,
        onPrayerAcknowledged: () => prayerAck = true,
      );

      expect(ackResult.success, true);
      expect(ackResult.message, contains('dikonfirmasi'));
      expect(prayerAck, true);

      final snoozeAction = WearActionPayload(
        type: WearActionType.snoozePrayer,
        timestamp: DateTime.now(),
      );

      final snoozeResult = await bridgeService.handleWearAction(
        snoozeAction,
        onSnoozePrayer: () => prayerSnooze = true,
      );

      expect(snoozeResult.success, true);
      expect(snoozeResult.message, contains('ditunda'));
      expect(prayerSnooze, true);
    });

    test('Uji aksi tipe tidak dikenal', () async {
      final action = WearActionPayload(
        type: WearActionType.unknown,
        timestamp: DateTime.now(),
      );

      final result = await bridgeService.handleWearAction(action);
      expect(result.success, false);
      expect(result.message, contains('tidak dikenali'));
    });
  });

  group('Uji Parsing Payload Rusak atau Tidak Valid', () {
    test('deserializePayload melempar FormatException jika input string kosong', () {
      expect(
        () => bridgeService.deserializePayload('   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('deserializePayload melempar FormatException jika json korup', () {
      expect(
        () => bridgeService.deserializePayload('{ broken_json: true, '),
        throwsA(isA<FormatException>()),
      );
    });

    test('deserializePayload melempar FormatException jika payload berupa JSON array bukan Map', () {
      expect(
        () => bridgeService.deserializePayload('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('handleRawActionJson menangani input kosong dengan graceful error result', () async {
      final result = await bridgeService.handleRawActionJson('');
      expect(result.success, false);
      expect(result.message, contains('kosong'));
    });

    test('handleRawActionJson menangani json korup tanpa crash', () async {
      final result = await bridgeService.handleRawActionJson('{{{ corrupt');
      expect(result.success, false);
      expect(result.message, contains('Gagal memproses'));
    });

    test('handleRawActionJson menangani tipe json bukan objek tanpa crash', () async {
      final result = await bridgeService.handleRawActionJson('"hanya string"');
      expect(result.success, false);
      expect(result.message, contains('harus berupa object'));
    });

    test('handleRawActionJson sukses memproses string json valid', () async {
      String? toggled;
      const raw = '{"type":"toggle_task","payload":{"taskId":"t-100"}}';

      final result = await bridgeService.handleRawActionJson(
        raw,
        onToggleTask: (id) => toggled = id,
      );

      expect(result.success, true);
      expect(toggled, 't-100');
    });

    test('WearTileData.fromJson menangani map kosong atau nilai null dengan aman', () {
      final tile = WearTileData.fromJson({});
      expect(tile.activePrayer, isNull);
      expect(tile.upcomingMeeting, isNull);
      expect(tile.topTasks, isEmpty);
      expect(tile.lastSyncedAt, isNotNull);
    });

    test('WearActionPayload.fromJson menangani tipe tidak dikenal dengan aman', () {
      final payload = WearActionPayload.fromJson({
        'type': 'unsupported_command_xyz',
        'payload': null,
      });

      expect(payload.type, WearActionType.unknown);
      expect(payload.payload, isEmpty);
    });
  });

  group('Wear OS MethodChannel Simulation & Riverpod Providers Tests', () {
    test('MethodChannel fallback graceful saat tidak tersedia di host platform', () async {
      final now = DateTime.utc(2026, 11, 23);
      final tile = WearTileData(lastSyncedAt: now);
      final complication = WearComplicationData(
        id: 'comp-1',
        type: WearComplicationType.meeting,
        title: 'Meeting',
        subtitle: '10:00',
        iconKey: 'ic_meeting',
        remainingMinutes: 10,
        targetTimestamp: now,
      );

      // Pada unit test environment tanpa native mock, pemanggilan channel ditangkap secara graceful
      final tileResult = await bridgeService.sendTileSnapshotToWear(tile);
      expect(tileResult, isA<bool>());

      final compResult = await bridgeService.sendComplicationToWear(complication);
      expect(compResult, isA<bool>());
    });

    test('wearSyncBridgeProvider dan wearTileDataProvider terinisialisasi dalam ProviderContainer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bridge = container.read(wearSyncBridgeProvider);
      expect(bridge, isNotNull);

      final tileData = container.read(wearTileDataProvider);
      expect(tileData, isNotNull);
      expect(tileData.topTasks, isNotNull);
    });
  });
}
