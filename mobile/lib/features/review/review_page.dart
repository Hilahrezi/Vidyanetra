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
        const SnackBar(content: Text('Submission difinalisasi')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Hasil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan & Finalisasi'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(data),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final details = (data['details'] as List).cast<Map<String, dynamic>>();
    final status = data['status'] as String;
    final total = data['total_score'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: Icon(status == 'finalized' ? Icons.check_circle : Icons.hourglass_top,
                color: status == 'finalized' ? Colors.green : Colors.orange),
            title: Text('Siswa: ${data['student_name'] ?? '-'}'),
            subtitle: Text('Status: $status${total != null ? '  |  Total: $total' : ''}'),
          ),
        ),
        if (status == 'pending' || status == 'grading')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 12),
                  Text(_progressLabel(details)),
                ],
              ),
            ),
          ),
        for (final d in details) _detailCard(d),
      ],
    );
  }

  String _progressLabel(List<Map<String, dynamic>> details) {
    final labels = {
      'mcq': 'pilihan ganda',
      'short': 'isian singkat',
      'essay': 'esai',
    };
    final pending = details
        .where((d) => d['status'] == 'pending')
        .map((d) => labels[d['type']] ?? 'soal')
        .toSet()
        .toList();
    return pending.isEmpty
        ? 'AI sedang mengevaluasi jawaban...'
        : 'Memeriksa ${pending.join(' & ')}...';
  }

  Widget _detailCard(Map<String, dynamic> d) {
    final qid = d['question_id'] as int;
    final score = (d['overridden_score'] as num?) ?? (d['similarity_score'] as num?) ?? 0;
    final effectiveScore = (_overrides[qid] ?? score.toDouble());
    final isOverridden = d['manual_override'] == true;
    final status = d['status'] as String;
    final imageUrl = d['image_url'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Soal ${d['question_number']}',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Chip(
                  label: Text(status),
                  backgroundColor: status == 'done'
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                ),
              ],
            ),
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl.startsWith('http') ? imageUrl : '${ApiClient.instance.dio.options.baseUrl}$imageUrl',
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('(gambar tidak tersedia)'),
                  ),
                ),
              ),
            Text('Hasil baca AI: ${d['student_answer_text'] ?? '-'}'),
            Text('Skor AI: ${d['similarity_score'] ?? '-'}  '
                '${d['is_correct'] == null ? '' : (d['is_correct'] == true ? '(benar)' : '(salah)')}'
                '${isOverridden ? '  [diubah guru]' : ''}'),
            if (d['ai_reasoning'] != null)
              Text('Alasan: ${d['ai_reasoning']}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Override: '),
                Expanded(
                  child: Slider(
                    value: effectiveScore,
                    max: 100,
                    divisions: 20,
                    label: effectiveScore.round().toString(),
                    onChanged: (v) => setState(() => _overrides[qid] = v),
                  ),
                ),
                Text(effectiveScore.round().toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
