import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Maps generic image-labeler output (e.g. "pill", "bottle") to a useful
/// dosage form so a scan can hint what kind of medication was detected.
class DoseForms {
  DoseForms._();

  static const _formHints = <String, String>{
    'pill': 'Tablet',
    'tablet': 'Tablet',
    'tablets': 'Tablet',
    'caplet': 'Tablet',
    'capsule': 'Capsule',
    'capsules': 'Capsule',
    'gelcap': 'Capsule',
    'medicine': 'Tablet',
    'medication': 'Tablet',
    'drug': 'Tablet',
    'bottle': 'Bottle',
    'liquid': 'Liquid',
    'syrup': 'Syrup',
    'solution': 'Liquid',
    'injection': 'Injection',
    'syringe': 'Injection',
    'cream': 'Topical',
    'ointment': 'Topical',
    'lotion': 'Topical',
    'inhaler': 'Inhaler',
    'asthma': 'Inhaler',
    'patch': 'Patch',
    'drops': 'Drops',
    'eye': 'Drops',
  };

  static const _formIcons = <String, IconData>{
    'Tablet': Icons.medication,
    'Capsule': Icons.medication,
    'Bottle': Icons.medication_liquid,
    'Liquid': Icons.local_drink,
    'Syrup': Icons.local_drink,
    'Injection': Icons.vaccines,
    'Topical': Icons.healing,
    'Inhaler': Icons.air,
    'Patch': Icons.healing,
    'Drops': Icons.water_drop,
  };

  /// Returns the most confident form name (e.g. "Tablet") based on the
  /// detected labels, or null if nothing resembles a medication form.
  static String? formFromLabels(List<ImageLabel> labels) {
    for (final label in labels) {
      final norm = label.label.toLowerCase().trim();
      for (final entry in _formHints.entries) {
        if (norm == entry.key ||
            norm.contains(entry.key) ||
            entry.key.contains(norm)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  static IconData iconFor(String form) =>
      _formIcons[form] ?? Icons.medication;
}