import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class UserEditorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  const UserEditorScreen({super.key, required this.user});

  @override
  ConsumerState<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends ConsumerState<UserEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  final Set<String> _allowedDevices = {};
  bool _saving = false;
  bool _isActive = true;

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

  bool get _isChild => widget.user['role'] == 'child';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name'] ?? '');
    _pinController = TextEditingController();
    _isActive = widget.user['is_active'] != false;

    final allowedDevices = widget.user['allowed_devices'];
    if (allowedDevices is List) {
      for (final device in allowedDevices) {
        if (device is String) _allowedDevices.add(device);
      }
    } else if (_isChild) {
      // Default: all devices allowed for new/existing children without config
      _allowedDevices.addAll(_deviceOptions.keys);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name ist erforderlich')),
      );
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.isNotEmpty && pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN muss mindestens 4 Ziffern haben')),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'is_active': _isActive,
    };

    if (pin.isNotEmpty) {
      payload['pin'] = pin;
    }

    if (_isChild) {
      payload['allowed_devices'] = _allowedDevices.toList();
    }

    try {
      await api.updateUser(widget.user['id'] as int, payload);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gespeichert')),
      );
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

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Benutzer deaktivieren?'),
        content: Text(
          'Moechtest du "${widget.user['name']}" wirklich deaktivieren? '
          'Der Benutzer kann sich dann nicht mehr anmelden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = ref.read(apiClientProvider);
      try {
        await api.deactivateUser(widget.user['id'] as int);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.user['name']} wurde deaktiviert')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isChild ? 'Kind bearbeiten' : 'Elternteil bearbeiten'),
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
          // User info header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _isChild
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    child: Icon(
                      _isChild ? Icons.child_care : Icons.person,
                      size: 32,
                      color: _isChild ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user['name'] ?? 'Unbekannt',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Builder(builder: (context) => Text(
                          _isChild ? 'Kind' : 'Elternteil',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        )),
                        Builder(builder: (context) => Text(
                          'ID: ${widget.user['id']}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // PIN
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: 'Neue PIN (leer lassen, um aktuelle zu behalten)',
              border: OutlineInputBorder(),
              helperText: 'Mindestens 4 Ziffern',
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          const SizedBox(height: 24),

          // Device permissions (only for children)
          if (_isChild) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices),
                        const SizedBox(width: 8),
                        const Text(
                          'Erlaubte Geraete',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        if (_allowedDevices.isNotEmpty)
                          Builder(builder: (context) => Text(
                            '${_allowedDevices.length} ausgewaehlt',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Builder(builder: (context) => Text(
                      'Fuer welche Geraete kann dieses Kind TANs einloesen?',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    )),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _deviceOptions.entries.map((entry) {
                        final selected = _allowedDevices.contains(entry.key);
                        return FilterChip(
                          avatar: Icon(_deviceIcons[entry.key], size: 18),
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _allowedDevices.add(entry.key);
                              } else {
                                _allowedDevices.remove(entry.key);
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
                            _allowedDevices.addAll(_deviceOptions.keys);
                          }),
                          child: const Text('Alle'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _allowedDevices.clear()),
                          child: const Text('Keine'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Active status
          Card(
            child: SwitchListTile(
              title: const Text('Aktiv'),
              subtitle: Text(
                _isActive
                    ? 'Benutzer kann sich anmelden'
                    : 'Benutzer ist deaktiviert',
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ),
          const SizedBox(height: 32),

          // Deactivate button
          if (_isActive)
            OutlinedButton.icon(
              onPressed: _confirmDeactivate,
              icon: const Icon(Icons.block, color: Colors.red),
              label: const Text('Benutzer deaktivieren', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}
