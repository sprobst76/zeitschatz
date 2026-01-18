import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/child_home_screen.dart';
import '../screens/child_task_detail_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/register_screen.dart';
import '../screens/onboarding/family_setup_screen.dart';
import '../screens/onboarding/child_login_screen.dart';
import '../screens/family/family_settings_screen.dart';
import '../screens/family/family_members_screen.dart';
import '../screens/family/device_providers_screen.dart';
import '../screens/family/add_child_screen.dart';
import '../screens/parent_home_screen.dart';
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
    initialLocation: '/welcome',
    refreshListenable: RouterRefreshStream(ref.watch(sessionProvider.notifier).stream),
    routes: [
      // Onboarding routes
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/family-setup',
        builder: (context, state) => const FamilySetupScreen(),
      ),
      GoRoute(
        path: '/child-login',
        builder: (context, state) => const ChildLoginScreen(),
      ),
      // Legacy role select - redirect to welcome
      GoRoute(
        path: '/role',
        redirect: (context, state) => '/welcome',
      ),
      // Child routes
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
      // Parent routes
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
      // Family management routes
      GoRoute(
        path: '/family/settings',
        builder: (context, state) => const FamilySettingsScreen(),
      ),
      GoRoute(
        path: '/family/members',
        builder: (context, state) => const FamilyMembersScreen(),
      ),
      GoRoute(
        path: '/family/devices',
        builder: (context, state) => const DeviceProvidersScreen(),
      ),
      GoRoute(
        path: '/family/add-child',
        builder: (context, state) => const AddChildScreen(),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final isAuth = session.isAuthenticated;
      final loc = state.matchedLocation;

      // Public routes that don't require auth
      const publicRoutes = ['/welcome', '/login', '/register', '/child-login', '/role'];

      if (!isAuth && !publicRoutes.contains(loc)) {
        return '/welcome';
      }

      // If authenticated but no family, redirect to family setup (except if already there)
      if (isAuth && !session.hasFamily && loc != '/family-setup' && session.role == 'parent') {
        return '/family-setup';
      }

      return null;
    },
  );
});
