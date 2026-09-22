import 'package:flutter/material.dart';
import '../services/medicine_database.dart';

/// Browse the offline medicine database. When [onSelect] is provided the
/// screen acts as a picker: tapping a result returns its name to the caller.
class MedicineInfoScreen extends StatefulWidget {
  final String? initialQuery;
  final void Function(MedicineInfo info)? onSelect;

  const MedicineInfoScreen({super.key, this.initialQuery, this.onSelect});

  @override
  State<MedicineInfoScreen> createState() => _MedicineInfoScreenState();
}

class _MedicineInfoScreenState extends State<MedicineInfoScreen> {
  late final TextEditingController _searchController;
  final List<MedicineInfo> _results = [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _query);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await MedicineDatabase.instance.load();
      if (_query.isNotEmpty) _search();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load medicine information: ${e.toString()}';
        });
      }
    }
  }

  void _search() {
    final db = MedicineDatabase.instance;
    if (!db.isLoaded) return;
    setState(() {
      _results
        ..clear()
        ..addAll(MedicineDatabase.search(db.entries, _query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Information')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search medicine or salt…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _results.clear();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              // Debounce-free incremental search once the db is loaded.
              onChanged: (v) {
                _query = v;
                _search();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_query.isEmpty) {
      return const _HintView();
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No matches found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _ResultTile(
        info: _results[i],
        onSelect: widget.onSelect,
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  const _HintView();

  @override
  Widget build(BuildContext context) {
    final db = MedicineDatabase.instance;
    final count = db.isLoaded ? db.entries.length : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medication_liquid, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              count == null
                  ? 'Type to browse the medicine database.'
                  : '$count medications available offline.\n'
                      'Type to browse descriptions, side effects and interactions.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final MedicineInfo info;
  final void Function(MedicineInfo info)? onSelect;

  const _ResultTile({required this.info, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isPicker = onSelect != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.medication),
        title: Text(
          info.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _subtitle(),
        trailing: isPicker
            ? FilledButton.tonal(
                onPressed: () => onSelect!(info),
                child: const Text('Use'),
              )
            : const Icon(Icons.expand_more),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in _details)
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                    Text(value, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget? _subtitle() {
    final parts = <String>[
      if (info.salt.isNotEmpty) info.salt,
      if (info.therapeuticClass.isNotEmpty) info.therapeuticClass,
      if (info.price.isNotEmpty) 'Rs. $info.price',
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  List<(String, String)> get _details => [
        ('Salt composition', info.salt),
        ('Therapeutic class', info.therapeuticClass),
        ('Category', info.category),
        ('Manufacturer', info.manufacturer),
        ('Price', info.price.isEmpty ? '' : 'Rs. ${info.price}'),
        ('Description', info.description),
        ('Side effects', info.sideEffects),
        ('Drug interactions', info.interactions),
      ];
}