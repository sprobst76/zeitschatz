import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ParentHistoryScreen extends ConsumerStatefulWidget {
  const ParentHistoryScreen({super.key});

  @override
  ConsumerState<ParentHistoryScreen> createState() => _ParentHistoryScreenState();
}

class _ParentHistoryScreenState extends ConsumerState<ParentHistoryScreen> {
  final _childIdController = TextEditingController();
  List<dynamic> _history = [];
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
      final childId = int.tryParse(_childIdController.text);
      final history = await api.fetchSubmissionHistory(childId: childId);
      setState(() => _history = history);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _childIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission-Historie')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _childIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kind-ID (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Laden'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final status = item['status'] ?? 'unknown';
                      return Card(
                        child: ListTile(
                          title: Text('Submission ${item['id']}'),
                          subtitle: Text('Task ${item['task_id']} • Child ${item['child_id']} • $status'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
