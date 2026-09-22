import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import 'add_medicine_screen.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Camera Teammate Integration Hook ──────────────────────────────────────
  // Called by CameraScreen once the user confirms a detected label.
  // Also the entry point for the real camera teammate module when ready.
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Medications')),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Medicine>('medicines').listenable(),
        builder: (context, Box<Medicine> box, _) {
          final meds = box.values.toList();
          if (meds.isEmpty) {
            return const Center(child: Text('No medications added yet.'));
          }
          return ListView.builder(
            itemCount: meds.length,
            itemBuilder: (context, i) => CheckboxListTile(
              title: Text(meds[i].name),
              subtitle: Text(meds[i].doseTimes.join(', ')),
              value: meds[i].lastTaken != null && _isToday(meds[i].lastTaken!),
              onChanged: (_) {
                meds[i].lastTaken = DateTime.now();
                meds[i].save();
              },
            ),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
              );
            },
            tooltip: 'Add Medicine Manually',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
