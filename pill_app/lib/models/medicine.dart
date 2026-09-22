import 'package:hive/hive.dart';
part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String imagePath;
  @HiveField(2)
  List<String> doseTimes; // e.g. ["08:00", "20:00"]
  @HiveField(3)
  DateTime? lastTaken;
  Medicine({
    required this.name,
    required this.imagePath,
    required this.doseTimes,
    this.lastTaken,
  });
}
