import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class ReviewPage extends StatefulWidget {
  final int submissionId;
  const ReviewPage({super.key, required this.submissionId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _saving = false;
  final Map<int, double> _overrides = {}; // question_id -> skor

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    while (mounted) {
      try {
        final data = await ApiClient.instance.getSubmissionDetails(widget.submissionId);
        if (!mounted) return;
        setState(() => _data = data);
        final status = data['status'] as String;
        if (status == 'graded' || status == 'finalized') return;
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
        return;
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_overrides.isNotEmpty) {
        await ApiClient.instance.review(widget.submissionId, [
          for (final e in _overrides.entries)
            {'question_id': e.key, 'overridden_score': e.value},
        ]);
      }
      await ApiClient.instance.finalize(widget.submissionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Hasil evaluasi siswa berhasil difinalisasi!'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushNamed('/classes');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final status = data?['status'] as String?;
    final isFinalized = status == 'finalized';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Hasil Evaluasi AI'),
        actions: [
          if (!isFinalized)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: _saving
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Finalisasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
          : data == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
              : _buildBody(data),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final details = (data['details'] as List).cast<Map<String, dynamic>>();
    final status = data['status'] as String;
    final total = data['total_score'];
    final studentName = data['student_name'] as String? ?? 'Siswa';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCCFBF1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Color(0xFF0F766E), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: status == 'finalized'
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: status == 'finalized' ? const Color(0xFF86EFAC) : const Color(0xFFFDE047),
                            ),
                          ),
                          child: Text(
                            status == 'finalized' ? '✓ Final' : '⏳ Terkoreksi AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'finalized' ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        if (total != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Total Skor: $total pt',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // AI Processing Banner if grading
        if (status == 'pending' || status == 'grading')
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _progressLabel(details),
                    style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Question Details Feed
        for (final d in details) _detailCard(d),
      ],
    );
  }

  String _progressLabel(List<Map<String, dynamic>> details) {
    final labels = {
      'mcq': 'Pilihan Ganda',
      'short': 'Isian Singkat',
      'essay': 'Esai',
    };
    final pending = details
        .where((d) => d['status'] == 'pending')
        .map((d) => labels[d['type']] ?? 'soal')
        .toSet()
        .toList();
    return pending.isEmpty
        ? 'AI sedang menganalisis semantik jawaban...'
        : 'Mengevaluasi ${pending.join(' & ')}...';
  }

  Widget _detailCard(Map<String, dynamic> d) {
    final qid = d['question_id'] as int;
    final score = (d['overridden_score'] as num?) ?? (d['similarity_score'] as num?) ?? 0;
    final effectiveScore = (_overrides[qid] ?? score.toDouble());
    final isOverridden = d['manual_override'] == true || _overrides.containsKey(qid);
    final imageUrl = d['image_url'] as String? ?? '';
    final qType = (d['type'] ?? 'mcq').toString();

    // Semantic Color Threshold
    Color badgeColor = const Color(0xFF16A34A); // Green >= 85
    String badgeText = 'Sangat Sesuai (>85%)';
    if (effectiveScore < 50) {
      badgeColor = const Color(0xFFE11D48);
      badgeText = 'Kurang Sesuai (<50%)';
    } else if (effectiveScore < 85) {
      badgeColor = const Color(0xFFF59E0B);
      badgeText = 'Perlu Cek Guru (50–84%)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF0F766E),
                  child: Text(
                    '${d['question_number']}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  qType == 'mcq'
                      ? 'Pilihan Ganda'
                      : qType == 'short'
                          ? 'Isian Singkat'
                          : 'Esai',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Original Handwriting Crop Thumbnail
                if (imageUrl.isNotEmpty) ...[
                  const Text('1. Potongan Tulisan Tangan Siswa:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl.startsWith('http')
                            ? imageUrl
                            : '${ApiClient.instance.dio.options.baseUrl}$imageUrl',
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('(Citra crop tidak tersedia)', style: TextStyle(fontSize: 11, color: Colors.black38)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Extracted Text & Teacher Key
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📝 Teks Ekstraksi AI:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                      const SizedBox(height: 2),
                      Text(
                        d['student_answer_text'] ?? '(Kosong / tidak terbaca)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (d['answer_key'] != null) ...[
                        const SizedBox(height: 8),
                        const Text('🔑 Kunci Jawaban Guru:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                        const SizedBox(height: 2),
                        Text(
                          d['answer_key'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. AI Reasoning
                if (d['ai_reasoning'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            'Alasan AI: ${d['ai_reasoning']}',
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4. Interactive Score Override Slider
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Skor Kemiripan Semantik:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Row(
                      children: [
                        Text(
                          '${effectiveScore.round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F766E)),
                        ),
                        if (isOverridden) ...[
                          const SizedBox(width: 4),
                          const Text('(diubah)', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ],
                ),
                Slider(
                  value: effectiveScore,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFF0F766E),
                  inactiveColor: const Color(0xFFE2E8F0),
                  onChanged: (v) => setState(() => _overrides[qid] = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
