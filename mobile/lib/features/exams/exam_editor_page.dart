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

  // New exam form controller
  final _titleCtrl = TextEditingController(text: 'Ujian Baru');
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
        const SnackBar(content: Text('Isi judul ujian dan pilih penugasan kelas')),
      );
      return;
    }

    final selectedClass = _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => null,
    );
    final subject = selectedClass?['subject'] as String? ?? 'Umum';

    try {
      final res = await ApiClient.instance.createExam(
        _selectedClassId!,
        _titleCtrl.text.trim(),
        subject: subject,
        totalScore: 0,
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

    final nextNumber = _questions.length + 1;
    String selectedType = 'mcq';
    final weightCtrl = TextEditingController(text: '5');
    String selectedMcqKey = 'A';
    final answerKeyCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tambah Butir Soal #$nextNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Soal',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mcq', child: Text('Pilihan Ganda (MCQ A-D)')),
                    DropdownMenuItem(value: 'short', child: Text('Isian Singkat (Kata / Angka)')),
                    DropdownMenuItem(value: 'essay', child: Text('Esai / Uraian')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        selectedType = v;
                        if (v == 'mcq') {
                          weightCtrl.text = '5';
                        } else if (v == 'short') {
                          weightCtrl.text = '10';
                        } else if (v == 'essay') {
                          weightCtrl.text = '20';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bobot Nilai (Poin)',
                    hintText: 'mis. 5, 10, 20',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                if (selectedType == 'mcq') ...[
                  const Text('Kunci Jawaban Pilihan Ganda:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = selectedMcqKey == opt;
                      return ChoiceChip(
                        label: Text(opt, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: Colors.indigo,
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedMcqKey = opt);
                        },
                      );
                    }).toList(),
                  ),
                ] else if (selectedType == 'short') ...[
                  TextField(
                    controller: answerKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kunci Jawaban Singkat',
                      hintText: 'mis. fotosintesis | reaksi fotosintesis (pisahkan opsi dengan |)',
                      border: OutlineInputBorder(),
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
                    final key = selectedType == 'mcq' ? selectedMcqKey : answerKeyCtrl.text.trim();
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

  Future<void> _showEditQuestionDialog(dynamic q) async {
    final qId = q['id'] as int;
    final qNumber = q['question_number'] as int;
    String selectedType = (q['type'] ?? 'mcq').toString();
    final weightCtrl = TextEditingController(text: '${q['weight']}');
    String selectedMcqKey = selectedType == 'mcq' ? (q['answer_key'] ?? 'A').toString().toUpperCase() : 'A';
    final answerKeyCtrl = TextEditingController(text: selectedType != 'mcq' ? (q['answer_key'] ?? '') : '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Butir Soal #$qNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Soal',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mcq', child: Text('Pilihan Ganda (MCQ A-D)')),
                    DropdownMenuItem(value: 'short', child: Text('Isian Singkat (Kata / Angka)')),
                    DropdownMenuItem(value: 'essay', child: Text('Esai / Uraian')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        selectedType = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bobot Nilai (Poin)',
                    hintText: 'mis. 5, 10, 20',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                if (selectedType == 'mcq') ...[
                  const Text('Kunci Jawaban Pilihan Ganda:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = selectedMcqKey == opt;
                      return ChoiceChip(
                        label: Text(opt, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: Colors.indigo,
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedMcqKey = opt);
                        },
                      );
                    }).toList(),
                  ),
                ] else if (selectedType == 'short') ...[
                  TextField(
                    controller: answerKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kunci Jawaban Singkat',
                      hintText: 'mis. fotosintesis | reaksi fotosintesis (pisahkan opsi dengan |)',
                      border: OutlineInputBorder(),
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
                    final key = selectedType == 'mcq' ? selectedMcqKey : answerKeyCtrl.text.trim();
                    if (key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kunci jawaban wajib diisi!')),
                      );
                      return;
                    }
                    final weight = double.tryParse(weightCtrl.text) ?? 10.0;

                    try {
                      await ApiClient.instance.updateQuestion(
                        qId,
                        qNumber,
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
                  child: const Text('Simpan Perubahan'),
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
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir != null) {
        final filePath = '${dir.path}/lembar_jawaban_exam_${_currentExamId}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF Lembar Jawaban disimpan di:\n$filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal men-download PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedClass = _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => null,
    );
    final currentSubject = selectedClass?['subject'] as String? ?? 'Umum';

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentExamId == null ? 'Buat Ujian Baru' : (_exam?['title'] ?? 'Edit Soal Ujian')),
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
                      if (_currentExamId == null) ...[
                        // Form Create Exam
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
                              const Text('1. Informasi Ujian & Penugasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              if (_classes.isEmpty)
                                const Text('Belum ada penugasan kelas dari Administrator.')
                              else ...[
                                DropdownButtonFormField<int>(
                                  value: _selectedClassId,
                                  decoration: const InputDecoration(
                                    labelText: 'Pilih Penugasan Kelas',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _classes.map((c) {
                                    final subj = c['subject'] ?? 'Umum';
                                    final cName = c['name'] ?? 'Kelas';
                                    return DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text('$cName — $subj'),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedClassId = v;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F4F1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCCFBF1)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF0F766E)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Mata Pelajaran: $currentSubject (Sesuai penugasan Admin)',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Judul Ujian',
                                    hintText: 'mis. Ulangan Harian Dinamika Gerak',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _createExam,
                                  child: const Text('Buat & Lanjut Tambah Soal'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Exam Info Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE6F4F1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.assignment, color: Color(0xFF0F766E)),
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
                                          'Total Skor: ${_questions.fold<double>(0, (sum, q) => sum + ((q['weight'] as num?) ?? 0)).toInt()} pt (Akumulasi ${_questions.length} Butir Soal)',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
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
                                    backgroundColor: const Color(0xFFE6F4F1),
                                    foregroundColor: const Color(0xFF0F766E),
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
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.indigo),
                                      tooltip: 'Edit Soal',
                                      onPressed: () => _showEditQuestionDialog(q),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      tooltip: 'Hapus Soal',
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
