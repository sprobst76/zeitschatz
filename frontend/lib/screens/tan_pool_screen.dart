import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class TanPoolScreen extends ConsumerStatefulWidget {
  const TanPoolScreen({super.key});

  @override
  ConsumerState<TanPoolScreen> createState() => _TanPoolScreenState();
}

class _TanPoolScreenState extends ConsumerState<TanPoolScreen> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _tans = [];
  bool _loading = true;
  String? _filterDevice;
  bool _showAvailableOnly = true;

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
        api.fetchTanPoolStats(),
        api.fetchTanPool(availableOnly: _showAvailableOnly, targetDevice: _filterDevice),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _tans = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _showImportDialog() async {
    final textController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TANs importieren'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) => Text(
                'Format: TAN;Minutes;Created;Device',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              )),
              const SizedBox(height: 4),
              Builder(builder: (context) => Text(
                'Beispiel:\n114187;30;2025-12-20;LEOS LAPTOP',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Theme.of(context).colorScheme.onSurfaceVariant),
              )),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'TAN-Daten hier einfuegen...',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        textController.text = data!.text!;
                      }
                    },
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Einfuegen'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );

    if (result != true || textController.text.trim().isEmpty) return;

    final api = ref.read(apiClientProvider);
    try {
      final response = await api.importTans(textController.text);
      if (!mounted) return;
      final imported = response['imported'] ?? 0;
      final skipped = response['skipped'] ?? 0;
      final errors = response['errors'] as List<dynamic>? ?? [];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$imported importiert, $skipped uebersprungen${errors.isNotEmpty ? ', ${errors.length} Fehler' : ''}'),
          duration: const Duration(seconds: 3),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _deleteTan(int tanId, String tanCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TAN loeschen?'),
        content: Text('TAN $tanCode wirklich loeschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Loeschen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = ref.read(apiClientProvider);
    try {
      await api.deleteTan(tanId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _deviceIcon(String? device) {
    switch (device) {
      case 'pc':
        return 'PC';
      case 'tablet':
        return 'Tablet';
      case 'phone':
        return 'Phone';
      default:
        return device ?? '?';
    }
  }

  IconData _deviceIconData(String? device) {
    switch (device) {
      case 'pc':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      case 'phone':
        return Icons.phone_android;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDevice = _stats['by_device'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('TAN Pool'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImportDialog,
        icon: const Icon(Icons.upload),
        label: const Text('Import'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  // Stats Card
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'Gesamt',
                                  value: '${_stats['total'] ?? 0}',
                                  color: Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: _StatTile(
                                  label: 'Verfuegbar',
                                  value: '${_stats['available'] ?? 0}',
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _StatTile(
                                  label: 'Verwendet',
                                  value: '${_stats['used'] ?? 0}',
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          if (byDevice.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text('Verfuegbar nach Geraet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: byDevice.entries.map((e) {
                                return Chip(
                                  avatar: Icon(_deviceIconData(e.key), size: 18),
                                  label: Text('${_deviceIcon(e.key)}: ${e.value}'),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _filterDevice,
                            decoration: const InputDecoration(
                              labelText: 'Geraet',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Alle')),
                              DropdownMenuItem(value: 'pc', child: Text('PC')),
                              DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                              DropdownMenuItem(value: 'phone', child: Text('Phone')),
                            ],
                            onChanged: (value) {
                              setState(() => _filterDevice = value);
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          label: const Text('Nur verfuegbar'),
                          selected: _showAvailableOnly,
                          onSelected: (value) {
                            setState(() => _showAvailableOnly = value);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${_tans.length} TANs',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // TAN List
                  if (_tans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Keine TANs gefunden.'),
                      ),
                    )
                  else
                    ..._tans.map((tan) {
                      final isUsed = tan['used'] == true;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            _deviceIconData(tan['target_device']),
                            color: isUsed ? Colors.grey : Colors.blue,
                          ),
                          title: Text(
                            tan['tan_code'] ?? '',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: isUsed ? Colors.grey : null,
                              decoration: isUsed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '${tan['minutes']} Min • ${_deviceIcon(tan['target_device'])}${isUsed ? ' • Verwendet' : ''}',
                          ),
                          trailing: isUsed
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteTan(tan['id'] as int, tan['tan_code'] ?? ''),
                                ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
