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
  SessionNotifier() : super(const SessionState());

  void setSession({
    required String token,
    String? refreshToken,
    required int userId,
    required String role,
    int? familyId,
    String? familyName,
    String? userName,
    String? email,
  }) {
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
  }

  void updateTokens({required String token, String? refreshToken}) {
    state = state.copyWith(token: token, refreshToken: refreshToken ?? state.refreshToken);
  }

  void setFamily({required int familyId, required String familyName}) {
    state = state.copyWith(familyId: familyId, familyName: familyName);
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
