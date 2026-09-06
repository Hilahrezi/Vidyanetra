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
              Icon(Icons.dns, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Pengaturan Server Vidyanetra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Masukkan alamat base URL backend FastAPI:',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
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
                            testColor = Colors.teal[800];
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
                                testStatus = '✅ Terhubung! Server Vidyanetra aktif.';
                                testColor = Colors.green[800];
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
                              testStatus = '❌ Tidak dapat terhubung. Cek koneksi server.';
                              testColor = Colors.red[700];
                            });
                          }
                        },
                ),
                if (testStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    testStatus!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: testColor),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Preset Cepat:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
            icon: const Icon(Icons.tune_rounded),
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
                // Vidyanetra Brand Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/vidyanetra_logo.png',
                        height: 76,
                        width: 76,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vidyanetra',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Intelligent Academic Vision & Assessment',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Server: ${AppConfig.apiBase}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black38, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  decoration: InputDecoration(
                    labelText: 'Email Guru',
                    prefixIcon: const Icon(Icons.alternate_email, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Masuk ke Vidyanetra', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.settings_ethernet, size: 16),
                    label: const Text('Ubah Alamat Server', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
