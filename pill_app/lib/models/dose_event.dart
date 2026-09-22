import 'package:hive/hive.dart';
part 'dose_event.g.dart';

@HiveType(typeId: 1)
class DoseEvent extends HiveObject {
  @HiveField(0)
  int medicineKey;
  @HiveField(1)
  String doseTime;
  @HiveField(2)
  DateTime date;
  @HiveField(3)
  bool taken;
  @HiveField(4)
  DateTime? actedAt;
  DoseEvent({
    required this.medicineKey,
    required this.doseTime,
    required this.date,
    required this.taken,
    this.actedAt,
  });
}