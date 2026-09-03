import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  List<dynamic>? _classes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ApiClient.instance.getClasses();
      if (mounted) setState(() => _classes = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penugasan Kelas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiClient.instance.logout();
              if (mounted && context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : _classes == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _classes!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.black26),
                                SizedBox(height: 12),
                                Text(
                                  'Belum ada penugasan kelas',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Hubungi Administrator Sekolah untuk penugasan rombel dan mata pelajaran Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classes!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final c = _classes![i];
                            final subj = c['subject'] as String? ?? 'Umum';
                            final cName = c['name'] as String? ?? 'Kelas';
                            final displayTitle = cName.startsWith(subj) ? cName : '$subj — $cName';

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F4F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school, color: Color(0xFF0F766E)),
                                ),
                                title: Text(
                                  displayTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Rombel: $cName · Mapel: $subj',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                                onTap: () => Navigator.of(context).pushNamed('/exams', arguments: c['id']),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
