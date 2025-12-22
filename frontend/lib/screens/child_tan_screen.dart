import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ChildTanScreen extends ConsumerStatefulWidget {
  const ChildTanScreen({super.key});

  @override
  ConsumerState<ChildTanScreen> createState() => _ChildTanScreenState();
}

class _ChildTanScreenState extends ConsumerState<ChildTanScreen> {
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

  IconData _deviceIcon(String? device) {
    switch (device) {
      case 'tablet':
        return Icons.tablet;
      case 'pc':
        return Icons.computer;
      case 'phone':
      default:
        return Icons.phone_android;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ledger.isEmpty) {
      return const Center(child: Text('Noch keine TANs verdient'));
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        itemCount: _ledger.length,
        itemBuilder: (context, index) {
          final entry = _ledger[index];
          return Card(
            child: ListTile(
              leading: Icon(_deviceIcon(entry['target_device'] as String?)),
              title: Text('${entry['total_minutes'] ?? 0} Minuten'),
              subtitle: Text('${entry['target_device'] ?? ''} • ${entry['entry_count'] ?? 0} Aufgaben'),
            ),
          );
        },
      ),
    );
  }
}
