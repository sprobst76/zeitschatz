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
  List<dynamic> _submissions = [];
  bool _loading = true;
  final Set<int> _submitting = {};
  final Set<int> _submitted = {}; // Lokal getrackte eingereichte Tasks

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
        api.fetchSubmissionHistory(childId: session.userId!),
      ]);
      final tasks = results[0] as List<dynamic>;
      final submissions = results[1] as List<dynamic>;

      // Finde heute eingereichte Tasks
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final submittedToday = submissions
          .where((s) => (s['created_at'] as String?)?.startsWith(todayStr) == true)
          .map((s) => s['task_id'] as int)
          .toSet();

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
    final submission = _submissions.firstWhere(
      (s) => s['task_id'] == taskId,
      orElse: () => null,
    );
    if (submission == null) return 'pending';
    return submission['status'] as String? ?? 'pending';
  }

  Widget _buildTaskButton(Map<String, dynamic> task) {
    final taskId = task['id'] as int;
    final isSubmitting = _submitting.contains(taskId);
    final isSubmitted = _submitted.contains(taskId);
    final status = _getSubmissionStatus(taskId);

    if (isSubmitting) {
      return const SizedBox(
        height: 36,
        width: 100,
        child: Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (isSubmitted || status == 'pending' && _submitted.contains(taskId)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Eingereicht', style: TextStyle(color: Colors.orange)),
      );
    }

    if (status == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Bestätigt ✓', style: TextStyle(color: Colors.green)),
      );
    }

    if (status == 'retry') {
      return ElevatedButton(
        onPressed: () => _submitTask(taskId),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
        child: const Text('Nochmal'),
      );
    }

    return ElevatedButton(
      onPressed: () => _submitTask(taskId),
      child: const Text('Erledigt'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'Meine TANs',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChildLedgerScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Card(
                    child: ListTile(
                      title: Text(task['title'] ?? 'Aufgabe'),
                      subtitle: Text('${task['tan_reward'] ?? 0} Min • ${task['target_device'] ?? ''}'),
                      trailing: _buildTaskButton(task),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ChildLedgerScreen extends ConsumerStatefulWidget {
  const ChildLedgerScreen({super.key});

  @override
  ConsumerState<ChildLedgerScreen> createState() => _ChildLedgerScreenState();
}

class _ChildLedgerScreenState extends ConsumerState<ChildLedgerScreen> {
  List<dynamic> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final api = ref.read(apiClientProvider);
    try {
      final ledger = await api.fetchMyLedger();
      setState(() {
        _ledger = ledger;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine TANs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ledger.isEmpty
              ? const Center(child: Text('Noch keine TANs verdient'))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    itemCount: _ledger.length,
                    itemBuilder: (context, index) {
                      final entry = _ledger[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            entry['target_device'] == 'tablet'
                                ? Icons.tablet
                                : entry['target_device'] == 'pc'
                                    ? Icons.computer
                                    : Icons.phone_android,
                            size: 32,
                          ),
                          title: Text('${entry['total_minutes'] ?? 0} Minuten'),
                          subtitle: Text('${entry['target_device'] ?? ''} • ${entry['count'] ?? 0} Aufgaben'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
