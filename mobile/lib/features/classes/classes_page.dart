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
        title: const Text('Kelas Saya'),
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
          ? Center(child: Text(_error!))
          : _classes == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _classes!.length,
                    itemBuilder: (context, i) {
                      final c = _classes![i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.school)),
                          title: Text(c['name']),
                          subtitle: Text('Tingkat ${c['grade_level']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context)
                              .pushNamed('/exams', arguments: c['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
