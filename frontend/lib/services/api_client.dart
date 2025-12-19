import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({String baseUrl = 'http://localhost:8070', String? token})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, headers: token != null ? {'Authorization': 'Bearer $token'} : {}));

  Future<String> login({required int userId, required String pin}) async {
    final res = await _dio.post('/auth/login', data: {'user_id': userId, 'pin': pin});
    return res.data['access_token'] as String;
  }

  Future<List<dynamic>> fetchTasksForChild(int childId) async {
    final res = await _dio.get('/tasks', queryParameters: {'child_id': childId});
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> submitTask({required int taskId, String? comment, String? photoPath}) async {
    final res = await _dio.post('/submissions', data: {'task_id': taskId, 'comment': comment, 'photo_path': photoPath});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchPendingSubmissions() async {
    final res = await _dio.get('/submissions/pending');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> approveSubmission(
    int submissionId, {
    required int minutes,
    required String targetDevice,
    String? tanCode,
    String? validUntil,
    String? comment,
  }) async {
    final res = await _dio.post('/submissions/$submissionId/approve', data: {
      'minutes': minutes,
      'target_device': targetDevice,
      'tan_code': tanCode,
      'valid_until': validUntil,
      'comment': comment,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> retrySubmission(
    int submissionId, {
    String? comment,
  }) async {
    final res = await _dio.post('/submissions/$submissionId/retry', data: {
      'comment': comment,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> registerPushToken({required String token, required String platform}) async {
    await _dio.post('/notifications/register', queryParameters: {'token': token, 'platform': platform});
  }
}
