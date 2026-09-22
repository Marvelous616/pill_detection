// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineAdapter extends TypeAdapter<Medicine> {
  @override
  final int typeId = 0;

  @override
  Medicine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medicine(
      name: fields[0] as String,
      imagePath: fields[1] as String,
      doseTimes: (fields[2] as List).cast<String>(),
      lastTaken: fields[3] as DateTime?,
      dosage: fields[4] as String?,
      notes: fields[5] as String?,
      remindersEnabled: fields[6] as bool?,
      mealTiming: fields[7] as String?,
      restrictions: (fields[8] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Medicine obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.doseTimes)
      ..writeByte(3)
      ..write(obj.lastTaken)
      ..writeByte(4)
      ..write(obj.dosage)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.remindersEnabled)
      ..writeByte(7)
      ..write(obj.mealTiming)
      ..writeByte(8)
      ..write(obj.restrictions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
