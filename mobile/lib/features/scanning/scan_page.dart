import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/api_client.dart';
import '../../core/opencv_pipeline.dart';
import '../../core/template_constants.dart';

class CellCropData {
  final int questionNumber;
  final String base64;
  final String? mcqAnswer;
  final bool mcqAmbiguous;
  const CellCropData(this.questionNumber, this.base64,
      {this.mcqAnswer, this.mcqAmbiguous = false});
}

/// Proses satu foto halaman: deteksi marker + crop sel halaman tsb.
/// Dipanggil di dalam isolate (CPU-heavy).
Future<List<CellCropData>> _processPage(String filePath, List<CellRect> pageCells) async {
  final bytes = File(filePath).readAsBytesSync();
  final photo = img.decodeImage(bytes);
  if (photo == null) {
    throw const MarkerDetectionException('Gagal membaca foto');
  }
  final res = detectMarkers(photo);
  final crops = cropCells(photo, res, pageCells);
  return crops
      .map((c) => CellCropData(
            c.questionNumber,
            base64Encode(c.jpegBytes),
            mcqAnswer: c.mcqMark?.answer,
            mcqAmbiguous: c.mcqMark?.ambiguous ?? false,
          ))
      .toList();
}

class ScanPage extends StatefulWidget {
  final int examId;
  const ScanPage({super.key, required this.examId});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _camera;
  bool _cameraReady = false;
  List<dynamic>? _students;
  dynamic _student;
  List<dynamic>? _questions;
  bool _processing = false;
  String? _error;

  List<List<CellRect>> _pages = [];
  int _pageIndex = 0;
  final List<CellCropData> _crops = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Kamera tidak ditemukan');
        return;
      }
      final controller = CameraController(
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first),
        ResolutionPreset.max,
        enableAudio: false,
      );
      await controller.initialize();
      final exam = await ApiClient.instance.getExam(widget.examId);
      final students = await ApiClient.instance.getStudents(exam['class_id'] as int);
      final questions = await ApiClient.instance.getQuestions(widget.examId);
      if (!mounted) return;
      final types = questions.map((q) => q['type'] as String).toList();
      setState(() {
        _camera = controller;
        _cameraReady = true;
        _students = students;
        _questions = questions;
        if (students.isNotEmpty) _student = students.first;
        _pages = computeLayout(types);
        _pageIndex = 0;
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _capture() async {
    if (_camera == null || !_cameraReady || _processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final xfile = await _camera!.takePicture();
      final pageCells = _pages[_pageIndex];
      final result = await _processPage(xfile.path, pageCells);
      if (!mounted) return;
      setState(() {
        _crops.addAll(result);
        if (_pageIndex < _pages.length - 1) {
          _pageIndex++; // lanjut halaman berikutnya
        }
      });
      if (pageCells.isEmpty) {
        setState(() => _error = 'Halaman ini tidak memiliki soal');
      }
    } on MarkerDetectionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _upload() async {
    if (_student == null || _crops.isEmpty) return;
    setState(() => _processing = true);
    try {
      final submission = await ApiClient.instance.uploadCrops(
        widget.examId,
        _student!['id'] as int,
        _crops
            .map((c) => {
                  'question_number': c.questionNumber.toString(),
                  'image_base64': c.base64,
                  if (c.mcqAnswer != null) 'mcq_answer': c.mcqAnswer,
                  'mcq_ambiguous': c.mcqAmbiguous,
                })
            .toList(),
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed('/review', arguments: submission['id'] as int);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _questions?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Lembar Jawaban')),
      body: _error != null && _camera == null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: _cameraReady && _camera != null
                      ? Stack(fit: StackFit.expand, children: [
                          CameraPreview(_camera!),
                          if (_pages.length > 1)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Chip(
                                label: Text('Halaman ${_pageIndex + 1}/${_pages.length}'),
                              ),
                            ),
                        ])
                      : const Center(child: CircularProgressIndicator()),
                ),
                if (_students != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: DropdownButtonFormField<dynamic>(
                      initialValue: _student,
                      decoration: const InputDecoration(labelText: 'Siswa'),
                      items: _students!
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text('${s['student_number']} — ${s['name']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _student = v),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        _crops.isEmpty
                            ? 'Foto halaman ${_pageIndex + 1}'
                            : '${_crops.length}/$totalQuestions soal ter-crop',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _processing ? null : _capture,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_crops.isEmpty ? 'Ambil Foto' : 'Foto Berikutnya'),
                            ),
                          ),
                          if (_crops.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _processing ? null : _upload,
                                icon: const Icon(Icons.upload),
                                label: const Text('Kirim & Koreksi'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
