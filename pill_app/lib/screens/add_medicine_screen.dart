import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/medicine.dart';
import '../services/medicine_database.dart';
import '../services/notification_service.dart';
import 'medicine_info_screen.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? initialName;
  final String? initialImagePath;
  final Medicine? medicine;

  const AddMedicineScreen({super.key, this.initialName, this.initialImagePath, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  static const _restrictionOptions = [
    'No grapefruit',
    'No dairy',
    'No caffeine',
    'No alcohol',
    'No spinach (blood thinners)',
    'Avoid antacids',
    'Take with water',
  ];

  static const _frequencyPresets = {
    1: ['08:00'],
    2: ['08:00', '20:00'],
    3: ['08:00', '14:00', '20:00'],
    4: ['08:00', '12:00', '16:00', '20:00'],
  };

  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _notesController;
  late String _imagePath;
  bool _remindersOn = true;
  String _mealTiming = '';
  final List<String> _restrictions = [];
  final List<TimeOfDay> _selectedTimes = [];
  MedicineInfo? _selectedInfo;

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: widget.initialName ?? med?.name ?? '');
    _imagePath = widget.initialImagePath ?? med?.imagePath ?? '';
    _dosageController = TextEditingController(text: med?.dosage ?? '1');
    _notesController = TextEditingController(text: med?.notesText ?? '');
    _remindersOn = med?.reminderOn ?? true;
    _mealTiming = med?.mealTiming ?? '';
    _restrictions.addAll(med?.restrictionList ?? const []);
    if (med != null) {
      for (final time in med.doseTimes) {
        final parts = time.split(':');
        _selectedTimes.add(TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTimes.add(time));
    }
  }

  Future<void> _lookupMedicineInfo() async {
    final info = await Navigator.push<MedicineInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineInfoScreen(
          onSelect: (selected) => Navigator.pop(context, selected),
        ),
      ),
    );
    if (info == null) return;
    setState(() {
      _selectedInfo = info;
      _nameController.text = info.name;
    });
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _applyFrequency(int count) {
    final presets = _frequencyPresets[count]!;
    setState(() {
      _selectedTimes.clear();
      for (final t in presets) {
        final parts = t.split(':');
        _selectedTimes.add(TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ));
      }
    });
  }

  bool _matchesPreset(int count) {
    final preset = _frequencyPresets[count]!;
    final current = _selectedTimes.map(_fmt).toSet();
    return current.length == preset.length &&
        current.containsAll(preset.map((t) => t));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and at least one dose time')),
      );
      return;
    }

    final doseTimes = _selectedTimes.map(_fmt).toList();
    final dosage = _dosageController.text.trim().isEmpty
        ? '1'
        : _dosageController.text.trim();

    if (_isEditing) {
      final med = widget.medicine!;
      med.name = name;
      med.imagePath = _imagePath;
      med.doseTimes = doseTimes;
      med.doseLabel = dosage;
      med.notesText = _notesController.text.trim();
      med.reminderOn = _remindersOn;
      med.mealLabel = _mealTiming;
      med.restrictionList = List.of(_restrictions);
      await NotificationService.rescheduleMedicine(med);
      await med.save();
    } else {
      final med = Medicine(
        name: name,
        imagePath: _imagePath,
        doseTimes: doseTimes,
        dosage: dosage,
        notes: _notesController.text.trim(),
        remindersEnabled: _remindersOn,
        mealTiming: _mealTiming,
        restrictions: List.of(_restrictions),
      );
      final box = Hive.box<Medicine>('medicines');
      await box.add(med);
      await NotificationService.scheduleMedicine(med);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildInfoCard(MedicineInfo info) {
    final points = <String>[
      if (info.description.isNotEmpty) info.description,
      if (info.sideEffects.isNotEmpty)
        'Side effects: ${info.sideEffects}',
      if (info.interactions.isNotEmpty)
        'Interactions: ${info.interactions}',
    ];
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Medicine info',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Dismiss',
                  onPressed: () => setState(() => _selectedInfo = null),
                ),
              ],
            ),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Medicine' : 'Add Medicine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imagePath.isNotEmpty && File(_imagePath).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath),
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Medicine Name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.manage_search),
                  tooltip: 'Look up medicine information',
                  onPressed: _lookupMedicineInfo,
                ),
              ),
            ),
            if (_selectedInfo != null) ...[
              const SizedBox(height: 8),
              _buildInfoCard(_selectedInfo!),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dose quantity (e.g. 1 pill, 10 ml)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Frequency per day',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final count in _frequencyPresets.keys)
                  ChoiceChip(
                    label: Text('$count× daily'),
                    selected: _selectedTimes.length == count &&
                        _matchesPreset(count),
                    onSelected: (_) => _applyFrequency(count),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('When to take',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'before', label: Text('Before meal')),
                ButtonSegment(value: 'after', label: Text('After meal')),
                ButtonSegment(value: '', label: Text('Anytime')),
              ],
              selected: {_mealTiming},
              onSelectionChanged: (s) => setState(() => _mealTiming = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Dietary restrictions',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in _restrictionOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _restrictions.contains(option),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _restrictions.add(option);
                      } else {
                        _restrictions.remove(option);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Reminders enabled'),
              subtitle: const Text('Schedules notification per dose time'),
              value: _remindersOn,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _remindersOn = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.access_time),
                    label: const Text('Add Dose Time'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final t in _selectedTimes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_fmt(t)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _selectedTimes.remove(t)),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Save Changes' : 'Save & Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}