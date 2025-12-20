import 'package:dio/dio.dart';

class TokenPair {
  final String accessToken;
  final String? refreshToken;

  const TokenPair({required this.accessToken, this.refreshToken});
}

class ApiClient {
  final Dio _dio;
  final Dio _refreshDio;
  String? _refreshToken;
  final Future<void> Function(TokenPair tokens)? _onRefresh;
  final void Function()? _onUnauthorized;

  ApiClient({
    String baseUrl = 'http://192.168.0.144:8070',
    String? token,
    String? refreshToken,
    Future<void> Function(TokenPair tokens)? onRefresh,
    void Function()? onUnauthorized,
  })  : _refreshToken = refreshToken,
        _onRefresh = onRefresh,
        _onUnauthorized = onUnauthorized,
        _dio = Dio(BaseOptions(baseUrl: baseUrl, headers: token != null ? {'Authorization': 'Bearer $token'} : {})),
        _refreshDio = Dio(BaseOptions(baseUrl: baseUrl)) {
    if (_refreshToken != null && _onRefresh != null) {
      _dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 && error.requestOptions.extra['retried'] != true) {
          try {
            final tokens = await _refreshWithToken(_refreshToken!);
            _refreshToken = tokens.refreshToken ?? _refreshToken;
            await _onRefresh!(tokens);
            error.requestOptions.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
            error.requestOptions.extra['retried'] = true;
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (_) {
            _onUnauthorized?.call();
            return handler.next(error);
          }
        }
        return handler.next(error);
      }));
    }
  }

  Future<TokenPair> login({required int userId, required String pin}) async {
    final res = await _dio.post('/auth/login', data: {'user_id': userId, 'pin': pin});
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  Future<TokenPair> refresh({required String refreshToken}) async {
    final res = await _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  Future<TokenPair> _refreshWithToken(String refreshToken) async {
    final res = await _refreshDio.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  Future<List<dynamic>> fetchTasksForChild(int childId) async {
    final res = await _dio.get('/tasks', queryParameters: {'child_id': childId});
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchTodayTasksForChild(int childId) async {
    final res = await _dio.get('/tasks/today', queryParameters: {'child_id': childId});
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

  Future<List<dynamic>> fetchSubmissionHistory({int? childId}) async {
    final res = await _dio.get('/submissions/history', queryParameters: childId != null ? {'child_id': childId} : null);
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

  Future<List<dynamic>> fetchLedgerAggregate({int? childId}) async {
    final res = await _dio.get('/ledger/aggregate', queryParameters: childId != null ? {'child_id': childId} : null);
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchMyLedger() async {
    final res = await _dio.get('/ledger/my');
    return res.data as List<dynamic>;
  }

  Future<void> registerPushToken({required String token, required String platform}) async {
    await _dio.post('/notifications/register', queryParameters: {'token': token, 'platform': platform});
  }
}
