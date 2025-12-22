import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/child_home_screen.dart';
import '../screens/child_task_detail_screen.dart';
import '../screens/parent_home_screen.dart';
import '../screens/role_select_screen.dart';
import '../screens/tan_pool_screen.dart';
import '../screens/task_editor_screen.dart';
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
        path: '/child/task',
        builder: (context, state) {
          final task = state.extra;
          if (task is! Map<String, dynamic>) {
            return const Scaffold(body: Center(child: Text('Keine Aufgabe gefunden')));
          }
          return ChildTaskDetailScreen(task: task);
        },
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentHomeScreen(),
      ),
      GoRoute(
        path: '/parent/task',
        builder: (context, state) {
          final task = state.extra;
          if (task != null && task is! Map<String, dynamic>) {
            return const Scaffold(body: Center(child: Text('Keine Aufgabe gefunden')));
          }
          return TaskEditorScreen(task: task as Map<String, dynamic>?);
        },
      ),
      GoRoute(
        path: '/parent/tan-pool',
        builder: (context, state) => const TanPoolScreen(),
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
