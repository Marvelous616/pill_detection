import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _labels = [];
    });
    await _classify(_imageFile!);
  }

  Future<void> _classify(File imageFile) async {
    setState(() => _classifying = true);

    final inputImage = InputImage.fromFile(imageFile);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.4),
    );

    final labels = await labeler.processImage(inputImage);
    await labeler.close();

    setState(() {
      _labels = labels
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      _classifying = false;
    });
  }

  void _confirm(String label) {
    widget.onMedicineIdentified(label, _imageFile!.path);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identify Pill')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image Preview ────────────────────────────────────────────
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

            // ── Source Buttons ───────────────────────────────────────────
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

            // ── Labels / Loading ─────────────────────────────────────────
            Expanded(
              flex: 2,
              child: _classifying
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
                  : _labels.isEmpty
                      ? const Center(
                          child: Text(
                            'Pick an image to classify it',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detected labels – tap to confirm:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _labels.take(6).map((label) {
                                    final pct = (label.confidence * 100).toStringAsFixed(1);
                                    return ActionChip(
                                      label: Text('${label.label} ($pct%)'),
                                      onPressed: () => _confirm(label.label),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
