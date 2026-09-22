import 'package:flutter_test/flutter_test.dart';

import 'package:pill_app/services/medicine_database.dart';

MedicineInfo info(String name, {String salt = ''}) => MedicineInfo(name: name, salt: salt);

void main() {
  final db = [
    info('Vitamin D3', salt: 'Cholecalciferol'),
    info('Paracetamol 500', salt: 'Paracetamol'),
    info('Paracetamol tablets'),
    info('Aspirin'),
    info('Amoxicillin'),
    info('Ibuprofen', salt: 'Ibuprofen'),
  ];

  test('normalize strips punctuation and lowercases', () {
    expect(MedicineDatabase.normalize('Vitamin D3'), 'vitamind3');
    expect(MedicineDatabase.normalize('Paracetamol 500!'), 'paracetamol500');
  });

  test('exact name match ranks first', () {
    final r = MedicineDatabase.search(db, 'paracetamol 500');
    expect(r.first.name, 'Paracetamol 500');
  });

  test('prefix matches rank before substring matches', () {
    final r = MedicineDatabase.search(db, 'amoxi');
    expect(r.first.name, 'Amoxicillin');
    expect(r.first.name, startsWith('Amoxi'));

    final both = MedicineDatabase.search(db, 'paracetamol');
    expect(both.length, greaterThanOrEqualTo(2));
    expect(both.map((e) => e.name), containsAll(['Paracetamol 500', 'Paracetamol tablets']));
  });

  test('case and punctuation insensitive search', () {
    final r = MedicineDatabase.search(db, 'vitamin-d3');
    expect(r, isNotEmpty);
    expect(r.first.name, 'Vitamin D3');
  });

  test('search matches salt composition', () {
    final r = MedicineDatabase.search(db, 'cholecalciferol');
    expect(r, isNotEmpty);
    expect(r.first.name, 'Vitamin D3');
  });

  test('empty or short query returns no results', () {
    expect(MedicineDatabase.search(db, ''), isEmpty);
    expect(MedicineDatabase.search(db, '  '), isEmpty);
  });

  test('respects limit', () {
    final r = MedicineDatabase.search(db, 'paracetamol', limit: 1);
    expect(r.length, 1);
  });

  test('fromJson parses compact schema', () {
    final m = MedicineInfo.fromJson({
      'n': 'Aspirin',
      's': 'Acetylsalicylic acid',
      'm': 'Bayer',
      'c': 'Pain',
      'p': '25',
      'd': 'Reduces pain.',
      'e': 'Heartburn',
      'i': 'Warfarin',
      't': 'NSAID',
    });
    expect(m.name, 'Aspirin');
    expect(m.salt, 'Acetylsalicylic acid');
    expect(m.interactions, 'Warfarin');
    expect(m.hasDetails, isTrue);
  });

  test('missing fields default to empty strings', () {
    const m = MedicineInfo(name: 'OnlyName');
    expect(m.salt, '');
    expect(m.hasDetails, isFalse);
  });

  testWidgets('loads the real bundled dataset asset', (tester) async {
    await tester.runAsync(() async {
      await MedicineDatabase.instance.load();
    });
    expect(MedicineDatabase.instance.isLoaded, isTrue);
    expect(MedicineDatabase.instance.entries.length, greaterThan(7000));
    final r = MedicineDatabase.search(
      MedicineDatabase.instance.entries,
      'paracetamol',
    );
    expect(r, isNotEmpty);
    expect(r.first.hasDetails, isTrue);
  });
}