import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';

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
  const SessionState({this.token, this.refreshToken, this.userId, this.role = 'guest'});

  SessionState copyWith({String? token, String? refreshToken, int? userId, String? role}) {
    return SessionState(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      role: role ?? this.role,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setSession({required String token, String? refreshToken, required int userId, required String role}) {
    state = SessionState(token: token, refreshToken: refreshToken, userId: userId, role: role);
  }

  void updateTokens({required String token, String? refreshToken}) {
    state = state.copyWith(token: token, refreshToken: refreshToken ?? state.refreshToken);
  }

  void clear() {
    state = const SessionState();
  }
}

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
