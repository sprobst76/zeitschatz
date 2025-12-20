import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class ParentInboxScreen extends ConsumerStatefulWidget {
  const ParentInboxScreen({super.key});

  @override
  ConsumerState<ParentInboxScreen> createState() => _ParentInboxScreenState();
}

class _ParentInboxScreenState extends ConsumerState<ParentInboxScreen> {
  List<dynamic> _pending = [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    final api = ref.read(apiClientProvider);
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
    setState(() => _working = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.approveSubmission(submissionId, minutes: 30, targetDevice: 'phone', tanCode: 'ABC12345');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestätigt')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Bestätigen')));
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _approveDialog(int submissionId) async {
    final minutesCtrl = TextEditingController(text: '30');
    final deviceCtrl = TextEditingController(text: 'phone');
    final tanCtrl = TextEditingController(text: 'ABC12345');
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submission bestätigen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: minutesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minuten')),
              TextField(controller: deviceCtrl, decoration: const InputDecoration(labelText: 'Gerät (phone/pc)')),
              TextField(controller: tanCtrl, decoration: const InputDecoration(labelText: 'TAN-Code (optional)')),
              TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Kommentar (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                final minutes = int.tryParse(minutesCtrl.text) ?? 30;
                _approveWithParams(submissionId, minutes, deviceCtrl.text.isEmpty ? 'phone' : deviceCtrl.text,
                    tanCtrl.text.isEmpty ? null : tanCtrl.text, commentCtrl.text.isEmpty ? null : commentCtrl.text);
                Navigator.pop(context);
              },
              child: const Text('Bestätigen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveWithParams(int submissionId, int minutes, String device, String? tan, String? comment) async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    setState(() => _working = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.approveSubmission(submissionId, minutes: minutes, targetDevice: device, tanCode: tan, comment: comment);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestätigt')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Bestätigen')));
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _retry(int submissionId, String comment) async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    setState(() => _working = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.retrySubmission(submissionId, comment: comment);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zur Wiederholung markiert')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Zurückweisen')));
    } finally {
      setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            onPressed: () => context.go('/parent/history'),
            icon: const Icon(Icons.history),
            tooltip: 'Historie',
          ),
          IconButton(
            onPressed: () => context.go('/parent/ledger-aggregate'),
            icon: const Icon(Icons.summarize),
            tooltip: 'Ledger-Aggregat',
          ),
        ],
      ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _working ? null : () => _approveDialog(sub['id']),
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Bestätigen',
                          ),
                          IconButton(
                            onPressed: _working
                                ? null
                                : () async {
                                    final commentCtrl = TextEditingController();
                                    await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Zur Wiederholung schicken'),
                                        content: TextField(
                                          controller: commentCtrl,
                                          decoration: const InputDecoration(labelText: 'Kommentar (optional)'),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                                          ElevatedButton(
                                            onPressed: () {
                                              _retry(sub['id'], commentCtrl.text);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Senden'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.refresh, color: Colors.orange),
                            tooltip: 'Wiederholen',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
