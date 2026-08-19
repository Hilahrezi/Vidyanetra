import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Konfigurasi aplikasi. Base URL backend dioverride saat build atau diubah di runtime:
/// flutter run --dart-define=API_BASE=http://100.78.211.26:8000
class AppConfig {
  static const String defaultApiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://100.78.211.26:8000', // Default Tailscale PC
  );

  static const _storage = FlutterSecureStorage();
  static const _keyApiBase = 'custom_api_base';

  static String _currentApiBase = defaultApiBase;
  static String get apiBase => _currentApiBase;

  static Future<void> init() async {
    final saved = await _storage.read(key: _keyApiBase);
    if (saved != null && saved.trim().isNotEmpty) {
      _currentApiBase = saved.trim().replaceAll(RegExp(r'/+$'), '');
    }
  }

  static Future<void> setApiBase(String newUrl) async {
    _currentApiBase = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: _keyApiBase, value: _currentApiBase);
  }
}
