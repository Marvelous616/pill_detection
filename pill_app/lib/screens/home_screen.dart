import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import 'add_medicine_screen.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import 'medicine_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void onMedicineIdentified(String medicineName, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(
          initialName: medicineName,
          initialImagePath: imagePath,
        ),
      ),
    );
  }

  void _openCameraScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(onMedicineIdentified: onMedicineIdentified),
      ),
    );
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
  }

  void _openEdit(Medicine med) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMedicineScreen(medicine: med)),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _openInfo(Medicine med) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineInfoScreen(initialQuery: med.name),
      ),
    );
  }

  Future<void> _markTaken(DoseItem item) async {
    final box = ScheduleService.events();
    await ScheduleService.markDose(
      box,
      item.medicine.key as int,
      item.time,
      DateTime.now(),
      true,
    );
    await NotificationService.dismissDoseToday(item.medicine, item.index);
  }

  Future<void> _unmarkTaken(DoseItem item) async {
    final box = ScheduleService.events();
    await ScheduleService.clearDose(
      box,
      item.medicine.key as int,
      item.time,
      DateTime.now(),
    );
    await NotificationService.restoreDoseToday(item.medicine, item.index);
  }

  Future<void> _skipToday(DoseItem item) async {
    final box = ScheduleService.events();
    await ScheduleService.markDose(
      box,
      item.medicine.key as int,
      item.time,
      DateTime.now(),
      false,
    );
    await NotificationService.dismissDoseToday(item.medicine, item.index);
  }

  Future<void> _unshipToday(DoseItem item) => _unmarkTaken(item);

  Future<void> _snooze(DoseItem item) async {
    await NotificationService.snooze(item.medicine, item.index);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder for ${item.time} snoozed 15 min'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteMedicine(Medicine med) async {
    try {
      await NotificationService.cancelMedicineNotifications(med);
    } catch (_) {
      // Notification plugin may not be initialized; never block deletion.
    }
    final events = ScheduleService.events();
    final toDelete = events.values
        .where((e) => e.medicineKey == med.key)
        .toList();
    for (final e in toDelete) {
      await e.delete();
    }
    await med.delete();
  }

  void _confirmDelete(Medicine med) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text('"${med.name}" and its history will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMedicine(med);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showActions(DoseItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final med = item.medicine;
        final taken = item.status == DoseStatus.taken;
        final skipped = item.status == DoseStatus.skipped;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.medication),
                title: Text(med.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.time} · ${med.doseLabel}'),
                    if (med.mealHint.isNotEmpty)
                      Text(
                        med.mealHint,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (!taken)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as taken'),
                  onTap: () {
                    Navigator.pop(context);
                    _markTaken(item);
                  },
                ),
              if (taken)
                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.orange),
                  title: const Text('Undo taken'),
                  onTap: () {
                    Navigator.pop(context);
                    _unmarkTaken(item);
                  },
                ),
              if (!skipped && !taken)
                ListTile(
                  leading: const Icon(Icons.event_busy, color: Colors.grey),
                  title: const Text('Skip today'),
                  onTap: () {
                    Navigator.pop(context);
                    _skipToday(item);
                  },
                ),
              if (skipped)
                ListTile(
                  leading: const Icon(Icons.replay, color: Colors.blue),
                  title: const Text('Cancel skip'),
                  onTap: () {
                    Navigator.pop(context);
                    _unshipToday(item);
                  },
                ),
              if (!taken && !skipped)
                ListTile(
                  leading: const Icon(Icons.alarm, color: Colors.indigo),
                  title: const Text('Snooze 15 minutes'),
                  onTap: () {
                    Navigator.pop(context);
                    _snooze(item);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.manage_search, color: Colors.teal),
                title: const Text('View medicine info'),
                onTap: () {
                  Navigator.pop(context);
                  _openInfo(med);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.black54),
                title: const Text('Edit medicine'),
                onTap: () {
                  Navigator.pop(context);
                  _openEdit(med);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete medicine'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(med);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(DoseStatus status, String time) {
    final (label, color) = switch (status) {
      DoseStatus.taken => ('Taken', Colors.green),
      DoseStatus.skipped => ('Skipped', Colors.grey),
      DoseStatus.overdue => ('Missed', Colors.red),
      DoseStatus.upcoming => ('Upcoming', Colors.indigo),
    };
    return Chip(
      label: Text('$label $time',
          style: TextStyle(fontSize: 11, color: color)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }

  List<Widget> _buildDoseRow(DoseItem item) {
    final med = item.medicine;
    final taken = item.status == DoseStatus.taken;
    final hintParts = <String>[];
    if (med.mealLabel.isNotEmpty) hintParts.add(med.mealLabel);
    hintParts.addAll(med.restrictionList);
    final hint = hintParts.isNotEmpty ? 'Take ${hintParts.join(' · ')}' : '';
    return [
      ListTile(
        leading: Checkbox(
          value: taken,
          onChanged: (_) =>
              taken ? _unmarkTaken(item) : _markTaken(item),
        ),
        title: Text('${item.time} · ${med.doseLabel}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(med.name),
            if (hint.isNotEmpty)
              Text(
                hint,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            if (med.notesText.isNotEmpty)
              Text(
                med.notesText,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip(item.status, item.time),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showActions(item),
            ),
          ],
        ),
        onTap: () => taken ? _unmarkTaken(item) : _markTaken(item),
      ),
      const Divider(height: 1, indent: 72),
    ];
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '$title ($count)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicineBox = Hive.box<Medicine>('medicines');
    final eventsBox = ScheduleService.events();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insert_chart_outlined),
            tooltip: 'History & adherence',
            onPressed: _openHistory,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable:
            Listenable.merge([medicineBox.listenable(), eventsBox.listenable()]),
        builder: (context, _) {
          final meds = medicineBox.values.toList();
          if (meds.isEmpty) {
            return const Center(
              child: Text(
                'No medications added yet.\nUse the camera or + button to add one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final items = ScheduleService.buildSchedule(meds, DateTime.now());
          final stats = ScheduleService.dayStats(meds, DateTime.now(), items: items);

          final overdue = items.where((i) => i.status == DoseStatus.overdue).toList();
          final upcoming = items.where((i) => i.status == DoseStatus.upcoming).toList();
          final taken = items.where((i) => i.status == DoseStatus.taken).toList();
          final skipped = items.where((i) => i.status == DoseStatus.skipped).toList();

          final progress = stats.expected == 0
              ? 0.0
              : stats.taken / stats.expected;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (stats.missed > 0)
                          Expanded(
                            child: _summaryChip(
                              '${stats.missed} missed',
                              Colors.red,
                            ),
                          ),
                        if (stats.upcoming > 0)
                          Expanded(
                            child: _summaryChip(
                              '${stats.upcoming} upcoming',
                              Colors.indigo,
                            ),
                          ),
                        if (stats.taken > 0)
                          Expanded(
                            child: _summaryChip(
                              '${stats.taken} taken',
                              Colors.green,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.taken}/${stats.expected} doses taken today',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _sectionHeader('Missed', overdue.length),
                      for (final i in overdue) ..._buildDoseRow(i),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _sectionHeader('Upcoming', upcoming.length),
                      for (final i in upcoming) ..._buildDoseRow(i),
                    ],
                    if (taken.isNotEmpty) ...[
                      _sectionHeader('Taken today', taken.length),
                      for (final i in taken) ..._buildDoseRow(i),
                    ],
                    if (skipped.isNotEmpty) ...[
                      _sectionHeader('Skipped today', skipped.length),
                      for (final i in skipped) ..._buildDoseRow(i),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'camera_scan_btn',
            onPressed: _openCameraScreen,
            tooltip: 'Scan Pill with Camera',
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'manual_add_btn',
            onPressed: _openAdd,
            tooltip: 'Add Medicine Manually',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}