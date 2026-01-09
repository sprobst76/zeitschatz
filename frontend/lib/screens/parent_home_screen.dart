import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/session_storage.dart';
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

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).clear();
    if (mounted) context.go('/welcome');
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

  Future<void> _openSettings() async {
    final storage = SessionStorage();
    final biometricAvailable = await storage.isBiometricAvailable();
    final biometricEnabled = await storage.isBiometricEnabled();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsSheet(
        biometricAvailable: biometricAvailable,
        biometricEnabled: biometricEnabled,
        onBiometricChanged: (enabled) async {
          await storage.setBiometricEnabled(enabled);
        },
      ),
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
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
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

class _SettingsSheet extends StatefulWidget {
  final bool biometricAvailable;
  final bool biometricEnabled;
  final Future<void> Function(bool enabled) onBiometricChanged;

  const _SettingsSheet({
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.onBiometricChanged,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _biometricEnabled;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = widget.biometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Einstellungen',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.biometricAvailable) ...[
              SwitchListTile(
                title: const Text('Fingerabdruck-Anmeldung'),
                subtitle: const Text('Schneller Zugriff mit Fingerabdruck'),
                secondary: const Icon(Icons.fingerprint),
                value: _biometricEnabled,
                onChanged: (value) async {
                  setState(() => _biometricEnabled = value);
                  await widget.onBiometricChanged(value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Fingerabdruck-Anmeldung aktiviert'
                              : 'Fingerabdruck-Anmeldung deaktiviert',
                        ),
                      ),
                    );
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.fingerprint, color: Colors.grey),
                title: const Text('Fingerabdruck-Anmeldung'),
                subtitle: const Text('Nicht verfuegbar auf diesem Geraet'),
                enabled: false,
              ),
            ],
            const Divider(),
            Consumer(
              builder: (context, ref, _) => SwitchListTile(
                title: const Text('Dunkles Design'),
                secondary: const Icon(Icons.dark_mode),
                value: ref.watch(themeProvider) == ThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).setTheme(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
