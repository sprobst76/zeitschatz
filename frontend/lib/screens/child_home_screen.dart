import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import 'child_achievements_screen.dart';
import 'child_tan_screen.dart';
import 'child_tasks_screen.dart';
import 'learning_hub_screen.dart';

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  int _index = 0;

  final _pages = const [
    ChildTasksScreen(),
    LearningHubScreen(),
    ChildAchievementsScreen(),
    ChildTanScreen(),
  ];

  String get _title {
    switch (_index) {
      case 1:
        return 'Lernen';
      case 2:
        return 'Achievements';
      case 3:
        return 'Mein TAN-Budget';
      default:
        return 'Heute';
    }
  }

  void _logout() {
    ref.read(sessionProvider.notifier).clear();
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Theme wechseln',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Aufgaben'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Lernen'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Badges'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'TANs'),
        ],
      ),
    );
  }
}
