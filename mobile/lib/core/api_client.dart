import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  String? _token;

  String? get token => _token;

  Dio get dio => _dio;

  Future<void> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<void> saveToken(String token) async {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> logout() async {
    _token = null;
    _dio.options.headers.remove('Authorization');
    await _storage.delete(key: _tokenKey);
  }

  /// Wrapper: terjemahkan error Dio menjadi ApiException yang ramah UI.
  Future<T> _guard<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final resp = await call();
      return resp.data as T;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? _friendly(e);
      throw ApiException(msg.toString());
    }
  }

  String _friendly(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi & base URL.';
      case DioExceptionType.badResponse:
        return 'Server error (${e.response?.statusCode}).';
      default:
        return 'Gagal terhubung: ${e.message}';
    }
  }

  // ---- Auth ----
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _guard(() => _dio.post('/auth/login', data: {'email': email, 'password': password}));
    await saveToken(data['access_token'] as String);
    return data['user'] as Map<String, dynamic>;
  }

  // ---- Master data ----
  Future<List<dynamic>> getClasses() => _guard<List<dynamic>>(() => _dio.get('/classes'));

  Future<dynamic> getExam(int examId) => _guard<dynamic>(() => _dio.get('/exams/$examId'));

  Future<List<dynamic>> getExams({int? classId}) => _guard<List<dynamic>>(
      () => _dio.get('/exams', queryParameters: {'class_id': ?classId}));

  Future<List<dynamic>> getQuestions(int examId) =>
      _guard<List<dynamic>>(() => _dio.get('/exams/$examId/questions'));

  Future<List<dynamic>> getStudents(int classId) =>
      _guard<List<dynamic>>(() => _dio.get('/classes/$classId/students'));

  // ---- Submission ----
  Future<Map<String, dynamic>> uploadCrops(
    int examId,
    int studentId,
    List<Map<String, dynamic>> crops, // [{question_number, image_base64, mcq_answer?, mcq_ambiguous}]
  ) async {
    final data = await _guard<dynamic>(() => _dio.post('/submissions/upload-crops', data: {
          'exam_id': examId,
          'student_id': studentId,
          'crops': crops,
        }));
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubmissionDetails(int submissionId) =>
      _guard<Map<String, dynamic>>(() => _dio.get('/submissions/$submissionId/details'));

  Future<void> review(int submissionId, List<Map<String, dynamic>> items) =>
      _guard<void>(() => _dio.put('/submissions/$submissionId/review', data: {'items': items}));

  Future<Map<String, dynamic>> finalize(int submissionId) =>
      _guard<Map<String, dynamic>>(() => _dio.post('/submissions/$submissionId/finalize'));
}
