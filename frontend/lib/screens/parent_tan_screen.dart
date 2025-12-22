import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class ParentTanScreen extends ConsumerStatefulWidget {
  const ParentTanScreen({super.key});

  @override
  ConsumerState<ParentTanScreen> createState() => _ParentTanScreenState();
}

class _ParentTanScreenState extends ConsumerState<ParentTanScreen> {
  List<dynamic> _aggregate = [];
  List<dynamic> _entries = [];
  List<dynamic> _children = [];
  int? _selectedChildId;
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
        api.fetchLedgerAggregate(),
        api.fetchChildren(),
      ]);
      final aggregate = results[0] as List<dynamic>;
      final children = results[1] as List<dynamic>;
      final selectedChildId = _selectedChildId ?? (children.isNotEmpty ? children.first['id'] as int? : null);
      final entries = selectedChildId == null ? <dynamic>[] : await api.fetchLedgerEntries(selectedChildId);
      if (!mounted) return;
      setState(() {
        _aggregate = aggregate;
        _children = children;
        _selectedChildId = selectedChildId;
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _childName(int? id) {
    if (id == null) return 'Unbekannt';
    dynamic match;
    for (final child in _children) {
      if (child['id'] == id) {
        match = child;
        break;
      }
    }
    if (match == null) return 'Kind $id';
    return match['name'] ?? 'Kind $id';
  }

  Future<void> _markPaid(int entryId) async {
    final api = ref.read(apiClientProvider);
    await api.markLedgerPaid(entryId);
    await _load();
  }

  Future<void> _createManualTan() async {
    final minutesCtrl = TextEditingController(text: '30');
    final deviceCtrl = TextEditingController(text: 'phone');
    final tanCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'manual payout');
    int? childId = _selectedChildId;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TAN anlegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: childId,
              items: _children
                  .map(
                    (child) => DropdownMenuItem(
                      value: child['id'] as int,
                      child: Text(child['name'] ?? 'Kind'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => childId = value,
              decoration: const InputDecoration(labelText: 'Kind'),
            ),
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minuten'),
            ),
            TextField(
              controller: deviceCtrl,
              decoration: const InputDecoration(labelText: 'Gerät (phone/pc)'),
            ),
            TextField(
              controller: tanCtrl,
              decoration: const InputDecoration(labelText: 'TAN-Code (optional)'),
            ),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Notiz'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Anlegen')),
        ],
      ),
    );
    if (result != true || childId == null) return;
    final api = ref.read(apiClientProvider);
    await api.createPayout({
      'child_id': childId,
      'minutes': int.tryParse(minutesCtrl.text) ?? 30,
      'target_device': deviceCtrl.text.trim().isEmpty ? 'phone' : deviceCtrl.text.trim(),
      'tan_code': tanCtrl.text.trim().isEmpty ? null : tanCtrl.text.trim(),
      'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final paidMinutes = _entries.where((e) => e['paid_out'] == true).fold<int>(
          0,
          (sum, e) => sum + (e['minutes'] as int? ?? 0),
        );
    final unpaidMinutes = _entries.where((e) => e['paid_out'] != true).fold<int>(
          0,
          (sum, e) => sum + (e['minutes'] as int? ?? 0),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _createManualTan,
                    icon: const Icon(Icons.add),
                    label: const Text('TAN anlegen'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/parent/tan-pool'),
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('TAN Pool'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Offen (unbezahlt)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (_aggregate.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Keine offenen TANs.'),
            ),
          ..._aggregate.map((row) {
            final childId = row['child_id'] as int?;
            final device = row['target_device'] ?? 'alle Geräte';
            final minutes = row['total_minutes'] ?? 0;
            final count = row['entry_count'] ?? 0;
            return ListTile(
              title: Text('${_childName(childId)} • $device'),
              subtitle: Text('$minutes Minuten • $count Einträge'),
            );
          }),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<int>(
              value: _selectedChildId,
              items: _children
                  .map(
                    (child) => DropdownMenuItem(
                      value: child['id'] as int,
                      child: Text(child['name'] ?? 'Kind'),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() => _selectedChildId = value);
                if (value != null) {
                  final api = ref.read(apiClientProvider);
                  final entries = await api.fetchLedgerEntries(value);
                  if (!mounted) return;
                  setState(() => _entries = entries);
                }
              },
              decoration: const InputDecoration(labelText: 'Ledger pro Kind'),
            ),
          ),
          if (_selectedChildId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: ListTile(
                  title: Text(_childName(_selectedChildId)),
                  subtitle: Text('Verfügbar: $unpaidMinutes Min • Verbraucht: $paidMinutes Min'),
                ),
              ),
            ),
          if (_entries.isEmpty && _selectedChildId != null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Keine Ledger-Einträge vorhanden.'),
            ),
          ..._entries.map((entry) {
            final isPaid = entry['paid_out'] == true;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text('${entry['minutes']} Minuten • ${entry['target_device'] ?? ''}'),
                subtitle: Text(entry['reason'] ?? 'Task'),
                trailing: isPaid
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () => _markPaid(entry['id'] as int),
                        child: const Text('Bezahlt'),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
