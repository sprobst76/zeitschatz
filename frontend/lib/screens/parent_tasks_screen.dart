import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class ParentTasksScreen extends ConsumerStatefulWidget {
  const ParentTasksScreen({super.key});

  @override
  ConsumerState<ParentTasksScreen> createState() => _ParentTasksScreenState();
}

class _ParentTasksScreenState extends ConsumerState<ParentTasksScreen> {
  List<dynamic> _tasks = [];
  Map<int, String> _childNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.fetchTasks(),
        api.fetchChildren(),
      ]);
      final tasks = results[0] as List<dynamic>;
      final children = results[1] as List<dynamic>;
      final nameMap = <int, String>{};
      for (final child in children) {
        final id = child['id'];
        if (id is int) {
          nameMap[id] = child['name'] ?? 'Kind $id';
        }
      }
      setState(() {
        _tasks = tasks;
        _childNames = nameMap;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _assignedLabel(List<dynamic>? assigned) {
    if (assigned == null || assigned.isEmpty) {
      return 'Alle Kinder';
    }
    final names = assigned.map((id) => _childNames[id] ?? 'ID $id').toList();
    return names.join(', ');
  }

  static const _dayLabels = {
    'mon': 'Mo',
    'tue': 'Di',
    'wed': 'Mi',
    'thu': 'Do',
    'fri': 'Fr',
    'sat': 'Sa',
    'sun': 'So',
  };

  String _recurrenceLabel(Map<String, dynamic>? recurrence) {
    if (recurrence == null) return '';
    final activeDays = <String>[];
    for (final entry in _dayLabels.entries) {
      if (recurrence[entry.key] == true) {
        activeDays.add(entry.value);
      }
    }
    if (activeDays.isEmpty) return '';
    if (activeDays.length == 7) return 'Taeglich';
    if (activeDays.length == 5 &&
        recurrence['mon'] == true &&
        recurrence['tue'] == true &&
        recurrence['wed'] == true &&
        recurrence['thu'] == true &&
        recurrence['fri'] == true &&
        recurrence['sat'] != true &&
        recurrence['sun'] != true) {
      return 'Werktags';
    }
    return activeDays.join(' ');
  }

  IconData _deviceIcon(String? device) {
    switch (device) {
      case 'phone':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet_android;
      case 'pc':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  String _deviceLabel(String? device) {
    switch (device) {
      case 'phone':
        return 'Handy';
      case 'tablet':
        return 'Tablet';
      case 'pc':
        return 'PC';
      default:
        return device ?? 'Alle';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _tasks.isEmpty ? 2 : _tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: FilledButton.icon(
                onPressed: () async {
                  final changed = await context.push('/parent/task');
                  if (changed == true) {
                    _load();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Neue Aufgabe'),
              ),
            );
          }
          if (_tasks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(child: Text('Noch keine Aufgaben angelegt.')),
            );
          }
          final task = _tasks[index - 1];
          final assigned = (task['assigned_children'] as List<dynamic>?);
          final recurrence = task['recurrence'] as Map<String, dynamic>?;
          final recurrenceText = _recurrenceLabel(recurrence);
          final tanReward = task['tan_reward'] ?? task['duration_minutes'] ?? 0;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: InkWell(
              onTap: () async {
                final changed = await context.push('/parent/task', extra: task);
                if (changed == true) {
                  _load();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task['title'] ?? 'Aufgabe',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (task['requires_photo'] == true)
                          const Icon(Icons.photo_camera, size: 20, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(icon: Icons.timer, label: '$tanReward Min'),
                        if (task['target_device'] != null)
                          _InfoChip(
                            icon: _deviceIcon(task['target_device']),
                            label: _deviceLabel(task['target_device']),
                          ),
                        if (recurrenceText.isNotEmpty)
                          _InfoChip(
                            icon: Icons.repeat,
                            label: recurrenceText,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => Text(
                        'Zuweisung: ${_assignedLabel(assigned)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: chipColor),
          ),
        ],
      ),
    );
  }
}
