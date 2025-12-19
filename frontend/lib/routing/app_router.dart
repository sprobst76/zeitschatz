import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/child_home_screen.dart';
import '../screens/parent_inbox_screen.dart';
import '../screens/role_select_screen.dart';
import '../state/app_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role',
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
