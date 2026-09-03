import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class ExamsPage extends StatefulWidget {
  final int classId;
  const ExamsPage({super.key, required this.classId});

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  List<dynamic>? _exams;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ApiClient.instance.getExams(classId: widget.classId);
      if (mounted) setState(() => _exams = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _deleteExam(int examId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Ujian?'),
        content: Text('Apakah Anda yakin ingin menghapus ujian "$title"? Semua butir soal dan data koreksi di dalamnya akan terhapus.'),
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
        await ApiClient.instance.deleteExam(examId);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ujian "$title" berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus ujian: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Ujian'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/exam_editor').then((_) => _load()),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Ujian Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _exams == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _exams!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_outlined, size: 48, color: Colors.black26),
                                SizedBox(height: 12),
                                Text(
                                  'Belum ada ujian di kelas ini',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tekan tombol "+ Buat Ujian Baru" untuk membuat asesmen dan menyusun butir soal.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _exams!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final e = _exams![i];
                            final subj = e['subject'] as String? ?? 'Umum';
                            final title = e['title'] as String? ?? 'Ujian';
                            final totalScore = e['total_score'] ?? 0;
                            final subsCount = e['submissions_count'] ?? 0;
                            final totalStudents = e['total_students'] ?? 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE6F4F1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFCCFBF1)),
                                                  ),
                                                  child: Text(
                                                    subj,
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F766E),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Total: $totalScore pt',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Koreksi: $subsCount / $totalStudents siswa ternilai',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => Navigator.of(context).pushNamed('/scan', arguments: e['id']).then((_) => _load()),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F766E),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.camera_alt, size: 16),
                                        label: const Text('Scan LJK'),
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => Navigator.of(context).pushNamed('/exam_editor', arguments: e['id']).then((_) => _load()),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0F766E),
                                              side: const BorderSide(color: Color(0xFFCCFBF1)),
                                              backgroundColor: const Color(0xFFE6F4F1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.edit, size: 14),
                                            label: const Text('Soal & PDF'),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            tooltip: 'Hapus Ujian',
                                            onPressed: () => _deleteExam(e['id'] as int, title),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
