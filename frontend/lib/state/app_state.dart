import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';

// Theme State
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  void setTheme(ThemeMode mode) {
    state = mode;
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class SessionState {
  final String? token;
  final String? refreshToken;
  final String role; // 'parent' | 'child'
  final int? userId;
  final int? familyId;
  final String? familyName;
  final String? userName;
  final String? email;

  const SessionState({
    this.token,
    this.refreshToken,
    this.userId,
    this.role = 'guest',
    this.familyId,
    this.familyName,
    this.userName,
    this.email,
  });

  bool get isAuthenticated => token != null;
  bool get hasFamily => familyId != null;

  SessionState copyWith({
    String? token,
    String? refreshToken,
    int? userId,
    String? role,
    int? familyId,
    String? familyName,
    String? userName,
    String? email,
  }) {
    return SessionState(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      userName: userName ?? this.userName,
      email: email ?? this.email,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final SessionStorage _storage = SessionStorage();
  final _streamController = StreamController<SessionState>.broadcast();
  bool _initialized = false;

  SessionNotifier() : super(const SessionState());

  Stream<SessionState> get stream => _streamController.stream;

  /// Initialize session from storage (call on app start)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final savedSession = await _storage.loadSession();
    if (savedSession != null && savedSession['token'] != null) {
      state = SessionState(
        token: savedSession['token'],
        refreshToken: savedSession['refreshToken'],
        userId: savedSession['userId'],
        role: savedSession['role'] ?? 'guest',
        familyId: savedSession['familyId'],
        familyName: savedSession['familyName'],
        userName: savedSession['userName'],
        email: savedSession['email'],
      );
      _streamController.add(state);
    }
  }

  Future<void> setSession({
    required String token,
    String? refreshToken,
    required int userId,
    required String role,
    int? familyId,
    String? familyName,
    String? userName,
    String? email,
  }) async {
    state = SessionState(
      token: token,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
      familyId: familyId,
      familyName: familyName,
      userName: userName,
      email: email,
    );
    _streamController.add(state);

    // Persist to storage
    await _storage.saveSession(
      token: token,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
      familyId: familyId,
      familyName: familyName,
      userName: userName,
      email: email,
    );
  }

  Future<void> updateTokens({required String token, String? refreshToken}) async {
    state = state.copyWith(token: token, refreshToken: refreshToken ?? state.refreshToken);
    _streamController.add(state);
    await _storage.updateTokens(token: token, refreshToken: refreshToken);
  }

  Future<void> setFamily({required int familyId, required String familyName}) async {
    state = state.copyWith(familyId: familyId, familyName: familyName);
    _streamController.add(state);
    await _storage.updateFamily(familyId: familyId, familyName: familyName);
  }

  Future<void> clear() async {
    state = const SessionState();
    _streamController.add(state);
    await _storage.clearSession();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}

/// Provider for session storage (for biometric settings etc.)
final sessionStorageProvider = Provider((ref) => SessionStorage());

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

final apiClientProvider = Provider((ref) {
  final session = ref.watch(sessionProvider);
  final notifier = ref.read(sessionProvider.notifier);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    token: session.token,
    refreshToken: session.refreshToken,
    onRefresh: (tokens) async {
      notifier.updateTokens(token: tokens.accessToken, refreshToken: tokens.refreshToken);
    },
    onUnauthorized: () {
      notifier.clear();
    },
  );
});
