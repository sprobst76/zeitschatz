import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';

class ParentInboxScreen extends ConsumerStatefulWidget {
  const ParentInboxScreen({super.key});

  @override
  ConsumerState<ParentInboxScreen> createState() => _ParentInboxScreenState();
}

class _ParentInboxScreenState extends ConsumerState<ParentInboxScreen> {
  List<dynamic> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    final api = ApiClient(token: session.token!);
    try {
      final res = await api.fetchPendingSubmissions();
      setState(() {
        _pending = res;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approve(int submissionId) async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    final api = ApiClient(token: session.token!);
    await api.approveSubmission(submissionId, minutes: 30, targetDevice: 'phone', tanCode: 'ABC12345');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _pending.length,
                itemBuilder: (context, index) {
                  final sub = _pending[index];
                  return Card(
                    child: ListTile(
                      title: Text('Submission ${sub['id']}'),
                      subtitle: Text('Task ${sub['task_id']} • Status ${sub['status']}'),
                      trailing: ElevatedButton(
                        onPressed: () => _approve(sub['id']),
                        child: const Text('Approve'),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
