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
  const CellCropData(
    this.questionNumber,
    this.base64, {
    this.mcqAnswer,
    this.mcqAmbiguous = false,
  });
}

/// Proses satu foto halaman: deteksi marker + crop sel halaman tsb.
/// Dipanggil di dalam isolate (CPU-heavy).
Future<List<CellCropData>> _processPage(String filePath, List<CellRect> pageCells) async {
  final bytes = File(filePath).readAsBytesSync();
  final photo = img.decodeImage(bytes);
  if (photo == null) {
    throw const MarkerDetectionException('Gagal membaca foto lembar jawaban');
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

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  CameraController? _camera;
  bool _cameraReady = false;
  List<dynamic>? _students;
  dynamic _student;
  List<dynamic>? _questions;
  bool _processing = false;
  String? _error;

  List<List<CellRect>> _pages = [];
  int _pageIndex = 0;

  /// Menyimpan hasil crop terpetakan per halaman (pageIndex -> List<CellCropData>)
  /// Memungkinkan foto ulang (retake) per halaman tanpa menghapus halaman lain.
  final Map<int, List<CellCropData>> _pageCrops = {};

  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Kamera tidak ditemukan pada perangkat ini');
        return;
      }
      final controller = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
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

  List<CellCropData> _getAllCrops() {
    final list = <CellCropData>[];
    for (var i = 0; i < _pages.length; i++) {
      if (_pageCrops.containsKey(i)) {
        list.addAll(_pageCrops[i]!);
      }
    }
    list.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
    return list;
  }

  Future<void> _captureCurrentPage() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    if (_pages.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final file = await _camera!.takePicture();
      final targetPageCells = _pages[_pageIndex];
      final crops = await _processPage(file.path, targetPageCells);

      setState(() {
        _pageCrops[_pageIndex] = crops;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Berhasil memotong ${crops.length} butir soal dari Halaman ${_pageIndex + 1}'),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
          ),
        );

        if (_pageIndex < _pages.length - 1 && !_pageCrops.containsKey(_pageIndex + 1)) {
          setState(() => _pageIndex = _pageIndex + 1);
        }
      }
    } on MarkerDetectionException catch (e) {
      setState(() => _error = 'Marker LJK tidak terdeteksi: ${e.message}. Pastikan 4 kotak sudut masuk bingkai.');
    } catch (e) {
      setState(() => _error = 'Gagal memproses foto: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _upload() async {
    if (_student == null) {
      setState(() => _error = 'Pilih siswa terlebih dahulu!');
      return;
    }

    final crops = _getAllCrops();
    if (crops.isEmpty) {
      setState(() => _error = 'Ambil foto lembar jawaban terlebih dahulu');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final payload = [
        for (final c in crops)
          {
            'question_number': c.questionNumber,
            'image_base64': c.base64,
            if (c.mcqAnswer != null) 'mobile_answer': c.mcqAnswer,
          },
      ];
      final submission = await ApiClient.instance.uploadCrops(
        widget.examId,
        _student['id'] as int,
        payload,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/review', arguments: submission['id'] as int);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _questions?.length ?? 0;
    final allCrops = _getAllCrops();
    final isCurrentPageScanned = _pageCrops.containsKey(_pageIndex);
    final isAllPagesScanned = _pageCrops.length == _pages.length && _pages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidyanetra Scanner'),
        actions: [
          if (_pageCrops.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _pageCrops.clear();
                  _pageIndex = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua halaman di-reset')),
                );
              },
              icon: const Icon(Icons.refresh, color: Color(0xFF0F766E), size: 16),
              label: const Text('Reset', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _error != null && _camera == null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                // Selector Halaman & Status Scan
                if (_pages.length > 1)
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_pages.length, (idx) {
                          final hasCrop = _pageCrops.containsKey(idx);
                          final isSelected = idx == _pageIndex;
                          final count = _pageCrops[idx]?.length ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasCrop ? Icons.check_circle_rounded : Icons.document_scanner_outlined,
                                    size: 14,
                                    color: hasCrop ? const Color(0xFF10B981) : (isSelected ? const Color(0xFF0F766E) : Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasCrop ? 'Hal ${idx + 1} ($count soal)' : 'Hal ${idx + 1}',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                      color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _pageIndex = idx),
                              selectedColor: const Color(0xFFE6F4F1),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                // Area Kamera dengan Smart Viewfinder & Laser Overlay
                Expanded(
                  child: _cameraReady && _camera != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_camera!),

                            // Smart Viewfinder Guide Overlay
                            CustomPaint(
                              painter: ViewfinderOverlayPainter(
                                isProcessing: _processing,
                                laserProgress: _laserController.value,
                              ),
                            ),

                            // Top Info Pill
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCurrentPageScanned ? const Color(0xFF10B981) : Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Halaman ${_pageIndex + 1} dari ${_pages.length}'
                                      '${isCurrentPageScanned ? ' (✓ Ter-crop)' : ' (Arahkan LJK)'}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Processing Overlay
                            if (_processing)
                              Container(
                                color: Colors.black.withOpacity(0.6),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: Color(0xFF10B981)),
                                      SizedBox(height: 14),
                                      Text(
                                        'Ekstraksi Edge CV & Homografi...',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
                ),

                // Pilihan Siswa
                if (_students != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<dynamic>(
                      initialValue: _student,
                      decoration: InputDecoration(
                        labelText: 'Pilih Siswa yang Dinilai',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _students!
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text('${s['student_number']} — ${s['name']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _student = v),
                    ),
                  ),

                // Pesan Error jika ada
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Kontrol Tombol Aksi
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status: ${allCrops.length}/$totalQuestions butir ter-crop',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Hal ${_pageIndex + 1} (${_pages.isNotEmpty ? _pages[_pageIndex].length : 0} butir)',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Tombol Ambil / Retake Foto
                          Expanded(
                            flex: 3,
                            child: FilledButton.icon(
                              onPressed: _processing ? null : _captureCurrentPage,
                              style: FilledButton.styleFrom(
                                backgroundColor: isCurrentPageScanned ? Colors.amber.shade800 : const Color(0xFF0F766E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(isCurrentPageScanned ? Icons.replay : Icons.camera_alt, size: 18),
                              label: Text(
                                isCurrentPageScanned
                                    ? '🔄 Foto Ulang (Hal ${_pageIndex + 1})'
                                    : '📷 Ambil Foto (Hal ${_pageIndex + 1})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Tombol Kirim & Koreksi
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: (_processing || !isAllPagesScanned) ? null : _upload,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Koreksi AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
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

/// Custom Painter untuk Smart Viewfinder Kamera Vidyanetra
class ViewfinderOverlayPainter extends CustomPainter {
  final bool isProcessing;
  final double laserProgress;

  ViewfinderOverlayPainter({required this.isProcessing, required this.laserProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final marginH = size.width * 0.08;
    final marginV = size.height * 0.08;
    final rect = Rect.fromLTRB(marginH, marginV, size.width - marginH, size.height - marginV);

    final guidePaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer guide border
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), guidePaint);

    // 4 Corner Brackets (Thick Accent)
    final cornerPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLen), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - cornerLen, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLen), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - cornerLen, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), cornerPaint);

    // Animated Laser Line during processing / scanning
    if (isProcessing) {
      final laserY = rect.top + (rect.height * laserProgress);
      final laserPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, Color(0xFF10B981), Color(0xFF14B8A6), Colors.transparent],
        ).createShader(Rect.fromLTWH(rect.left, laserY - 2, rect.width, 4))
        ..strokeWidth = 3.0;

      canvas.drawLine(Offset(rect.left + 8, laserY), Offset(rect.right - 8, laserY), laserPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ViewfinderOverlayPainter oldDelegate) => true;
}
