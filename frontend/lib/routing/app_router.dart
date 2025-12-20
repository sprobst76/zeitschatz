import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/child_home_screen.dart';
import '../screens/ledger_aggregate_screen.dart';
import '../screens/parent_history_screen.dart';
import '../screens/parent_inbox_screen.dart';
import '../screens/role_select_screen.dart';
import '../state/app_state.dart';

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role',
    refreshListenable: RouterRefreshStream(ref.watch(sessionProvider.notifier).stream),
    routes: [
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/child',
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentInboxScreen(),
      ),
      GoRoute(
        path: '/parent/history',
        builder: (context, state) => const ParentHistoryScreen(),
      ),
      GoRoute(
        path: '/parent/ledger-aggregate',
        builder: (context, state) => const LedgerAggregateScreen(),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final isAuth = session.token != null;
      if (!isAuth && state.matchedLocation != '/role') {
        return '/role';
      }
      return null;
    },
  );
});
