import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class ChildTasksScreen extends ConsumerStatefulWidget {
  const ChildTasksScreen({super.key});

  @override
  ConsumerState<ChildTasksScreen> createState() => _ChildTasksScreenState();
}

class _ChildTasksScreenState extends ConsumerState<ChildTasksScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _submissions = [];
  bool _loading = true;
  final Set<int> _submitting = {};
  final Set<int> _submitted = {};

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
      final results = await Future.wait([
        api.fetchTodayTasksForChild(session.userId!),
        api.fetchSubmissionHistory(),
      ]);
      final tasks = results[0] as List<dynamic>;
      final submissions = results[1] as List<dynamic>;

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final submittedToday = submissions
          .where((s) => (s['created_at'] as String?)?.startsWith(todayStr) == true)
          .map((s) => s['task_id'] as int)
          .toSet();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _submissions = submissions;
        _submitted.addAll(submittedToday);
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
      setState(() => _submitted.add(taskId));
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

  String _getSubmissionStatus(int taskId) {
    dynamic match;
    for (final submission in _submissions) {
      if (submission['task_id'] == taskId) {
        match = submission;
        break;
      }
    }
    if (match == null) return 'pending';
    return match['status'] as String? ?? 'pending';
  }

  Widget _buildTaskButton(Map<String, dynamic> task, bool requiresPhoto) {
    final taskId = task['id'] as int;
    final isSubmitting = _submitting.contains(taskId);
    final status = _getSubmissionStatus(taskId);
    final isSubmitted = _submitted.contains(taskId);

    if (isSubmitting) {
      return const SizedBox(
        height: 36,
        width: 100,
        child: Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Bestätigt ✓', style: TextStyle(color: Colors.green)),
      );
    }

    if (status == 'retry') {
      return ElevatedButton(
        onPressed: () => _submitTask(taskId),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.15)),
        child: const Text('Nochmal', style: TextStyle(color: Colors.red)),
      );
    }

    if (isSubmitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Eingereicht', style: TextStyle(color: Colors.orange)),
      );
    }

    return ElevatedButton(
      onPressed: requiresPhoto ? () => context.push('/child/task', extra: task) : () => _submitTask(taskId),
      child: Text(requiresPhoto ? 'Details' : 'Erledigt'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: _tasks.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Keine Aufgaben für heute.')),
              ],
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final requiresPhoto = task['requires_photo'] == true;
                return Card(
                  child: ListTile(
                    title: Text(task['title'] ?? 'Aufgabe'),
                    subtitle: Text('${task['duration_minutes'] ?? 0} Minuten • ${task['target_device'] ?? ''}'),
                    leading: Icon(requiresPhoto ? Icons.photo_camera : Icons.task_alt),
                    trailing: _buildTaskButton(task, requiresPhoto),
                    onTap: () => context.push('/child/task', extra: task),
                  ),
                );
              },
            ),
    );
  }
}
