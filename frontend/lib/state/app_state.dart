import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionState {
  final String? token;
  final String role; // 'parent' | 'child'
  final int? userId;
  const SessionState({this.token, this.userId, this.role = 'guest'});

  SessionState copyWith({String? token, int? userId, String? role}) {
    return SessionState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      role: role ?? this.role,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setSession({required String token, required int userId, required String role}) {
    state = SessionState(token: token, userId: userId, role: role);
  }

  void clear() {
    state = const SessionState();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
