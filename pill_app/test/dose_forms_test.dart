import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'package:pill_app/services/dose_forms.dart';

ImageLabel label(String text, {double confidence = 0.9}) =>
    ImageLabel(label: text, confidence: confidence, index: 0);

void main() {
  test('recognises tablet from pill label', () {
    expect(DoseForms.formFromLabels([label('pill')]), 'Tablet');
    expect(DoseForms.formFromLabels([label('Tablet')]), 'Tablet');
  });

  test('recognises capsule', () {
    expect(DoseForms.formFromLabels([label('capsule')]), 'Capsule');
    expect(DoseForms.formFromLabels([label('gelcap')]), 'Capsule');
  });

  test('recognises liquid, inhaler, injection, drops', () {
    expect(DoseForms.formFromLabels([label('syrup')]), 'Syrup');
    expect(DoseForms.formFromLabels([label('inhaler')]), 'Inhaler');
    expect(DoseForms.formFromLabels([label('injection')]), 'Injection');
    expect(DoseForms.formFromLabels([label('drops')]), 'Drops');
  });

  test('uses the highest-confidence matching label first', () {
    final labels = [
      label('table', confidence: 0.5),
      label('pill', confidence: 0.9),
    ];
    expect(DoseForms.formFromLabels(labels), 'Tablet');
  });

  test('returns null when no label resembles a medicine form', () {
    expect(DoseForms.formFromLabels([label('person')]), isNull);
    expect(DoseForms.formFromLabels([]), isNull);
  });

  test('iconFor falls back to medication icon for unknown forms', () {
    expect(DoseForms.iconFor('Tablet'), Icons.medication);
    expect(DoseForms.iconFor('Nope'), Icons.medication);
  });
}