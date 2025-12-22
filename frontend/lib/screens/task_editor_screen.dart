import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class TaskEditorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? task;
  const TaskEditorScreen({super.key, this.task});

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _tanReward = 30;
  final Set<String> _targetDevices = {};
  final Map<String, bool> _recurrence = {
    'mon': false,
    'tue': false,
    'wed': false,
    'thu': false,
    'fri': false,
    'sat': false,
    'sun': false,
  };
  bool _requiresPhoto = false;
  bool _autoApprove = false;
  bool _saving = false;
  List<dynamic> _children = [];
  final Set<int> _assigned = {};
  List<dynamic> _templates = [];
  bool _showTemplates = true;

  static const _dayLabels = {
    'mon': 'Mo',
    'tue': 'Di',
    'wed': 'Mi',
    'thu': 'Do',
    'fri': 'Fr',
    'sat': 'Sa',
    'sun': 'So',
  };

  static const _timeOptions = [10, 20, 30, 60];

  static const _deviceOptions = {
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
    _loadChildren();
    _loadTemplates();
    final task = widget.task;
    if (task != null) {
      _showTemplates = false; // Don't show templates when editing
      _titleController.text = task['title'] ?? '';
      _descController.text = task['description'] ?? '';
      _tanReward = task['tan_reward'] ?? task['duration_minutes'] ?? 30;
      // Handle both old target_device (string) and new target_devices (list)
      final targetDevices = task['target_devices'];
      final targetDevice = task['target_device'];
      if (targetDevices is List) {
        for (final device in targetDevices) {
          if (device is String) _targetDevices.add(device);
        }
      } else if (targetDevice is String && targetDevice.isNotEmpty) {
        _targetDevices.add(targetDevice);
      }
      _requiresPhoto = task['requires_photo'] == true;
      _autoApprove = task['auto_approve'] == true;
      final recurrence = task['recurrence'];
      if (recurrence is Map) {
        for (final entry in _recurrence.keys) {
          _recurrence[entry] = recurrence[entry] == true;
        }
      }
      final assigned = task['assigned_children'];
      if (assigned is List) {
        for (final id in assigned) {
          if (id is int) {
            _assigned.add(id);
          }
        }
      }
    }
  }

  Future<void> _loadTemplates() async {
    final api = ref.read(apiClientProvider);
    try {
      final templates = await api.fetchTaskTemplates();
      if (!mounted) return;
      setState(() => _templates = templates);
    } catch (_) {}
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _showTemplates = false;
      _titleController.text = template['title'] ?? '';
      _descController.text = template['description'] ?? '';
      _tanReward = template['tan_reward'] ?? 30;
      _requiresPhoto = template['requires_photo'] == true;
      _autoApprove = template['auto_approve'] == true;
      final devices = template['target_devices'];
      if (devices is List) {
        _targetDevices.clear();
        for (final d in devices) {
          if (d is String) _targetDevices.add(d);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vorlage "${template['title']}" angewendet')),
    );
  }

  Future<void> _loadChildren() async {
    final api = ref.read(apiClientProvider);
    final children = await api.fetchChildren();
    if (!mounted) return;
    setState(() => _children = children);
  }

  Map<String, bool>? _buildRecurrence() {
    if (_recurrence.values.every((value) => value == false)) {
      return null;
    }
    return Map<String, bool>.from(_recurrence);
  }

  void _selectAllDays() {
    setState(() {
      for (final key in _recurrence.keys) {
        _recurrence[key] = true;
      }
    });
  }

  void _selectWeekdays() {
    setState(() {
      _recurrence['mon'] = true;
      _recurrence['tue'] = true;
      _recurrence['wed'] = true;
      _recurrence['thu'] = true;
      _recurrence['fri'] = true;
      _recurrence['sat'] = false;
      _recurrence['sun'] = false;
    });
  }

  void _clearDays() {
    setState(() {
      for (final key in _recurrence.keys) {
        _recurrence[key] = false;
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel ist erforderlich')),
      );
      return;
    }
    if (_targetDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens ein Geraet auswaehlen')),
      );
      return;
    }
    final api = ref.read(apiClientProvider);
    setState(() => _saving = true);
    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'duration_minutes': _tanReward,
      'tan_reward': _tanReward,
      'target_devices': _targetDevices.toList(),
      'requires_photo': _requiresPhoto,
      'auto_approve': _autoApprove,
      'recurrence': _buildRecurrence(),
      'assigned_children': _assigned.isEmpty ? null : _assigned.toList(),
    };
    try {
      if (widget.task == null) {
        await api.createTask(payload);
      } else {
        await api.updateTask(widget.task!['id'] as int, payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  IconData _getTemplateIcon(String? iconName) {
    switch (iconName) {
      case 'menu_book':
        return Icons.menu_book;
      case 'bedroom_child':
        return Icons.bedroom_child;
      case 'emoji_emotions':
        return Icons.emoji_emotions;
      case 'bed':
        return Icons.bed;
      case 'pets':
        return Icons.pets;
      case 'countertops':
        return Icons.countertops;
      case 'delete':
        return Icons.delete_sweep;
      case 'restaurant':
        return Icons.restaurant;
      case 'checkroom':
        return Icons.checkroom;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'music_note':
        return Icons.music_note;
      case 'auto_stories':
        return Icons.auto_stories;
      default:
        return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecurrence = _recurrence.values.any((v) => v);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten'),
        actions: [
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Speichern'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Template Section (only for new tasks)
          if (widget.task == null && _showTemplates && _templates.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flash_on, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Schnellauswahl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _showTemplates = false),
                          child: const Text('Schliessen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates.map((t) {
                        final template = t as Map<String, dynamic>;
                        final isAutoApprove = template['auto_approve'] == true;
                        return ActionChip(
                          avatar: Icon(
                            _getTemplateIcon(template['icon']),
                            size: 18,
                            color: isAutoApprove ? Colors.green : null,
                          ),
                          label: Text(template['title'] ?? ''),
                          backgroundColor: isAutoApprove ? Colors.green.withValues(alpha: 0.15) : null,
                          onPressed: () => _applyTemplate(template),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gruen = Automatisch genehmigt',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Titel
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
              hintText: 'z.B. Zimmer aufraeumen',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Beschreibung
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),

          // Belohnung (Zeit)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Belohnung (Minuten)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _timeOptions.map((minutes) {
                      final selected = _tanReward == minutes;
                      return ChoiceChip(
                        label: Text('$minutes Min'),
                        selected: selected,
                        onSelected: (sel) {
                          if (sel) setState(() => _tanReward = minutes);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Geraete (Multiselect)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Geraete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (_targetDevices.isNotEmpty)
                        Text(
                          '${_targetDevices.length} ausgewaehlt',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fuer welche Geraete kann diese Aufgabe erledigt werden?',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _deviceOptions.entries.map((entry) {
                      final selected = _targetDevices.contains(entry.key);
                      return FilterChip(
                        avatar: Icon(_deviceIcons[entry.key], size: 18),
                        label: Text(entry.value),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _targetDevices.add(entry.key);
                            } else {
                              _targetDevices.remove(entry.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _targetDevices.addAll(_deviceOptions.keys);
                        }),
                        child: const Text('Alle'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _targetDevices.clear()),
                        child: const Text('Keine'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Wiederholung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Wiederholung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (hasRecurrence)
                        TextButton(
                          onPressed: _clearDays,
                          child: const Text('Keine'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectAllDays,
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('Taeglich'),
                      ),
                      TextButton.icon(
                        onPressed: _selectWeekdays,
                        icon: const Icon(Icons.work, size: 18),
                        label: const Text('Werktags'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _recurrence.keys.map((day) {
                      return FilterChip(
                        label: Text(_dayLabels[day] ?? day),
                        selected: _recurrence[day] == true,
                        onSelected: (selected) => setState(() => _recurrence[day] = selected),
                      );
                    }).toList(),
                  ),
                  if (!hasRecurrence)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Ohne Wiederholung: Aufgabe erscheint immer',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Optionen
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Foto erforderlich'),
                  subtitle: const Text('Kind muss ein Beweisfoto hochladen'),
                  value: _requiresPhoto,
                  onChanged: (value) => setState(() => _requiresPhoto = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Automatisch genehmigen'),
                  subtitle: const Text('Keine Eltern-Bestaetigung noetig'),
                  value: _autoApprove,
                  secondary: Icon(
                    Icons.verified,
                    color: _autoApprove ? Colors.green : Colors.grey,
                  ),
                  onChanged: (value) => setState(() => _autoApprove = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Zuweisung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Zuweisung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (_assigned.isNotEmpty)
                        Text(
                          '${_assigned.length} ausgewaehlt',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  if (_children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Keine Kinder gefunden'),
                    )
                  else
                    ..._children.map((child) {
                      final id = child['id'] as int;
                      return CheckboxListTile(
                        title: Text(child['name'] ?? 'Kind $id'),
                        value: _assigned.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _assigned.add(id);
                            } else {
                              _assigned.remove(id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  if (_assigned.isEmpty && _children.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Ohne Zuweisung: Aufgabe gilt fuer alle Kinder',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
