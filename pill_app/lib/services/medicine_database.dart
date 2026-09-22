import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

const _assetPath = 'assets/medicines.json.gz';

class MedicineInfo {
  final String name;
  final String salt;
  final String manufacturer;
  final String category;
  final String price;
  final String description;
  final String sideEffects;
  final String interactions;
  final String therapeuticClass;

  const MedicineInfo({
    required this.name,
    this.salt = '',
    this.manufacturer = '',
    this.category = '',
    this.price = '',
    this.description = '',
    this.sideEffects = '',
    this.interactions = '',
    this.therapeuticClass = '',
  });

  static MedicineInfo fromJson(Map<String, dynamic> j) => MedicineInfo(
        name: (j['n'] as String?) ?? '',
        salt: (j['s'] as String?) ?? '',
        manufacturer: (j['m'] as String?) ?? '',
        category: (j['c'] as String?) ?? '',
        price: (j['p'] as String?) ?? '',
        description: (j['d'] as String?) ?? '',
        sideEffects: (j['e'] as String?) ?? '',
        interactions: (j['i'] as String?) ?? '',
        therapeuticClass: (j['t'] as String?) ?? '',
      );

  bool get hasDetails =>
      salt.isNotEmpty ||
      manufacturer.isNotEmpty ||
      description.isNotEmpty ||
      sideEffects.isNotEmpty ||
      interactions.isNotEmpty;
}

/// Provides read-only lookup of medication information bundled as a gzipped
/// JSON asset (built from offline datasets by build_medicine_asset.py).
class MedicineDatabase {
  MedicineDatabase._();

  static final MedicineDatabase instance = MedicineDatabase._();

  List<MedicineInfo> _entries = const [];
  bool _loaded = false;
  Future<void>? _loading;

  bool get isLoaded => _loaded;

  List<MedicineInfo> get entries => _entries;

  /// Loads (once) and caches the bundled database. Safe to call repeatedly.
  Future<void> load() {
    final inFlight = _loading;
    if (inFlight != null) return inFlight;
    _loading = _doLoad();
    return _loading!;
  }

  Future<void> _doLoad() async {
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List();
    final content = Utf8Decoder().convert(GZipCodec().decode(bytes));
    final raw = const JsonDecoder().convert(content) as List<dynamic>;
    _entries = List.unmodifiable(
      raw
          .whereType<Map<String, dynamic>>()
          .map(MedicineInfo.fromJson)
          .where((e) => e.name.isNotEmpty),
    );
    _loaded = true;
  }

  /// Normalizes text for matching (lowercase, strips punctuation/spaces).
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Returns up to [limit] entries matching [query], best matches first.
  /// Exact name match ranks first, then prefix, then substring.
  /// When [query] is only 2+ chars, salt composition is also considered.
  static List<MedicineInfo> search(
    List<MedicineInfo> entries,
    String query, {
    int limit = 8,
  }) {
    final q = normalize(query.trim());
    if (q.isEmpty) return const [];

    MedicineInfo? exact;
    final prefix = <MedicineInfo>[];
    final substring = <MedicineInfo>[];
    final saltMatches = <MedicineInfo>[];

    for (final e in entries) {
      final n = normalize(e.name);
      if (n == q) {
        exact = e;
      } else if (n.startsWith(q)) {
        prefix.add(e);
      } else if (n.contains(q)) {
        substring.add(e);
      } else if (q.length >= 3 && e.salt.isNotEmpty) {
        if (normalize(e.salt).contains(q)) {
          saltMatches.add(e);
        }
      }
    }

    final ranked = <MedicineInfo>[
      ?exact,
      ...prefix,
      ...substring,
      ...saltMatches,
    ];
    return ranked.take(limit).toList();
  }
}