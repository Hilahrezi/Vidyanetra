import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'guru@sekolah.id');
  final _password = TextEditingController(text: 'rahasia123');
  bool _loading = false;
  String? _error;

  Future<void> _showServerSettingsDialog() async {
    final controller = TextEditingController(text: AppConfig.apiBase);
    String? testStatus;
    Color? testColor;
    bool testing = false;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dns, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Pengaturan Server'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Masukkan alamat base URL backend FastAPI:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'http://100.78.211.26:8000',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: testing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check, size: 16),
                  label: const Text('Tes Koneksi ke Server', style: TextStyle(fontSize: 12)),
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() {
                            testing = true;
                            testStatus = 'Menghubungi server...';
                            testColor = Colors.blue;
                          });
                          final rawUrl = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                          try {
                            final dio = Dio(BaseOptions(
                              connectTimeout: const Duration(seconds: 3),
                              receiveTimeout: const Duration(seconds: 3),
                            ));
                            final resp = await dio.get('$rawUrl/health');
                            if (resp.statusCode == 200) {
                              setDialogState(() {
                                testing = false;
                                testStatus = '✅ Terhubung! Server aktif.';
                                testColor = Colors.green[700];
                              });
                            } else {
                              setDialogState(() {
                                testing = false;
                                testStatus = '⚠️ Respons server (${resp.statusCode}).';
                                testColor = Colors.orange[800];
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              testing = false;
                              testStatus = '❌ Tidak dapat terhubung. Cek Tailscale & Firewall.';
                              testColor = Colors.red[700];
                            });
                          }
                        },
                ),
                if (testStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    testStatus!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: testColor),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Preset Cepat:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Tailscale (100.78.211.26)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = 'http://100.78.211.26:8000';
                          testStatus = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('ADB USB (127.0.0.1)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = 'http://127.0.0.1:8000';
                          testStatus = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = 'http://10.0.2.2:8000';
                          testStatus = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      await AppConfig.setApiBase(selected);
      ApiClient.instance.updateBaseUrl(AppConfig.apiBase);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server URL diubah ke: ${AppConfig.apiBase}')),
        );
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan Server',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.assignment_turned_in, size: 64, color: Colors.indigo),
                const SizedBox(height: 8),
                Text('AutoGrading', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Server: ${AppConfig.apiBase}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.person)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Masuk'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Ubah Alamat Server', style: TextStyle(fontSize: 12)),
                    onPressed: _showServerSettingsDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
