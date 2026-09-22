import 'package:hive/hive.dart';
part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String imagePath;
  @HiveField(2)
  List<String> doseTimes;
  @HiveField(3)
  DateTime? lastTaken;
  @HiveField(4)
  String? dosage;
  @HiveField(5)
  String? notes;
  @HiveField(6)
  bool? remindersEnabled;
  @HiveField(7)
  String? mealTiming;
  @HiveField(8)
  List<String>? restrictions;
  Medicine({
    required this.name,
    required this.imagePath,
    required this.doseTimes,
    this.lastTaken,
    this.dosage,
    this.notes,
    this.remindersEnabled,
    this.mealTiming,
    this.restrictions,
  });

  String get doseLabel => (dosage ?? '').trim().isEmpty ? '1 dose' : dosage!;
  String get notesText => notes ?? '';
  bool get reminderOn => remindersEnabled ?? true;
  List<String> get restrictionList => restrictions ?? const [];

  String get mealLabel => switch (mealTiming ?? '') {
        'before' => 'Before meals',
        'after' => 'After meals',
        _ => '',
      };

  String get mealHint => [
        if (mealLabel.isNotEmpty) 'Take $mealLabel',
        ...restrictionList,
      ].join(' · ');

  set doseLabel(String value) => dosage = value;
  set notesText(String value) => notes = value;
  set reminderOn(bool value) => remindersEnabled = value;
  set mealLabel(String value) => mealTiming = value;
  set restrictionList(List<String> value) => restrictions = value;
}