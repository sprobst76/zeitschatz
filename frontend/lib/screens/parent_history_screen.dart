import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';

class ParentHistoryScreen extends ConsumerStatefulWidget {
  const ParentHistoryScreen({super.key});

  @override
  ConsumerState<ParentHistoryScreen> createState() => _ParentHistoryScreenState();
}

class _ParentHistoryScreenState extends ConsumerState<ParentHistoryScreen> {
  List<dynamic> _completed = [];
  List<dynamic> _children = [];
  bool _loading = true;
  int? _selectedChildId;

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
    final api = ref.read(apiClientProvider);
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.fetchCompletedSubmissions(childId: _selectedChildId),
        api.fetchChildren(),
      ]);
      setState(() {
        _completed = results[0] as List<dynamic>;
        _children = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Heute, ${DateFormat.Hm().format(date)}';
      } else if (diff.inDays == 1) {
        return 'Gestern, ${DateFormat.Hm().format(date)}';
      } else if (diff.inDays < 7) {
        return DateFormat('EEEE, HH:mm', 'de_DE').format(date);
      } else {
        return DateFormat('dd.MM.yyyy, HH:mm').format(date);
      }
    } catch (_) {
      return dateStr;
    }
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
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    api.photoUrl(sub['id'] as int),
                    headers: session.token != null
                        ? {'Authorization': 'Bearer ${session.token}'}
                        : null,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Builder(
                        builder: (context) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Builder(
                      builder: (context) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task-Titel und Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sub['task_title'] ?? 'Aufgabe ${sub['task_id']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text(
                            'Erledigt',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Kind-Name und Datum
                Builder(
                  builder: (context) => Row(
                    children: [
                      Icon(
                        Icons.child_care,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sub['child_name'] ?? 'Kind',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(sub['updated_at']?.toString()),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Belohnung und Geraet
                Wrap(
                  spacing: 8,
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
                          const Icon(Icons.timer, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '$tanReward Min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectedDevice != null)
                      Builder(
                        builder: (context) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _deviceIcons[selectedDevice] ?? Icons.devices,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _deviceLabels[selectedDevice] ?? selectedDevice,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (hasPhoto)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo, size: 14, color: Colors.purple),
                            const SizedBox(width: 4),
                            const Text(
                              'Foto',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Kommentar
                if (sub['comment'] != null && sub['comment'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub['comment'].toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erledigte Aufgaben'),
      ),
      body: Column(
        children: [
          // Child filter
          if (_children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Alle'),
                      selected: _selectedChildId == null,
                      onSelected: (_) {
                        setState(() => _selectedChildId = null);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._children.map((child) {
                      final id = child['id'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: const Icon(Icons.child_care, size: 16),
                          label: Text(child['name'] ?? 'Kind $id'),
                          selected: _selectedChildId == id,
                          onSelected: (_) {
                            setState(() => _selectedChildId = id);
                            _load();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _completed.isEmpty
                    ? Center(
                        child: Builder(
                          builder: (context) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Keine erledigten Aufgaben',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _completed.length,
                          itemBuilder: (context, index) {
                            final sub = _completed[index] as Map<String, dynamic>;
                            return _buildSubmissionCard(sub);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
