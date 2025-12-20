import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class LedgerAggregateScreen extends ConsumerStatefulWidget {
  const LedgerAggregateScreen({super.key});

  @override
  ConsumerState<LedgerAggregateScreen> createState() => _LedgerAggregateScreenState();
}

class _LedgerAggregateScreenState extends ConsumerState<LedgerAggregateScreen> {
  final _childIdController = TextEditingController();
  List<dynamic> _rows = [];
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
      final rows = await api.fetchLedgerAggregate(childId: childId);
      setState(() => _rows = rows);
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
      appBar: AppBar(title: const Text('Ledger-Aggregat')),
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
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      final device = row['target_device'] ?? 'any';
                      final minutes = row['total_minutes'] ?? 0;
                      final count = row['entry_count'] ?? 0;
                      return Card(
                        child: ListTile(
                          title: Text('Child ${row['child_id']} • $device'),
                          subtitle: Text('$minutes Minuten • $count Einträge'),
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
