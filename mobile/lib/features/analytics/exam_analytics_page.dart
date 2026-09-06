import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class ExamAnalyticsPage extends StatefulWidget {
  final int examId;
  const ExamAnalyticsPage({super.key, required this.examId});

  @override
  State<ExamAnalyticsPage> createState() => _ExamAnalyticsPageState();
}

class _ExamAnalyticsPageState extends State<ExamAnalyticsPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _exam;
  List<dynamic> _submissions = [];
  Map<String, dynamic>? _distribution;
  Map<String, dynamic>? _difficulty;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiClient.instance.getExam(widget.examId),
        ApiClient.instance.getExamSubmissions(widget.examId),
        ApiClient.instance.getExamDistribution(widget.examId),
        ApiClient.instance.getQuestionDifficulty(widget.examId),
      ]);

      if (mounted) {
        setState(() {
          _exam = results[0] as Map<String, dynamic>;
          _submissions = results[1] as List<dynamic>;
          _distribution = results[2] as Map<String, dynamic>;
          _difficulty = results[3] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat analitik: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _exam?['title'] ?? 'Analitik Ujian';

    // Calculate Summary Stats
    final gradedSubs = _submissions.where((s) => s['total_score'] != null).toList();
    final scores = gradedSubs.map((s) => (s['total_score'] as num).toDouble()).toList();
    final avgScore = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
    final maxScore = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0.0;
    final minScore = scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0.0;
    final passCount = scores.where((s) => s >= 70.0).length;
    final passRate = scores.isNotEmpty ? (passCount / scores.length) * 100 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Distribusi'),
            Tab(text: 'Hasil Siswa'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Ringkasan & Kesulitan Soal
                    _buildSummaryTab(avgScore, maxScore, minScore, passRate, gradedSubs.length),

                    // Tab 2: Distribusi Nilai
                    _buildDistributionTab(),

                    // Tab 3: Hasil Siswa
                    _buildStudentResultsTab(),
                  ],
                ),
    );
  }

  Widget _buildSummaryTab(double avg, double max, double min, double passRate, int gradedCount) {
    final questions = (_difficulty?['questions'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4 Stat Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Rata-rata',
                    avg.toStringAsFixed(1),
                    Icons.speed,
                    Colors.indigo,
                    Colors.indigo.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Ketuntasan',
                    '${passRate.toStringAsFixed(0)}%',
                    Icons.check_circle_outline,
                    const Color(0xFF059669),
                    const Color(0xFFECFDF5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tertinggi',
                    max.toStringAsFixed(1),
                    Icons.trending_up,
                    Colors.teal,
                    Colors.teal.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Terendah',
                    min.toStringAsFixed(1),
                    Icons.trending_down,
                    Colors.deepOrange,
                    Colors.deepOrange.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section Kesulitan Soal
            const Text(
              'Tingkat Kesulitan Per Soal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            if (questions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: Text('Belum ada data evaluasi soal.')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final qNum = q['question_number'];
                  final qType = (q['type'] ?? 'mcq').toString().toUpperCase();
                  final avgScore = (q['average_score'] as num?)?.toDouble() ?? 0.0;

                  Color diffColor = Colors.green;
                  String diffLabel = 'Mudah';
                  if (avgScore < 50) {
                    diffColor = Colors.red;
                    diffLabel = 'Sulit';
                  } else if (avgScore < 75) {
                    diffColor = Colors.amber;
                    diffLabel = 'Sedang';
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Soal #$qNum ($qType)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: diffColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                diffLabel,
                                style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (avgScore / 100).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(diffColor),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rata-rata Skor: ${avgScore.toStringAsFixed(1)} / 100', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('Terkoreksi: ${q['attempted']} siswa', style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
    );
  }

  Widget _buildDistributionTab() {
    final buckets = (_distribution?['buckets'] as List<dynamic>?) ?? [];
    final total = (_distribution?['total'] as int?) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Histogram Distribusi Nilai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Total Terkoreksi: $total siswa', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 16),
                if (buckets.isEmpty)
                  const Center(child: Text('Belum ada data distribusi.'))
                else
                  Column(
                    children: buckets.map((b) {
                      final range = b['range'] ?? '';
                      final count = b['count'] as int? ?? 0;
                      final ratio = total > 0 ? (count / total) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 55,
                              child: Text(
                                range,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 14,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$count',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentResultsTab() {
    if (_submissions.isEmpty) {
      return const Center(child: Text('Belum ada lembar jawaban yang di-scan untuk ujian ini.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = _submissions[i];
        final name = s['student_name'] ?? 'Siswa';
        final noAbsen = s['student_number'] ?? '-';
        final score = s['total_score'];
        final status = s['status'] ?? 'pending';

        Color statusColor = Colors.orange;
        String statusLabel = 'Diproses';
        if (status == 'finalized') {
          statusColor = Colors.green;
          statusLabel = 'Final';
        } else if (status == 'graded') {
          statusColor = Colors.blue;
          statusLabel = 'Terkoreksi';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: Text(noAbsen, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: $statusLabel', style: TextStyle(fontSize: 12, color: statusColor)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score != null ? '${(score as num).toStringAsFixed(1)}' : '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.of(context).pushNamed('/review', arguments: s['id']);
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
