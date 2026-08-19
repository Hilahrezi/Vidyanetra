import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Map<String, dynamic>? _teacher;
  List<dynamic>? _classes;
  List<dynamic>? _exams;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiClient.instance.getMe().catchError((_) => <String, dynamic>{'name': 'Guru', 'email': 'guru@sekolah.id', 'role': 'teacher'}),
        ApiClient.instance.getClasses(),
        ApiClient.instance.getExams(),
      ]);

      if (mounted) {
        setState(() {
          _teacher = results[0] as Map<String, dynamic>;
          _classes = results[1] as List<dynamic>;
          _exams = results[2] as List<dynamic>;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data dashboard: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddClassDialog() async {
    final nameCtrl = TextEditingController();
    final gradeCtrl = TextEditingController(text: '8');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kelas Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'mis. Kelas 8A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gradeCtrl,
              decoration: const InputDecoration(
                labelText: 'Tingkat / Grade',
                hintText: 'mis. 8',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.createClass(nameCtrl.text.trim(), gradeCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Gagal menambah kelas: $e')));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (created == true) {
      _loadDashboardData();
    }
  }

  void _showSelectExamForScan() {
    if (_exams == null || _exams!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada ujian. Buat ujian terlebih dahulu!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Pilih Ujian untuk Di-Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _exams!.length,
                itemBuilder: (context, i) {
                  final e = _exams![i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(e['title'] ?? 'Ujian'),
                      subtitle: Text('Total Skor: ${e['total_score']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed('/scan', arguments: e['id']);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectExamForAnalytics() {
    if (_exams == null || _exams!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada ujian yang dibuat.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: Colors.amber),
                SizedBox(width: 8),
                Text('Pilih Ujian untuk Analitik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _exams!.length,
                itemBuilder: (context, i) {
                  final e = _exams![i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(e['title'] ?? 'Ujian'),
                      subtitle: Text('Total Skor: ${e['total_score']}'),
                      trailing: const Icon(Icons.analytics, color: Colors.amber),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed('/analytics', arguments: e['id']);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = _teacher?['name'] ?? 'Guru';
    final teacherEmail = _teacher?['email'] ?? 'guru@sekolah.id';
    final initials = teacherName.isNotEmpty ? teacherName.substring(0, 1).toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dashboard Guru', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Keluar',
            onPressed: () async {
              await ApiClient.instance.logout();
              if (mounted && context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadDashboardData, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Teacher Profile Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                child: Text(
                                  initials,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacherName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      teacherEmail,
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Pengajar Aktif',
                                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. Quick Actions Header
                        const Text(
                          'Aksi Cepat',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 12),

                        // 3 Quick Action Cards Grid
                        Row(
                          children: [
                            // Action 1: Scan
                            Expanded(
                              child: _buildActionCard(
                                title: 'Scan Ujian',
                                subtitle: 'Koreksi Lembar',
                                icon: Icons.camera_alt,
                                color: const Color(0xFF4F46E5),
                                bgColor: const Color(0xFFEEF2FF),
                                onTap: _showSelectExamForScan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Action 2: Buat Soal
                            Expanded(
                              child: _buildActionCard(
                                title: 'Buat Ujian',
                                subtitle: 'Susun Soal',
                                icon: Icons.edit_note,
                                color: const Color(0xFF059669),
                                bgColor: const Color(0xFFECFDF5),
                                onTap: () async {
                                  final res = await Navigator.of(context).pushNamed('/exam-editor');
                                  if (res == true) _loadDashboardData();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Action 3: Analitik
                            Expanded(
                              child: _buildActionCard(
                                title: 'Analitik',
                                subtitle: 'Statistik Nilai',
                                icon: Icons.insights,
                                color: const Color(0xFFD97706),
                                bgColor: const Color(0xFFFEF3C7),
                                onTap: _showSelectExamForAnalytics,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 3. Classes Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kelas yang Diampu (${_classes?.length ?? 0})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            TextButton.icon(
                              onPressed: _showAddClassDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_classes == null || _classes!.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Center(
                              child: Text('Belum ada kelas. Klik "+ Tambah" untuk membuat kelas.'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _classes!.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final c = _classes![i];
                                return InkWell(
                                  onTap: () => Navigator.of(context).pushNamed('/exams', arguments: c['id']),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 150,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.school, size: 20, color: Colors.indigo),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          c['name'] ?? 'Kelas',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Tingkat ${c['grade_level']}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),

                        // 4. Daftar Ujian Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Ujian Aktif (${_exams?.length ?? 0})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            TextButton(
                              onPressed: () async {
                                final res = await Navigator.of(context).pushNamed('/exam-editor');
                                if (res == true) _loadDashboardData();
                              },
                              child: const Text('Buat Baru'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_exams == null || _exams!.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Center(
                              child: Text('Belum ada ujian. Tekan "Buat Baru" untuk menyusun ujian & soal.'),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _exams!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final e = _exams![i];
                              final className = e['class_name'] as String? ?? 'Kelas #${e['class_id']}';
                              final subject = e['subject'] as String? ?? (className.contains(' — ') ? className.split(' — ')[0] : 'Mata Pelajaran');
                              final cleanClass = className.contains(' — ') ? className.split(' — ')[1] : className;
                              final totalStudents = (e['total_students'] as int?) ?? 1;
                              final finalized = (e['finalized_count'] as int?) ?? 0;
                              final progressPct = (finalized / (totalStudents > 0 ? totalStudents : 1) * 100).clamp(0, 100).toInt();

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badges
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFC7D2FE)),
                                          ),
                                          child: Text(
                                            '📚 $subject',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0F9FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFBAE6FD)),
                                          ),
                                          child: Text(
                                            '🏫 $cleanClass',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.assignment, color: Colors.indigo, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e['title'] ?? 'Ujian',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Total Bobot: ${e['total_score']} pt · Peserta: ${e['total_students'] ?? '-'} Siswa',
                                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Progress Bar Koreksi
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Progres Koreksi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
                                              Text('$finalized/${e['total_students'] ?? 0} Siswa ($progressPct%)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progressPct / 100,
                                              minHeight: 5,
                                              backgroundColor: const Color(0xFFE2E8F0),
                                              color: progressPct == 100 ? Colors.green : Colors.indigo,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                          ),
                                          icon: const Icon(Icons.edit_note, size: 16),
                                          label: const Text('Kelola Soal', style: TextStyle(fontSize: 11)),
                                          onPressed: () async {
                                            final res = await Navigator.of(context).pushNamed(
                                              '/exam-editor',
                                              arguments: e['id'],
                                            );
                                            if (res == true) _loadDashboardData();
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            foregroundColor: Colors.amber[800],
                                          ),
                                          icon: const Icon(Icons.insights, size: 16),
                                          label: const Text('Analitik', style: TextStyle(fontSize: 11)),
                                          onPressed: () => Navigator.of(context).pushNamed('/analytics', arguments: e['id']),
                                        ),
                                        const SizedBox(width: 6),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            backgroundColor: Colors.indigo,
                                          ),
                                          icon: const Icon(Icons.camera_alt, size: 16),
                                          label: const Text('Scan', style: TextStyle(fontSize: 11)),
                                          onPressed: () => Navigator.of(context).pushNamed('/scan', arguments: e['id']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
