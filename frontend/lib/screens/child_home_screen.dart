import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;
  final Set<int> _submitting = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final session = ref.read(sessionProvider);
    if (session.userId == null || session.token == null) return;
    final api = ref.read(apiClientProvider);
    try {
      final tasks = await api.fetchTodayTasksForChild(session.userId!);
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitTask(int taskId) async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    setState(() => _submitting.add(taskId));
    final api = ref.read(apiClientProvider);
    try {
      await api.submitTask(taskId: taskId, comment: 'Erledigt');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aufgabe eingereicht')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einreichen fehlgeschlagen')),
      );
    } finally {
      setState(() => _submitting.remove(taskId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heute')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  child: ListTile(
                    title: Text(task['title'] ?? 'Aufgabe'),
                    subtitle: Text('${task['duration_minutes'] ?? 0} Minuten • ${task['target_device'] ?? ''}'),
                    trailing: ElevatedButton(
                      onPressed: _submitting.contains(task['id']) ? null : () => _submitTask(task['id']),
                      child: _submitting.contains(task['id'])
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Erledigt'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
