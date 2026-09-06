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
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'in_progress', 'completed'
  String _sortBy = 'newest'; // 'newest', 'oldest', 'az', 'za'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<dynamic> _getProcessedExams() {
    if (_exams == null) return [];
    var list = List<dynamic>.from(_exams!);

    // 1. Filter Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((e) {
        final title = (e['title'] as String? ?? '').toLowerCase();
        final subj = (e['subject'] as String? ?? '').toLowerCase();
        return title.contains(q) || subj.contains(q);
      }).toList();
    }

    // 2. Filter Status
    if (_filterStatus == 'completed') {
      list = list.where((e) {
        final subs = (e['submissions_count'] as num?)?.toInt() ?? 0;
        final total = (e['total_students'] as num?)?.toInt() ?? 0;
        return total > 0 && subs >= total;
      }).toList();
    } else if (_filterStatus == 'in_progress') {
      list = list.where((e) {
        final subs = (e['submissions_count'] as num?)?.toInt() ?? 0;
        final total = (e['total_students'] as num?)?.toInt() ?? 0;
        return total == 0 || subs < total;
      }).toList();
    }

    // 3. Sort
    list.sort((a, b) {
      if (_sortBy == 'newest') {
        final aId = (a['id'] as num?)?.toInt() ?? 0;
        final bId = (b['id'] as num?)?.toInt() ?? 0;
        return bId.compareTo(aId);
      } else if (_sortBy == 'oldest') {
        final aId = (a['id'] as num?)?.toInt() ?? 0;
        final bId = (b['id'] as num?)?.toInt() ?? 0;
        return aId.compareTo(bId);
      } else if (_sortBy == 'az') {
        final aTitle = (a['title'] as String? ?? '').toLowerCase();
        final bTitle = (b['title'] as String? ?? '').toLowerCase();
        return aTitle.compareTo(bTitle);
      } else if (_sortBy == 'za') {
        final aTitle = (a['title'] as String? ?? '').toLowerCase();
        final bTitle = (b['title'] as String? ?? '').toLowerCase();
        return bTitle.compareTo(aTitle);
      }
      return 0;
    });

    return list;
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
    final filteredExams = _getProcessedExams();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Ujian Kelas'),
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
              : Column(
                  children: [
                    // Search & Sort Bar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama ujian atau mapel...',
                                    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0F766E)),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              setState(() {
                                                _searchController.clear();
                                                _searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort Menu Button
                              PopupMenuButton<String>(
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.sort, color: Color(0xFF0F766E), size: 20),
                                ),
                                tooltip: 'Urutkan Ujian',
                                onSelected: (val) => setState(() => _sortBy = val),
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'newest',
                                    child: Row(
                                      children: [
                                        Icon(Icons.schedule, size: 16, color: _sortBy == 'newest' ? const Color(0xFF0F766E) : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('Terbaru (Default)', style: TextStyle(fontWeight: _sortBy == 'newest' ? FontWeight.bold : FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'oldest',
                                    child: Row(
                                      children: [
                                        Icon(Icons.history, size: 16, color: _sortBy == 'oldest' ? const Color(0xFF0F766E) : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('Terlama', style: TextStyle(fontWeight: _sortBy == 'oldest' ? FontWeight.bold : FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'az',
                                    child: Row(
                                      children: [
                                        Icon(Icons.sort_by_alpha, size: 16, color: _sortBy == 'az' ? const Color(0xFF0F766E) : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('Judul (A-Z)', style: TextStyle(fontWeight: _sortBy == 'az' ? FontWeight.bold : FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'za',
                                    child: Row(
                                      children: [
                                        Icon(Icons.sort_by_alpha, size: 16, color: _sortBy == 'za' ? const Color(0xFF0F766E) : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('Judul (Z-A)', style: TextStyle(fontWeight: _sortBy == 'za' ? FontWeight.bold : FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Status Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Semua Ujian'),
                                  selected: _filterStatus == 'all',
                                  onSelected: (_) => setState(() => _filterStatus = 'all'),
                                  selectedColor: const Color(0xFFE6F4F1),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _filterStatus == 'all' ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Belum Selesai'),
                                  selected: _filterStatus == 'in_progress',
                                  onSelected: (_) => setState(() => _filterStatus = 'in_progress'),
                                  selectedColor: const Color(0xFFFEF3C7),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _filterStatus == 'in_progress' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Selesai Dinilai'),
                                  selected: _filterStatus == 'completed',
                                  onSelected: (_) => setState(() => _filterStatus = 'completed'),
                                  selectedColor: const Color(0xFFDCFCE7),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _filterStatus == 'completed' ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    // Exam List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filteredExams.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.search_off_rounded, size: 48, color: Colors.black26),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty || _filterStatus != 'all'
                                            ? 'Tidak ada ujian yang cocok dengan filter'
                                            : 'Belum ada ujian di kelas ini',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchQuery.isNotEmpty || _filterStatus != 'all'
                                            ? 'Coba ubah kata kunci pencarian atau reset filter status.'
                                            : 'Tekan tombol "+ Buat Ujian Baru" untuk membuat asesmen.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredExams.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final e = filteredExams[i];
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
                    ),
                  ],
                ),
    );
  }
}
