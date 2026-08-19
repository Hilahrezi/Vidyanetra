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

  Future<void> _showAddClassDialog() async {
    final nameCtrl = TextEditingController();
    final gradeCtrl = TextEditingController(text: '8');
    final subjectCtrl = TextEditingController(text: 'Matematika');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kelas Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  hintText: 'mis. Matematika, IPA, B. Indonesia',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kelas',
                  hintText: 'mis. 8A, 8B, 9A',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tingkat / Grade',
                  hintText: 'mis. 7, 8, 9',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || subjectCtrl.text.trim().isEmpty) {
                return;
              }
              try {
                await ApiClient.instance.createClass(
                  nameCtrl.text.trim(),
                  gradeCtrl.text.trim(),
                  subject: subjectCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Gagal menambah kelas: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (created == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelas Diampu'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClassDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kelas'),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _classes == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _classes!.isEmpty
                      ? const Center(child: Text('Belum ada kelas terdaftar.'))
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
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school, color: Colors.indigo),
                                ),
                                title: Text(
                                  displayTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Tingkat ${c['grade_level']} · Mapel: $subj',
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
