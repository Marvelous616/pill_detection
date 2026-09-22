import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/medicine.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotificationService.init();
  Hive.registerAdapter(MedicineAdapter());
  await Hive.openBox<Medicine>('medicines');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill App',
      home: const HomeScreen(),
    );
  }
}
