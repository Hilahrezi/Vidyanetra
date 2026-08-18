/// Konfigurasi aplikasi. Base URL backend dioverride saat build:
/// flutter run --dart-define=API_BASE=http://192.168.1.5:8000
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8000', // emulator Android -> host localhost
  );
}
