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

  String get baseUrl => _dio.options.baseUrl;

  String photoUrl(int submissionId) => '${_dio.options.baseUrl}/photos/$submissionId';

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

  // Legacy PIN login (will be deprecated)
  Future<TokenPair> login({required int userId, required String pin}) async {
    final res = await _dio.post('/auth/login', data: {'user_id': userId, 'pin': pin});
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  // New Auth Methods
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
  }

  Future<void> verifyEmail(String token) async {
    await _dio.post('/auth/verify-email', data: {'token': token});
  }

  Future<TokenPair> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login/email', data: {
      'email': email,
      'password': password,
    });
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  Future<TokenPair> loginWithPin({
    required String familyCode,
    required String pin,
    int? userId,
  }) async {
    final data = <String, dynamic>{
      'family_code': familyCode,
      'pin': pin,
    };
    if (userId != null) {
      data['user_id'] = userId;
    }
    final res = await _dio.post('/auth/login/pin', data: data);
    return TokenPair(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String?,
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post('/auth/reset-password', data: {
      'token': token,
      'new_password': newPassword,
    });
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

  Future<List<dynamic>> fetchTasks() async {
    final res = await _dio.get('/tasks');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchTodayTasksForChild(int childId) async {
    final res = await _dio.get('/tasks/today', queryParameters: {'child_id': childId});
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> payload) async {
    final res = await _dio.post('/tasks', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTask(int taskId, Map<String, dynamic> payload) async {
    final res = await _dio.patch('/tasks/$taskId', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitTask({
    required int taskId,
    String? comment,
    String? photoPath,
    String? selectedDevice,
  }) async {
    final res = await _dio.post('/submissions', data: {
      'task_id': taskId,
      'comment': comment,
      'photo_path': photoPath,
      'selected_device': selectedDevice,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadPhoto({
    required int submissionId,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      '/photos/upload',
      queryParameters: {'submission_id': submissionId},
      data: form,
    );
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

  Future<List<dynamic>> fetchCompletedSubmissions({int? childId, int limit = 50}) async {
    final params = <String, dynamic>{'limit': limit};
    if (childId != null) params['child_id'] = childId;
    final res = await _dio.get('/submissions/completed', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> approveSubmission(
    int submissionId, {
    int? minutes,
    String? tanCode,
    String? validUntil,
    String? comment,
  }) async {
    final res = await _dio.post('/submissions/$submissionId/approve', data: {
      'minutes': minutes,
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

  Future<List<dynamic>> fetchLedgerEntries(int childId) async {
    final res = await _dio.get('/ledger/$childId');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPayout(Map<String, dynamic> payload) async {
    final res = await _dio.post('/ledger/payout', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markLedgerPaid(int entryId) async {
    final res = await _dio.post('/ledger/$entryId/mark-paid');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchUsers() async {
    final res = await _dio.get('/users');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchChildren() async {
    final res = await _dio.get('/users/children');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String role,
    required String pin,
  }) async {
    final res = await _dio.post('/users', data: {'name': name, 'role': role, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> payload) async {
    final res = await _dio.patch('/users/$userId', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deactivateUser(int userId) async {
    await _dio.patch('/users/$userId', data: {'is_active': false});
  }

  Future<void> registerPushToken({required String token, required String platform}) async {
    await _dio.post('/notifications/register', queryParameters: {'token': token, 'platform': platform});
  }

  // TAN Pool
  Future<Map<String, dynamic>> fetchTanPoolStats() async {
    final res = await _dio.get('/tan-pool/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchTanPool({bool availableOnly = false, String? targetDevice}) async {
    final params = <String, dynamic>{};
    if (availableOnly) params['available_only'] = true;
    if (targetDevice != null) params['target_device'] = targetDevice;
    final res = await _dio.get('/tan-pool/', queryParameters: params.isNotEmpty ? params : null);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> importTans(String rawText) async {
    final res = await _dio.post('/tan-pool/import', data: {'raw_text': rawText});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getNextAvailableTan(String targetDevice) async {
    final res = await _dio.get('/tan-pool/next', queryParameters: {'target_device': targetDevice});
    return res.data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> markTanUsed(int tanId, {int? childId}) async {
    final params = childId != null ? {'child_id': childId} : null;
    final res = await _dio.post('/tan-pool/$tanId/use', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteTan(int tanId) async {
    await _dio.delete('/tan-pool/$tanId');
  }

  // Stats
  Future<Map<String, dynamic>> fetchStatsOverview() async {
    final res = await _dio.get('/stats/overview');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchChildStats(int childId) async {
    final res = await _dio.get('/stats/child/$childId');
    return res.data as Map<String, dynamic>;
  }

  // Learning
  Future<List<dynamic>> fetchLearningSubjects() async {
    final res = await _dio.get('/learning/subjects');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchLearningDifficulties() async {
    final res = await _dio.get('/learning/difficulties');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> startLearningSession({
    required String subject,
    required String difficulty,
    int questionCount = 10,
  }) async {
    final res = await _dio.post('/learning/sessions', data: {
      'subject': subject,
      'difficulty': difficulty,
      'question_count': questionCount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLearningQuestion(int sessionId) async {
    final res = await _dio.get('/learning/sessions/$sessionId/question');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitLearningAnswer({
    required int sessionId,
    required int questionIndex,
    required String answer,
  }) async {
    final res = await _dio.post('/learning/sessions/$sessionId/answer', data: {
      'session_id': sessionId,
      'question_index': questionIndex,
      'answer': answer,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeLearningSession(int sessionId) async {
    final res = await _dio.post('/learning/sessions/$sessionId/complete');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchLearningProgress() async {
    final res = await _dio.get('/learning/progress');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchLearningHistory() async {
    final res = await _dio.get('/learning/history');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchChildLearningStats(int childId) async {
    final res = await _dio.get('/learning/stats/$childId');
    return res.data as Map<String, dynamic>;
  }

  // Achievements
  Future<List<dynamic>> fetchAchievements() async {
    final res = await _dio.get('/achievements');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> checkAchievements() async {
    final res = await _dio.get('/achievements/check');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchNewAchievements() async {
    final res = await _dio.get('/achievements/new');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchChildAchievements(int childId) async {
    final res = await _dio.get('/achievements/child/$childId');
    return res.data as List<dynamic>;
  }

  // Task Templates
  Future<List<dynamic>> fetchTaskTemplates() async {
    final res = await _dio.get('/templates');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTaskFromTemplate(int templateId, {
    required List<int> assignedChildren,
    Map<String, bool>? recurrence,
  }) async {
    // First get the template
    final templateRes = await _dio.get('/templates/$templateId');
    final template = templateRes.data as Map<String, dynamic>;

    // Create task from template
    final taskData = {
      'title': template['title'],
      'description': template['description'],
      'category': template['category'],
      'duration_minutes': template['duration_minutes'],
      'tan_reward': template['tan_reward'],
      'target_devices': template['target_devices'],
      'requires_photo': template['requires_photo'],
      'auto_approve': template['auto_approve'],
      'assigned_children': assignedChildren,
      'recurrence': recurrence,
    };

    final res = await _dio.post('/tasks', data: taskData);
    return res.data as Map<String, dynamic>;
  }

  // Family Management
  Future<Map<String, dynamic>> createFamily(String name) async {
    final res = await _dio.post('/families', data: {'name': name});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchFamilies() async {
    final res = await _dio.get('/families');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchFamily(int familyId) async {
    final res = await _dio.get('/families/$familyId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateFamily(int familyId, Map<String, dynamic> data) async {
    final res = await _dio.patch('/families/$familyId', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<String> generateInviteCode(int familyId) async {
    final res = await _dio.post('/families/$familyId/invite');
    return res.data['invite_code'] as String;
  }

  Future<Map<String, dynamic>> joinFamily(String inviteCode) async {
    final res = await _dio.post('/families/join', data: {'invite_code': inviteCode});
    return res.data as Map<String, dynamic>;
  }

  Future<void> leaveFamily(int familyId) async {
    await _dio.delete('/families/$familyId/leave');
  }

  Future<List<dynamic>> fetchFamilyMembers(int familyId) async {
    final res = await _dio.get('/families/$familyId/members');
    return res.data as List<dynamic>;
  }

  Future<void> removeFamilyMember(int familyId, int userId) async {
    await _dio.delete('/families/$familyId/members/$userId');
  }

  Future<Map<String, dynamic>> addChildToFamily(int familyId, {
    required String name,
    required String pin,
  }) async {
    final res = await _dio.post('/families/$familyId/children', data: {
      'name': name,
      'pin': pin,
    });
    return res.data as Map<String, dynamic>;
  }

  // Device Providers
  Future<List<dynamic>> fetchDeviceProviders(int familyId) async {
    final res = await _dio.get('/families/$familyId/devices');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> setDeviceProvider(
    int familyId,
    String deviceType,
    String providerType, {
    Map<String, dynamic>? settings,
  }) async {
    final res = await _dio.patch('/families/$familyId/devices/$deviceType', data: {
      'provider_type': providerType,
      if (settings != null) 'provider_settings': settings,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchAvailableProviders() async {
    final res = await _dio.get('/families/providers/available');
    return res.data as List<dynamic>;
  }

  // Family-scoped endpoints (add family_id parameter)
  Future<List<dynamic>> fetchTasksForFamily(int familyId, {int? childId}) async {
    final params = <String, dynamic>{'family_id': familyId};
    if (childId != null) params['child_id'] = childId;
    final res = await _dio.get('/tasks', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTaskInFamily(int familyId, Map<String, dynamic> payload) async {
    final res = await _dio.post('/tasks', queryParameters: {'family_id': familyId}, data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchTanPoolStatsForFamily(int familyId) async {
    final res = await _dio.get('/tan-pool/stats', queryParameters: {'family_id': familyId});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchTanPoolForFamily(int familyId, {bool availableOnly = false, String? targetDevice}) async {
    final params = <String, dynamic>{'family_id': familyId};
    if (availableOnly) params['available_only'] = true;
    if (targetDevice != null) params['target_device'] = targetDevice;
    final res = await _dio.get('/tan-pool/', queryParameters: params);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> importTansForFamily(int familyId, String rawText) async {
    final res = await _dio.post('/tan-pool/import', queryParameters: {'family_id': familyId}, data: {'raw_text': rawText});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getNextAvailableTanForFamily(int familyId, String targetDevice) async {
    final res = await _dio.get('/tan-pool/next', queryParameters: {'family_id': familyId, 'target_device': targetDevice});
    return res.data as Map<String, dynamic>?;
  }
}
