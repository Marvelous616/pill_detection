import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../models/medicine.dart';
import '../services/dose_forms.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import 'medicine_info_screen.dart';

class CameraScreen extends StatefulWidget {
  final void Function(String medicineName, String imagePath) onMedicineIdentified;

  const CameraScreen({super.key, required this.onMedicineIdentified});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _classifying = false;
  List<ImageLabel> _labels = [];
  bool _scanComplete = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _labels = [];
      _scanComplete = false;
    });
    await _classify(_imageFile!);
  }

  Future<void> _classify(File imageFile) async {
    setState(() => _classifying = true);

    final inputImage = InputImage.fromFile(imageFile);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.3),
    );

    final labels = await labeler.processImage(inputImage);
    await labeler.close();

    setState(() {
      _labels = labels
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      _classifying = false;
      _scanComplete = true;
    });
  }

  void _addAsNew() {
    final best = _labels.isEmpty ? null : _labels.first.label;
    Navigator.pop(context);
    widget.onMedicineIdentified(best ?? 'New medicine', _imageFile!.path);
  }

  void _showDoseCheck(Medicine med) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DismissibleDoseCheckSheet(med: med),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Check')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.contain)
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Take or select a photo of the pill',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              flex: 4,
              child: _scanComplete
                  ? _buildCheckPanel()
                  : _classifying
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Classifying image…'),
                            ],
                          ),
                        )
                      : const _ScanTutorial(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckPanel() {
    final medicineBox = Hive.box<Medicine>('medicines');
    final form = DoseForms.formFromLabels(_labels);
    final bestLabel = _labels.isEmpty ? null : _labels.first.label;

    return ListenableBuilder(
      listenable: medicineBox.listenable(),
      builder: (context, _) {
        final meds = medicineBox.values.toList();
        return ListView(
          children: [
            if (form != null || bestLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (form != null)
                      Chip(
                        avatar: Icon(DoseForms.iconFor(form), size: 18),
                        label: Text(form),
                        backgroundColor: Colors.teal.withValues(alpha: 0.12),
                        side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
                      ),
                    for (final l in _labels.take(3))
                      Chip(
                        label: Text(
                          '${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            const Text('Which of your medications is this?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (meds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No medications saved yet — add it with the button below.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              for (final med in meds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication),
                  title: Text(med.name),
                  subtitle: Text(
                    [med.doseLabel, if (med.mealHint.isNotEmpty) med.mealHint]
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDoseCheck(med),
                ),
            const Divider(height: 16),
            TextButton.icon(
              onPressed: _addAsNew,
              icon: const Icon(Icons.add_circle_outline),
              label:
                  Text('This isn\'t one of mine — add as new (${bestLabel ?? 'search'})'),
            ),
          ],
        );
      },
    );
  }
}

class _ScanTutorial extends StatelessWidget {
  const _ScanTutorial();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Scan a pill, then tap any of your medications\n'
        'to see whether you\'re supposed to take it now.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

/// Bottom sheet that answers "should I take {med} now?" using the schedule
/// and lets the user record the dose in one tap.
class DismissibleDoseCheckSheet extends StatelessWidget {
  final Medicine med;

  const DismissibleDoseCheckSheet({super.key, required this.med});

  Future<void> _markTaken(BuildContext context, DoseItem item) async {
    await ScheduleService.markDose(
      ScheduleService.events(),
      med.key as int,
      item.time,
      DateTime.now(),
      true,
    );
    await NotificationService.dismissDoseToday(med, item.index);
  }

  Future<void> _undoTaken(BuildContext context, DoseItem item) async {
    await ScheduleService.clearDose(
      ScheduleService.events(),
      med.key as int,
      item.time,
      DateTime.now(),
    );
    await NotificationService.restoreDoseToday(med, item.index);
  }

  Widget _verdictHeader(BuildContext context, DoseVerdict verdict) {
    final (icon, color, headline, detail) = switch (verdict.kind) {
      DoseVerdictKind.dueNow => (
          Icons.alarm_on,
          Colors.green,
          'Should take',
          'You missed a dose at ${verdict.primary!.time} — take it now.',
        ),
      DoseVerdictKind.upcoming => (
          Icons.schedule,
          Colors.indigo,
          'Not yet',
          'Supposed to take at ${verdict.primary!.time}, not before.',
        ),
      DoseVerdictKind.done => (
          Icons.check_circle_outline,
          Colors.grey,
          'Nothing to take',
          verdict.items.any((i) => i.status == DoseStatus.skipped)
              ? 'You skipped today\'s scheduled doses.'
              : 'All of today\'s doses are accounted for.',
        ),
      DoseVerdictKind.noDoses => (
          Icons.event_busy,
          Colors.grey,
          'Not scheduled',
          'This medicine has no dose times set.',
        ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: ListenableBuilder(
          listenable: ScheduleService.events().listenable(),
          builder: (context, _) {
            final verdict = ScheduleService.verdictFor(med, DateTime.now());

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(med.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.manage_search),
                        tooltip: 'View medicine info',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MedicineInfoScreen(initialQuery: med.name),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _verdictHeader(context, verdict),

                  if (verdict.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Today\'s doses',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    for (final item in verdict.items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          switch (item.status) {
                            DoseStatus.taken => Icons.check_circle,
                            DoseStatus.skipped => Icons.remove_circle,
                            DoseStatus.overdue => Icons.error,
                            DoseStatus.upcoming => Icons.schedule,
                          },
                          size: 20,
                          color: switch (item.status) {
                            DoseStatus.taken => Colors.green,
                            DoseStatus.skipped => Colors.grey,
                            DoseStatus.overdue => Colors.red,
                            DoseStatus.upcoming => Colors.indigo,
                          },
                        ),
                        title: Text(
                          '${item.time} · ${med.doseLabel}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: switch (item.status) {
                          DoseStatus.taken => TextButton(
                              onPressed: () => _undoTaken(context, item),
                              child: const Text('Undo'),
                            ),
                          DoseStatus.overdue ||
                          DoseStatus.upcoming =>
                            FilledButton.tonal(
                              onPressed: () => _markTaken(context, item),
                              child: const Text('Take'),
                            ),
                          DoseStatus.skipped => const Text(
                              'Skipped',
                              style: TextStyle(fontSize: 12),
                            ),
                        },
                      ),
                    const SizedBox(height: 8),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: switch (verdict.kind) {
                      DoseVerdictKind.dueNow => FilledButton.icon(
                          onPressed: () => _markTaken(context, verdict.primary!),
                          icon: const Icon(Icons.check),
                          label: Text(
                              'Mark as taken (${verdict.primary!.time})'),
                        ),
                      DoseVerdictKind.upcoming => OutlinedButton.icon(
                          onPressed: () => _markTaken(context, verdict.primary!),
                          icon: const Icon(Icons.check),
                          label:
                              Text('Take now early (${verdict.primary!.time})'),
                        ),
                      DoseVerdictKind.done => null,
                      DoseVerdictKind.noDoses => null,
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}