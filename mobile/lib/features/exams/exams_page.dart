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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ujian')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _exams == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _exams!.length,
                    itemBuilder: (context, i) {
                      final e = _exams![i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.assignment)),
                          title: Text(e['title']),
                          subtitle: Text('Total skor ${e['total_score']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context)
                              .pushNamed('/scan', arguments: e['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
