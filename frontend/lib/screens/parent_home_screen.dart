import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/family_state.dart';
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

  @override
  void initState() {
    super.initState();
    // Load device providers to determine which tabs to show
    Future.microtask(() {
      ref.read(familyStateProvider.notifier).loadDeviceProviders();
    });
  }

  List<Widget> _getPages(bool hasKisi) {
    if (hasKisi) {
      return const [
        ParentInboxScreen(embedded: true),
        ParentTasksScreen(),
        ParentKidsScreen(),
        ParentTanScreen(),
        ParentStatsScreen(),
      ];
    } else {
      return const [
        ParentInboxScreen(embedded: true),
        ParentTasksScreen(),
        ParentKidsScreen(),
        ParentStatsScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems(bool hasKisi) {
    if (hasKisi) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
        BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Aufgaben'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Benutzer'),
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'TANs'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
        BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Aufgaben'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Benutzer'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
      ];
    }
  }

  String _getTitle(bool hasKisi) {
    if (hasKisi) {
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
    } else {
      switch (_index) {
        case 1:
          return 'Aufgaben';
        case 2:
          return 'Benutzer';
        case 3:
          return 'Statistik';
        default:
          return 'Inbox';
      }
    }
  }

  void _logout() {
    ref.read(sessionProvider.notifier).clear();
    context.go('/welcome');
  }

  void _openFamilySettings() {
    context.push('/family/settings');
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ParentHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyStateProvider);
    final hasKisi = familyState.hasKisiDevice;
    final pages = _getPages(hasKisi);
    final navItems = _getNavItems(hasKisi);

    // Ensure index is valid for current nav items
    if (_index >= navItems.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(hasKisi)),
        actions: [
          if (_index == 0) // Show history button on Inbox tab
            IconButton(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              tooltip: 'Erledigte Aufgaben',
            ),
          IconButton(
            onPressed: _openFamilySettings,
            icon: const Icon(Icons.family_restroom),
            tooltip: 'Familie verwalten',
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
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}
