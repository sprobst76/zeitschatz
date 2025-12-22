import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import 'parent_history_screen.dart';
import 'parent_inbox_screen.dart';
import 'parent_kids_screen.dart';
import 'parent_stats_screen.dart';
import 'parent_tasks_screen.dart';
import 'parent_tan_screen.dart';

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  int _index = 0;

  final _pages = const [
    ParentInboxScreen(embedded: true),
    ParentTasksScreen(),
    ParentKidsScreen(),
    ParentTanScreen(),
    ParentStatsScreen(),
  ];

  String get _title {
    switch (_index) {
      case 1:
        return 'Aufgaben';
      case 2:
        return 'Benutzer';
      case 3:
        return 'TAN-Uebersicht';
      case 4:
        return 'Statistik';
      default:
        return 'Inbox';
    }
  }

  void _logout() {
    ref.read(sessionProvider.notifier).clear();
    context.go('/role');
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ParentHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_index == 0) // Show history button on Inbox tab
            IconButton(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              tooltip: 'Erledigte Aufgaben',
            ),
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
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Aufgaben'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Benutzer'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'TANs'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}
