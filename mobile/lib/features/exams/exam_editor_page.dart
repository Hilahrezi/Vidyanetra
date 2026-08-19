import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';

class ExamEditorPage extends StatefulWidget {
  final int? examId;
  const ExamEditorPage({super.key, this.examId});

  @override
  State<ExamEditorPage> createState() => _ExamEditorPageState();
}

class _ExamEditorPageState extends State<ExamEditorPage> {
  int? _currentExamId;
  Map<String, dynamic>? _exam;
  List<dynamic> _questions = [];
  List<dynamic> _classes = [];
  bool _loading = true;
  bool _downloadingPdf = false;
  String? _error;

  // New exam form controllers
  final _titleCtrl = TextEditingController(text: 'Ujian Baru');
  final _totalScoreCtrl = TextEditingController(text: '100');
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _currentExamId = widget.examId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final classes = await ApiClient.instance.getClasses();
      _classes = classes;
      if (_classes.isNotEmpty && _selectedClassId == null) {
        _selectedClassId = _classes.first['id'] as int;
      }

      if (_currentExamId != null) {
        final examData = await ApiClient.instance.getExam(_currentExamId!);
        final qList = await ApiClient.instance.getQuestions(_currentExamId!);
        _exam = examData as Map<String, dynamic>;
        _questions = qList;
      }
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createExam() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi judul ujian dan pilih kelas')),
      );
      return;
    }

    final totalScore = int.tryParse(_totalScoreCtrl.text) ?? 100;
    try {
      final res = await ApiClient.instance.createExam(
        _selectedClassId!,
        _titleCtrl.text.trim(),
        totalScore,
      );
      _currentExamId = res['id'] as int;
      _exam = res;
      await _loadQuestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ujian berhasil dibuat! Sekarang susun butir soal.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _loadQuestions() async {
    if (_currentExamId == null) return;
    try {
      final qList = await ApiClient.instance.getQuestions(_currentExamId!);
      if (mounted) setState(() => _questions = qList);
    } catch (_) {}
  }

  Future<void> _showAddQuestionDialog() async {
    if (_currentExamId == null) return;

    final nextNumber = _questions.isEmpty ? 1 : (_questions.map((q) => q['question_number'] as int).reduce((a, b) => a > b ? a : b) + 1);
    String selectedType = 'mcq';
    String mcqSelectedChoice = 'A';
    final answerKeyCtrl = TextEditingController(text: 'A');
    final weightCtrl = TextEditingController(text: '10');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tambah Soal #$nextNumber',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Type Selector
                const Text('Tipe Soal:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mcq', label: Text('Pilgan (MCQ)')),
                    ButtonSegment(value: 'short', label: Text('Isian')),
                    ButtonSegment(value: 'essay', label: Text('Esai')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (set) {
                    setModalState(() {
                      selectedType = set.first;
                      if (selectedType == 'mcq') {
                        answerKeyCtrl.text = mcqSelectedChoice;
                      } else if (answerKeyCtrl.text == 'A' || answerKeyCtrl.text == 'B' || answerKeyCtrl.text == 'C' || answerKeyCtrl.text == 'D') {
                        answerKeyCtrl.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Weight input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bobot Nilai',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Answer key inputs
                if (selectedType == 'mcq') ...[
                  const Text('Pilih Opsi Kunci Jawaban Benar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = mcqSelectedChoice == opt;
                      return ChoiceChip(
                        label: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.indigo,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              mcqSelectedChoice = opt;
                              answerKeyCtrl.text = opt;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ] else if (selectedType == 'short') ...[
                  TextField(
                    controller: answerKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kunci Jawaban Isian Singkat',
                      hintText: 'mis. Ibukota Indonesia | Jakarta',
                      border: OutlineInputBorder(),
                      helperText: 'Gunakan "|" untuk alternatif jawaban benar',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Alternatif (|)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          final cur = answerKeyCtrl.text.trim();
                          if (cur.isNotEmpty && !cur.endsWith('|')) {
                            answerKeyCtrl.text = '$cur | ';
                          }
                        });
                      },
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: answerKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kunci Jawaban Esai (Gagasan Utama / Rubrik)',
                      hintText: 'Tuliskan poin-poin atau konsep kunci yang dinilai oleh AI semantik...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: () async {
                    final key = answerKeyCtrl.text.trim();
                    if (key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kunci jawaban wajib diisi!')),
                      );
                      return;
                    }
                    final weight = double.tryParse(weightCtrl.text) ?? 10.0;

                    try {
                      await ApiClient.instance.createQuestion(
                        _currentExamId!,
                        nextNumber,
                        selectedType,
                        key,
                        weight,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadQuestions();
                    } on ApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  child: const Text('Simpan Soal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteQuestion(int questionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Soal?'),
        content: const Text('Soal ini akan dihapus dari ujian.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ApiClient.instance.deleteQuestion(questionId);
        await _loadQuestions();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_currentExamId == null) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan butir soal terlebih dahulu sebelum membuat PDF!')),
      );
      return;
    }

    setState(() => _downloadingPdf = true);
    try {
      final bytes = await ApiClient.instance.downloadExamTemplatePdf(_currentExamId!);

      Directory? dir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          dir = downloadDir;
        } else {
          dir = await getExternalStorageDirectory();
        }
      }
      dir ??= await getApplicationDocumentsDirectory();

      final sanitizedTitle = (_exam?['title'] ?? 'ujian').toString().replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = 'lembar_jawaban_${_currentExamId}_$sanitizedTitle.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('PDF Lembar Jawaban'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lembar jawaban A4 (berisi 4 fiducial marker & kotak jawaban) berhasil dibuat dan disimpan di HP:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_open, size: 16, color: Colors.indigo),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        file.path,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '💡 Anda dapat mencetak file ini di kertas A4 untuk dibagikan kepada siswa.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_currentExamId == null ? 'Buat Ujian Baru' : 'Kelola Soal Ujian'),
        actions: [
          if (_currentExamId != null) ...[
            IconButton(
              icon: _downloadingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf, color: Colors.indigo),
              tooltip: 'Download PDF Lembar Jawaban',
              onPressed: _downloadingPdf ? null : _downloadPdf,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Hapus Ujian',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Ujian?'),
                    content: const Text('Semua soal dan submission dalam ujian ini akan dihapus.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    await ApiClient.instance.deleteExam(_currentExamId!);
                    if (mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Ujian Info / Form
                      if (_currentExamId == null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('1. Informasi Ujian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              if (_classes.isEmpty)
                                const Text('Belum ada kelas. Tambahkan kelas terlebih dahulu!')
                              else
                                DropdownButtonFormField<int>(
                                  value: _selectedClassId,
                                  decoration: const InputDecoration(
                                    labelText: 'Kelas Tujuan',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _classes.map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text('${c['name']} (Tingkat ${c['grade_level']})'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedClassId = v),
                                ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Judul Ujian',
                                  hintText: 'mis. UTS Matematika Genap',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _totalScoreCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Total Bobot Nilai',
                                  hintText: '100',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _createExam,
                                child: const Text('Buat & Lanjut Tambah Soal'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Exam Info Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.assignment, color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _exam?['title'] ?? 'Ujian',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Total Skor: ${_exam?['total_score']} | Jumlah Soal: ${_questions.length}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_questions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFEEF2FF),
                                    foregroundColor: Colors.indigo,
                                  ),
                                  icon: _downloadingPdf
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.picture_as_pdf, size: 18),
                                  label: const Text('📄 Download PDF Lembar Jawaban (A4)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: _downloadingPdf ? null : _downloadPdf,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Soal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Soal (${_questions.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            FilledButton.icon(
                              onPressed: _showAddQuestionDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Tambah Soal'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_questions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.quiz_outlined, size: 48, color: Colors.black26),
                                const SizedBox(height: 8),
                                const Text(
                                  'Belum ada butir soal.',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tekan "+ Tambah Soal" untuk memasukkan kunci jawaban.',
                                  style: TextStyle(fontSize: 12, color: Colors.black38),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _questions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final q = _questions[i];
                              final qType = (q['type'] ?? 'mcq').toString();
                              Color typeColor = Colors.blue;
                              String typeLabel = 'MCQ';
                              if (qType == 'short') {
                                typeColor = Colors.green;
                                typeLabel = 'Isian';
                              } else if (qType == 'essay') {
                                typeColor = Colors.purple;
                                typeLabel = 'Esai';
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.indigo.withOpacity(0.1),
                                      child: Text(
                                        '${q['question_number']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  typeLabel,
                                                  style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Bobot: ${q['weight']}',
                                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Kunci: ${q['answer_key']}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      onPressed: () => _deleteQuestion(q['id'] as int),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
