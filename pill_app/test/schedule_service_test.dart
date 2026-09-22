import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:pill_app/models/dose_event.dart';
import 'package:pill_app/models/medicine.dart';
import 'package:pill_app/services/schedule_service.dart';

void main() {
  Hive.init(Directory.systemTemp.path);
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(DoseEventAdapter());

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('hive_svc_test');
    Hive.init(dir.path);
    await Hive.openBox<Medicine>('medicines');
    await Hive.openBox<DoseEvent>('dose_events');
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  Medicine makeMed(String name, List<String> times) =>
      Medicine(name: name, imagePath: '', doseTimes: times);

  Future<int> addMed(Medicine med) async {
    final mb = Hive.box<Medicine>('medicines');
    await mb.add(med);
    return mb.values.first.key as int;
  }

  test('today: past dose overdue, future dose upcoming', () async {
    final now = DateTime.now();
    final past = ScheduleService.formatHM(now.subtract(const Duration(minutes: 30)));
    final future = ScheduleService.formatHM(now.add(const Duration(minutes: 30)));
    await addMed(makeMed('M', [past, future]));

    final items = ScheduleService.buildSchedule(
      Hive.box<Medicine>('medicines').values.toList(),
      DateTime.now(),
    );

    expect(items[0].status, DoseStatus.overdue);
    expect(items[1].status, DoseStatus.upcoming);
  });

  test('markDose upserts and counts as taken', () async {
    final key = await addMed(makeMed('M', ['08:00']));
    final day = DateTime.now();

    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, true);
    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, true);

    expect(ScheduleService.events().values.length, 1);

    final stats = ScheduleService.dayStats(
      Hive.box<Medicine>('medicines').values.toList(),
      day,
    );
    expect(stats.expected, 1);
    expect(stats.taken, 1);
    expect(stats.missed, 0);
  });

  test('skipped count as skipped, not missed', () async {
    final key = await addMed(makeMed('M', ['08:00']));
    final day = DateTime.now();

    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, false);

    final stats = ScheduleService.dayStats(
      Hive.box<Medicine>('medicines').values.toList(),
      day,
    );
    expect(stats.skipped, 1);
    expect(stats.missed, 0);
  });

  test('clearDose removes an existing event', () async {
    final key = await addMed(makeMed('M', ['08:00']));
    final day = DateTime.now();

    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, true);
    await ScheduleService.clearDose(ScheduleService.events(), key, '08:00', day);

    expect(ScheduleService.events().values, isEmpty);
  });

  test('verdictFor: overdue dose means due now', () async {
    final now = DateTime.now();
    final past = ScheduleService.formatHM(now.subtract(const Duration(minutes: 30)));
    await addMed(makeMed('M', [past]));

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, now);

    expect(verdict.kind, DoseVerdictKind.dueNow);
    expect(verdict.shouldTakeNow, isTrue);
    expect(verdict.primary?.time, past);
  });

  test('verdictFor: upcoming dose means not yet', () async {
    final now = DateTime.now();
    final future = ScheduleService.formatHM(now.add(const Duration(minutes: 30)));
    await addMed(makeMed('M', [future]));

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, now);

    expect(verdict.kind, DoseVerdictKind.upcoming);
    expect(verdict.shouldTakeNow, isFalse);
  });

  test('verdictFor: earliest overdue chosen as primary', () async {
    final now = DateTime.now();
    final later = ScheduleService.formatHM(now.add(const Duration(minutes: 30)));
    final earlier = ScheduleService.formatHM(now.subtract(const Duration(minutes: 30)));
    await addMed(makeMed('M', [later, earlier]));

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, now);

    expect(verdict.kind, DoseVerdictKind.dueNow);
    expect(verdict.primary?.time, earlier);
  });

  test('verdictFor: medicine with no dose times is not scheduled', () async {
    await addMed(makeMed('M', const []));

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, DateTime.now());

    expect(verdict.kind, DoseVerdictKind.noDoses);
  });

  test('verdictFor: all doses taken means done', () async {
    final key = await addMed(makeMed('M', ['08:00', '20:00']));
    final day = DateTime.now();
    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, true);
    await ScheduleService.markDose(ScheduleService.events(), key, '20:00', day, true);

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, day);

    expect(verdict.kind, DoseVerdictKind.done);
    expect(verdict.shouldTakeNow, isFalse);
  });

  test('verdictFor: all skipped also means done', () async {
    final key = await addMed(makeMed('M', ['08:00']));
    final day = DateTime.now();
    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, false);

    final med = Hive.box<Medicine>('medicines').values.first;
    final verdict = ScheduleService.verdictFor(med, day);

    expect(verdict.kind, DoseVerdictKind.done);
    expect(verdict.items.first.status, DoseStatus.skipped);
  });

  test('past day unresolved doses count as missed', () async {
    await addMed(makeMed('M', ['08:00']));

    final stats = ScheduleService.dayStats(
      Hive.box<Medicine>('medicines').values.toList(),
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(stats.expected, 1);
    expect(stats.missed, 1);
  });

  test('computeStreak counts consecutive fully-taken days', () async {
    final key = await addMed(makeMed('M', ['08:00']));
    final today = DateTime.now();

    for (var d = 0; d < 3; d++) {
      await ScheduleService.markDose(
        ScheduleService.events(),
        key,
        '08:00',
        today.subtract(Duration(days: d)),
        true,
      );
    }

    expect(
      ScheduleService.computeStreak(Hive.box<Medicine>('medicines').values.toList()),
      greaterThanOrEqualTo(3),
    );
  });

  test('adherencePercentage reflects taken / expected', () async {
    final key = await addMed(makeMed('M', ['08:00', '20:00']));
    final day = DateTime.now();

    await ScheduleService.markDose(ScheduleService.events(), key, '08:00', day, true);

    expect(
      ScheduleService.adherencePercentage(
        Hive.box<Medicine>('medicines').values.toList(),
        1,
      ),
      closeTo(50, 1),
    );
  });
}