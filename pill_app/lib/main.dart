import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/dose_event.dart';
import 'models/medicine.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotificationService.init();
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(DoseEventAdapter());
  await Hive.openBox<Medicine>('medicines');
  await Hive.openBox<DoseEvent>('dose_events');
  await _migrateLegacyMedicines();
  runApp(const MyApp());
}

Future<void> _migrateLegacyMedicines() async {
  final box = Hive.box<Medicine>('medicines');
  for (final med in box.values) {
    var changed = false;
    if (med.dosage == null) {
      med.dosage = '1';
      changed = true;
    }
    if (med.notes == null) {
      med.notes = '';
      changed = true;
    }
    if (med.remindersEnabled == null) {
      med.remindersEnabled = true;
      changed = true;
    }
    if (med.mealTiming == null) {
      med.mealTiming = '';
      changed = true;
    }
    if (med.restrictions == null) {
      med.restrictions = [];
      changed = true;
    }
    if (changed) {
      await med.save();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillOra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}