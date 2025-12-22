import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ParentInboxScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ParentInboxScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ParentInboxScreen> createState() => _ParentInboxScreenState();
}

class _ParentInboxScreenState extends ConsumerState<ParentInboxScreen> {
  List<dynamic> _pending = [];
  Map<String, dynamic>? _tanStats;
  bool _loading = true;
  bool _working = false;

  static const _deviceLabels = {
    'phone': 'Handy',
    'pc': 'PC',
    'console': 'Konsole',
  };

  static const _deviceIcons = {
    'phone': Icons.phone_android,
    'pc': Icons.computer,
    'console': Icons.videogame_asset,
  };

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
      final results = await Future.wait([
        api.fetchPendingSubmissions(),
        api.fetchTanPoolStats(),
      ]);
      setState(() {
        _pending = results[0] as List<dynamic>;
        _tanStats = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int _getAvailableTans(String device) {
    if (_tanStats == null) return 0;
    final byDevice = _tanStats!['by_device'] as Map<String, dynamic>?;
    if (byDevice == null) return 0;
    final deviceStats = byDevice[device] as Map<String, dynamic>?;
    return (deviceStats?['available'] as int?) ?? 0;
  }

  Future<void> _approveDialog(Map<String, dynamic> sub) async {
    final tanReward = sub['tan_reward'] as int? ?? 30;
    final selectedDevice = sub['selected_device'] as String? ?? 'phone';
    final availableTans = _getAvailableTans(selectedDevice);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${sub['task_title'] ?? 'Aufgabe'} bestaetigen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) => Row(
                children: [
                  Icon(Icons.child_care, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    sub['child_name'] ?? 'Kind',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )),
              const SizedBox(height: 16),
              // Geraet und Zeit
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(_deviceIcons[selectedDevice] ?? Icons.devices, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deviceLabels[selectedDevice] ?? selectedDevice,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('$tanReward Minuten'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // TAN-Verfuegbarkeit
              if (availableTans == 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keine TANs fuer ${_deviceLabels[selectedDevice]} verfuegbar!',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '$availableTans TAN(s) fuer ${_deviceLabels[selectedDevice]} verfuegbar',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bestaetigen'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _approve(sub['id'] as int);
    }
  }

  Future<void> _approve(int submissionId) async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    setState(() => _working = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.approveSubmission(submissionId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestaetigt')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Bestaetigen')));
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _retryDialog(Map<String, dynamic> sub) async {
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zur Wiederholung schicken'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aufgabe: ${sub['task_title'] ?? 'Unbekannt'}'),
            Text('Von: ${sub['child_name'] ?? 'Kind'}'),
            const SizedBox(height: 16),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Grund (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              _retry(sub['id'] as int, commentCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('Zurueckschicken'),
          ),
        ],
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Zurueckweisen')));
    } finally {
      setState(() => _working = false);
    }
  }

  void _showPhoto(int submissionId) {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    final api = ref.read(apiClientProvider);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Image.network(
                api.photoUrl(submissionId),
                headers: {'Authorization': 'Bearer ${session.token!}'},
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Foto nicht verfuegbar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> sub) {
    final session = ref.read(sessionProvider);
    final api = ref.read(apiClientProvider);
    final hasPhoto = sub['photo_path'] != null;
    final selectedDevice = sub['selected_device'] as String?;
    final tanReward = sub['tan_reward'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto-Thumbnail wenn vorhanden
          if (hasPhoto)
            GestureDetector(
              onTap: () => _showPhoto(sub['id'] as int),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Builder(builder: (context) => Image.network(
                    api.photoUrl(sub['id'] as int),
                    headers: session.token != null
                      ? {'Authorization': 'Bearer ${session.token}'}
                      : null,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.broken_image, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )),
                ),
              ),
            ),

          // Inhalt
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task-Titel
                Text(
                  sub['task_title'] ?? 'Aufgabe ${sub['task_id']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // Kind-Name
                Builder(builder: (context) => Row(
                  children: [
                    Icon(Icons.child_care, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      sub['child_name'] ?? 'Kind',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                )),
                const SizedBox(height: 8),

                // Belohnung und gewaehltes Geraet
                Wrap(
                  spacing: 12,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '$tanReward Min',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (selectedDevice != null)
                      Builder(builder: (context) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _deviceIcons[selectedDevice] ?? Icons.devices,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _deviceLabels[selectedDevice] ?? selectedDevice,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),

                // Kommentar vom Kind
                if (sub['comment'] != null && sub['comment'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sub['comment'].toString())),
                      ],
                    ),
                  )),
                ],

                const SizedBox(height: 12),

                // Aktions-Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _retryDialog(sub),
                      icon: const Icon(Icons.refresh, color: Colors.orange),
                      label: const Text('Wiederholen', style: TextStyle(color: Colors.orange)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _working ? null : () => _approveDialog(sub),
                      icon: const Icon(Icons.check),
                      label: const Text('Bestaetigen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _pending.isEmpty
            ? Builder(builder: (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'Keine offenen Aufgaben',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: _pending.length,
                  itemBuilder: (context, index) {
                    final sub = _pending[index] as Map<String, dynamic>;
                    return _buildSubmissionCard(sub);
                  },
                ),
              );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: body,
    );
  }
}
