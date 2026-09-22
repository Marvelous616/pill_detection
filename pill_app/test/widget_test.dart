import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:pill_app/models/dose_event.dart';
import 'package:pill_app/models/medicine.dart';
import 'package:pill_app/screens/home_screen.dart';

void main() {
  Hive.init(Directory.systemTemp.path);
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(DoseEventAdapter());

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(dir.path);
    await Hive.openBox<Medicine>('medicines');
    await Hive.openBox<DoseEvent>('dose_events');
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  testWidgets('shows empty state when no medications exist', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.textContaining('No medications added yet'), findsOneWidget);
  });

  testWidgets('renders dose rows for added medicines', (tester) async {
    await tester.runAsync(() async {
      final box = Hive.box<Medicine>('medicines');
      await box.add(Medicine(
        name: 'Vitamin D',
        imagePath: '',
        doseTimes: ['08:00', '20:00'],
        dosage: '1 pill',
      ));
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('08:00 · 1 pill'), findsOneWidget);
    expect(find.text('20:00 · 1 pill'), findsOneWidget);
    expect(find.text('Vitamin D'), findsNWidgets(2));

    final summary = find.text('0/2 doses taken today');
    expect(summary, findsOneWidget);
  });
}