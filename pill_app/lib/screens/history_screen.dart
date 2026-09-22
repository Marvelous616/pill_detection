import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import '../services/schedule_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final medicineBox = Hive.box<Medicine>('medicines');
    final eventsBox = ScheduleService.events();

    return Scaffold(
      appBar: AppBar(title: const Text('History & Adherence')),
      body: ListenableBuilder(
        listenable:
            Listenable.merge([medicineBox.listenable(), eventsBox.listenable()]),
        builder: (context, _) {
          final meds = medicineBox.values.toList();
          if (meds.isEmpty) {
            return const Center(child: Text('Add medications to see history.'));
          }
          final streak = ScheduleService.computeStreak(meds);
          final weekPct = ScheduleService.adherencePercentage(meds, 7);
          final monthPct = ScheduleService.adherencePercentage(meds, 30);
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statRow(streak, weekPct, monthPct),
              const SizedBox(height: 20),
              const Text('Last 14 days',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _calendarGrid(meds, todayDate),
              const SizedBox(height: 20),
              const Text('Recent days',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              for (var d = 0; d < 7; d++)
                _dayLog(
                  meds,
                  todayDate.subtract(Duration(days: d)),
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _statRow(int streak, double weekPct, double monthPct) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department,
            color: Colors.orange,
            value: '$streak day${streak == 1 ? '' : 's'}',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            value: '${weekPct.toStringAsFixed(0)}%',
            label: '7-day',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.calendar_today,
            color: Colors.indigo,
            value: '${monthPct.toStringAsFixed(0)}%',
            label: '30-day',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _calendarGrid(List<Medicine> meds, DateTime today) {
    final cells = <Widget>[];
    for (var d = 13; d >= 0; d--) {
      final date = today.subtract(Duration(days: d));
      final stats = ScheduleService.dayStats(meds, date);
      final color = stats.expected == 0
          ? Colors.grey.shade300
          : stats.missed == 0 && stats.taken == stats.expected
              ? Colors.green
              : stats.taken > 0
                  ? Colors.orange
                  : Colors.red;
      final isToday = ScheduleService.sameDay(date, today);
      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isToday ? 1.0 : 0.65),
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: Colors.black, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Text(
                _weekday(date),
                style: TextStyle(
                  fontSize: 10,
                  color: isToday ? Colors.white : Colors.black54,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isToday ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: cells,
    );
  }

  String _weekday(DateTime d) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }

  Widget _dayLog(List<Medicine> meds, DateTime date) {
    final stats = ScheduleService.dayStats(meds, date);
    final items = ScheduleService.buildSchedule(meds, date);
    final isToday = ScheduleService.sameDay(date, DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isToday ? 'Today' : _dateLabel(date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (stats.expected == 0)
                  const Text('No doses scheduled')
                else
                  Text(
                    '${stats.taken}/${stats.expected} taken'
                    '${stats.missed > 0 ? ' · ${stats.missed} missed' : ''}',
                    style: TextStyle(
                      color: stats.missed > 0 ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      switch (item.status) {
                        DoseStatus.taken => Icons.check_circle,
                        DoseStatus.skipped => Icons.remove_circle,
                        _ => Icons.radio_button_unchecked,
                      },
                      size: 16,
                      color: switch (item.status) {
                        DoseStatus.taken => Colors.green,
                        DoseStatus.skipped => Colors.grey,
                        DoseStatus.overdue => Colors.red,
                        DoseStatus.upcoming => Colors.indigo,
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.time} · ${item.medicine.name} '
                        '(${item.medicine.doseLabel})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      switch (item.status) {
                        DoseStatus.taken => 'Taken',
                        DoseStatus.skipped => 'Skipped',
                        DoseStatus.overdue => 'Missed',
                        DoseStatus.upcoming => 'Upcoming',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        color: switch (item.status) {
                          DoseStatus.taken => Colors.green.shade700,
                          DoseStatus.skipped => Colors.grey.shade600,
                          DoseStatus.overdue => Colors.red.shade700,
                          DoseStatus.upcoming => Colors.indigo,
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}