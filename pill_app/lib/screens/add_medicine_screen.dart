import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/medicine.dart';
import '../services/notification_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? initialName;
  final String? initialImagePath;

  const AddMedicineScreen({super.key, this.initialName, this.initialImagePath});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  late final TextEditingController _nameController;
  late String _imagePath;
  final List<TimeOfDay> _selectedTimes = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _imagePath = widget.initialImagePath ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTimes.add(time);
      });
    }
  }

  void _save() async {
    if (_nameController.text.isEmpty || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and at least one time')),
      );
      return;
    }

    final box = Hive.box<Medicine>('medicines');
    
    // Convert to "HH:mm"
    List<String> doseTimesStr = _selectedTimes.map((t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return "$h:$m";
    }).toList();

    final medicine = Medicine(
      name: _nameController.text,
      imagePath: _imagePath, // Uses the captured image path if provided
      doseTimes: doseTimesStr,
    );
    
    await box.add(medicine);

    // Schedule notifications
    int baseId = medicine.key.hashCode;
    for (int i = 0; i < _selectedTimes.length; i++) {
       final time = _selectedTimes[i];
       final notifId = baseId + i; 
       await NotificationService.scheduleDaily(
         notifId,
         'Time to take ${_nameController.text}',
         'It is time for your scheduled dose.',
         time.hour,
         time.minute,
       );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medicine')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addTime,
              child: const Text('Add Dose Time'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedTimes.length,
                itemBuilder: (context, i) {
                  final t = _selectedTimes[i];
                  return ListTile(
                    title: Text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() => _selectedTimes.removeAt(i));
                      },
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save & Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
