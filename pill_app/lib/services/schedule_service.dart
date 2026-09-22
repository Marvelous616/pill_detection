import 'package:hive/hive.dart';
import '../models/dose_event.dart';
import '../models/medicine.dart';

enum DoseStatus { taken, skipped, overdue, upcoming }

class DoseItem {
  final Medicine medicine;
  final int index;
  final String time;
  final DoseStatus status;
  final DoseEvent? event;

  DoseItem({
    required this.medicine,
    required this.index,
    required this.time,
    required this.status,
    required this.event,
  });
}

enum DoseVerdictKind { dueNow, upcoming, done, noDoses }

/// Answers "should I take this right now?" for a single [Medicine].
class DoseVerdict {
  final List<DoseItem> items;

  /// Whether the user should (or may) take the medicine now.
  final DoseVerdictKind kind;

  /// The dose to act on: the earliest overdue dose, else the earliest
  /// upcoming dose. Null when nothing is actionable today.
  final DoseItem? primary;

  const DoseVerdict({required this.items, required this.kind, this.primary});

  bool get shouldTakeNow => kind == DoseVerdictKind.dueNow;
}

class ScheduleService {
  static Box<DoseEvent> events() => Hive.box<DoseEvent>('dose_events');

  static int _timeValue(String time) => hourOf(time) * 60 + minuteOf(time);

  /// Computes what the user should do with [med] right now. The verdict is
  /// "due now" when an overdue dose exists (missed), "upcoming" when the next
  /// dose is still ahead, "done" when every dose today is taken/skipped, and
  /// "no doses" when the medicine has no dose times at all.
  static DoseVerdict verdictFor(Medicine med, DateTime now) {
    final items = buildSchedule([med], now);
    final overdue = items
        .where((i) => i.status == DoseStatus.overdue)
        .toList()
      ..sort((a, b) => _timeValue(a.time).compareTo(_timeValue(b.time)));
    if (overdue.isNotEmpty) {
      return DoseVerdict(
        items: items,
        kind: DoseVerdictKind.dueNow,
        primary: overdue.first,
      );
    }
    final upcoming = items
        .where((i) => i.status == DoseStatus.upcoming)
        .toList()
      ..sort((a, b) => _timeValue(a.time).compareTo(_timeValue(b.time)));
    if (upcoming.isNotEmpty) {
      return DoseVerdict(
        items: items,
        kind: DoseVerdictKind.upcoming,
        primary: upcoming.first,
      );
    }
    if (items.isEmpty) {
      return DoseVerdict(items: items, kind: DoseVerdictKind.noDoses);
    }
    return DoseVerdict(items: items, kind: DoseVerdictKind.done);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int hourOf(String time) => int.parse(time.split(':')[0]);

  static int minuteOf(String time) => int.parse(time.split(':')[1]);

  static String formatHM(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static DoseEvent? eventFor(
    Box<DoseEvent> box,
    int medKey,
    String time,
    DateTime date,
  ) {
    for (final e in box.values) {
      if (e.medicineKey == medKey && e.doseTime == time && sameDay(e.date, date)) {
        return e;
      }
    }
    return null;
  }

  static List<DoseItem> buildSchedule(List<Medicine> meds, DateTime day) {
    final box = events();
    final now = DateTime.now();
    final items = <DoseItem>[];
    for (final med in meds) {
      for (int i = 0; i < med.doseTimes.length; i++) {
        final time = med.doseTimes[i];
        final ev = eventFor(box, med.key as int, time, day);
        DoseStatus status;
        if (ev != null) {
          status = ev.taken ? DoseStatus.taken : DoseStatus.skipped;
        } else if (sameDay(day, now)) {
          final dueAt = dateOnly(now).add(
            Duration(hours: hourOf(time), minutes: minuteOf(time)),
          );
          status = now.isBefore(dueAt) ? DoseStatus.upcoming : DoseStatus.overdue;
        } else {
          status = DoseStatus.overdue;
        }
        items.add(DoseItem(
          medicine: med,
          index: i,
          time: time,
          status: status,
          event: ev,
        ));
      }
    }
    return items;
  }

  static ({int expected, int taken, int missed, int skipped, int upcoming})
      dayStats(
    List<Medicine> meds,
    DateTime day, {
    List<DoseItem>? items,
  }) {
    int expected = 0, taken = 0, missed = 0, skipped = 0, upcoming = 0;
    final list = items ?? buildSchedule(meds, day);
    for (final item in list) {
      expected++;
      switch (item.status) {
        case DoseStatus.taken:
          taken++;
          break;
        case DoseStatus.skipped:
          skipped++;
          break;
        case DoseStatus.overdue:
          missed++;
          break;
        case DoseStatus.upcoming:
          upcoming++;
          break;
      }
    }
    return (
      expected: expected,
      taken: taken,
      missed: missed,
      skipped: skipped,
      upcoming: upcoming,
    );
  }

  static Future<DoseEvent> markDose(
    Box<DoseEvent> box,
    int medKey,
    String time,
    DateTime day,
    bool taken,
  ) async {
    final existing = eventFor(box, medKey, time, day);
    if (existing != null) {
      existing.taken = taken;
      existing.date = dateOnly(day);
      existing.actedAt = DateTime.now();
      await existing.save();
      return existing;
    }
    final ev = DoseEvent(
      medicineKey: medKey,
      doseTime: time,
      date: dateOnly(day),
      taken: taken,
      actedAt: DateTime.now(),
    );
    await box.add(ev);
    return ev;
  }

  static Future<DoseEvent?> clearDose(
    Box<DoseEvent> box,
    int medKey,
    String time,
    DateTime day,
  ) async {
    final existing = eventFor(box, medKey, time, day);
    if (existing != null) {
      await existing.delete();
    }
    return existing;
  }

  static int computeStreak(List<Medicine> meds) {
    if (meds.isEmpty) return 0;
    var day = dateOnly(DateTime.now());
    final todayStats = dayStats(meds, day);
    if (todayStats.missed > 0 || todayStats.expected == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (true) {
      final s = dayStats(meds, day);
      if (s.expected == 0) {
        if (streak == 0) {
          day = day.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      if (s.missed > 0) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static double adherencePercentage(List<Medicine> meds, int days) {
    int expected = 0, taken = 0;
    final today = dateOnly(DateTime.now());
    for (int d = 0; d < days; d++) {
      final date = today.subtract(Duration(days: d));
      final s = dayStats(meds, date);
      expected += s.expected;
      taken += s.taken;
    }
    return expected == 0 ? 100 : taken / expected * 100;
  }
}