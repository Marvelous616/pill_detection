import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/medicine.dart';
import 'schedule_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('med_channel', 'Medication Reminders'),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  static int medicineBaseId(Medicine m) => m.key.hashCode;

  static String titleFor(Medicine m) => 'Time to take ${m.name}';

  static String bodyFor(Medicine m, String time) {
    final hint = m.mealHint;
    final base = '${m.doseLabel} — ${m.name} at $time';
    return hint.isEmpty ? base : '$base. $hint';
  }

  static Future<void> scheduleMedicine(Medicine m) async {
    if (!m.reminderOn) return;
    final baseId = medicineBaseId(m);
    for (int i = 0; i < m.doseTimes.length; i++) {
      final time = m.doseTimes[i];
      await _schedule(
        baseId + i,
        titleFor(m),
        bodyFor(m, time),
        ScheduleService.hourOf(time),
        ScheduleService.minuteOf(time),
        repeatDaily: true,
        startTomorrow: false,
      );
    }
  }

  static Future<void> rescheduleMedicine(Medicine m) async {
    await cancelMedicineNotifications(m);
    await scheduleMedicine(m);
  }

  static Future<void> cancelMedicineNotifications(Medicine m) async {
    final baseId = medicineBaseId(m);
    for (int i = 0; i < m.doseTimes.length; i++) {
      await _plugin.cancel(id: baseId + i);
      await _plugin.cancel(id: baseId + 1000 + i);
    }
  }

  static Future<void> dismissDoseToday(Medicine m, int index) async {
    final id = medicineBaseId(m) + index;
    await _plugin.cancel(id: id);
    await _schedule(
      id,
      titleFor(m),
      bodyFor(m, m.doseTimes[index]),
      ScheduleService.hourOf(m.doseTimes[index]),
      ScheduleService.minuteOf(m.doseTimes[index]),
      repeatDaily: true,
      startTomorrow: true,
    );
  }

  static Future<void> restoreDoseToday(Medicine m, int index) async {
    final time = m.doseTimes[index];
    await _schedule(
      medicineBaseId(m) + index,
      titleFor(m),
      bodyFor(m, time),
      ScheduleService.hourOf(time),
      ScheduleService.minuteOf(time),
      repeatDaily: true,
      startTomorrow: false,
    );
  }

  static Future<void> snooze(Medicine m, int index, {int minutes = 15}) async {
    final id = medicineBaseId(m) + 1000 + index;
    await _plugin.cancel(id: id);
    final time = m.doseTimes[index];
    final now = tz.TZDateTime.now(tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: titleFor(m),
      body: 'Snoozed: ${bodyFor(m, time)}',
      scheduledDate: now.add(Duration(minutes: minutes)),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> scheduleDaily(int id, String title, String body, int hour, int minute) async {
    await _schedule(id, title, body, hour, minute, repeatDaily: true, startTomorrow: false);
  }

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    int hour,
    int minute, {
    required bool repeatDaily,
    required bool startTomorrow,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime when;
    if (startTomorrow) {
      final tomorrow = now.add(const Duration(days: 1));
      when = tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    } else {
      when = _nextInstanceOfTime(hour, minute);
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}