import 'package:flutter_test/flutter_test.dart';
import 'package:zeitschatz/state/app_state.dart';

void main() {
  test('SessionNotifier sets and clears session', () {
    final notifier = SessionNotifier();
    expect(notifier.state.token, isNull);
    notifier.setSession(token: 'abc', refreshToken: 'rt1', userId: 1, role: 'parent');
    expect(notifier.state.token, 'abc');
    expect(notifier.state.refreshToken, 'rt1');
    expect(notifier.state.userId, 1);
    expect(notifier.state.role, 'parent');
    notifier.updateTokens(token: 'def', refreshToken: 'rt2');
    expect(notifier.state.token, 'def');
    expect(notifier.state.refreshToken, 'rt2');
    notifier.clear();
    expect(notifier.state.token, isNull);
    expect(notifier.state.role, 'guest');
  });
}
