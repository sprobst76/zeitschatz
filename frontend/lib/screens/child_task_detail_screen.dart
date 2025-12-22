import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ChildTaskDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;
  const ChildTaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<ChildTaskDetailScreen> createState() => _ChildTaskDetailScreenState();
}

class _ChildTaskDetailScreenState extends ConsumerState<ChildTaskDetailScreen> {
  Uint8List? _photoBytes;
  String? _photoName;
  String? _selectedDevice;
  bool _submitting = false;

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

  List<String> get _availableDevices {
    final targetDevices = widget.task['target_devices'];
    final targetDevice = widget.task['target_device'];

    if (targetDevices is List && targetDevices.isNotEmpty) {
      return targetDevices.whereType<String>().toList();
    } else if (targetDevice is String && targetDevice.isNotEmpty) {
      return [targetDevice];
    }
    return ['phone', 'pc', 'console'];
  }

  @override
  void initState() {
    super.initState();
    final devices = _availableDevices;
    if (devices.length == 1) {
      _selectedDevice = devices.first;
    }
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _photoBytes = file.bytes;
      _photoName = file.name;
    });
  }

  Future<void> _submit() async {
    final api = ref.read(apiClientProvider);
    final requiresPhoto = widget.task['requires_photo'] == true;

    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ein Geraet auswaehlen')),
      );
      return;
    }

    if (requiresPhoto && _photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ein Foto hinzufuegen')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final submission = await api.submitTask(
        taskId: widget.task['id'] as int,
        comment: 'Erledigt',
        selectedDevice: _selectedDevice,
      );
      if (_photoBytes != null && _photoName != null) {
        await api.uploadPhoto(
          submissionId: submission['id'] as int,
          bytes: _photoBytes!,
          filename: _photoName!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aufgabe eingereicht')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einreichen fehlgeschlagen')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiresPhoto = widget.task['requires_photo'] == true;
    final tanReward = widget.task['tan_reward'] ?? widget.task['duration_minutes'] ?? 0;
    final availableDevices = _availableDevices;

    return Scaffold(
      appBar: AppBar(title: Text(widget.task['title'] ?? 'Aufgabe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Task-Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.task['description'] != null &&
                      widget.task['description'].toString().isNotEmpty) ...[
                    Text(
                      widget.task['description'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '$tanReward Minuten',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Geraete-Auswahl
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fuer welches Geraet?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) => Text(
                      'Waehle das Geraet, fuer das du die Zeit haben moechtest',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableDevices.map((device) {
                      final isSelected = _selectedDevice == device;
                      return ChoiceChip(
                        avatar: Icon(
                          _deviceIcons[device] ?? Icons.devices,
                          size: 18,
                        ),
                        label: Text(_deviceLabels[device] ?? device),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedDevice = device);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Foto-Bereich
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_camera),
                      const SizedBox(width: 8),
                      Text(
                        requiresPhoto ? 'Foto erforderlich' : 'Foto (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: requiresPhoto ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _photoBytes!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _photoName ?? 'Foto',
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _photoBytes = null;
                            _photoName = null;
                          }),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Entfernen', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Foto aufnehmen oder auswaehlen'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_selectedDevice != null
                ? 'Fuer ${_deviceLabels[_selectedDevice] ?? _selectedDevice} einreichen'
                : 'Aufgabe einreichen'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
