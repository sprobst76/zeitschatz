import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'user_editor_screen.dart';

class ParentKidsScreen extends ConsumerStatefulWidget {
  const ParentKidsScreen({super.key});

  @override
  ConsumerState<ParentKidsScreen> createState() => _ParentKidsScreenState();
}

class _ParentKidsScreenState extends ConsumerState<ParentKidsScreen> {
  List<dynamic> _users = [];
  bool _loading = true;

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
      final users = await api.fetchUsers();
      setState(() => _users = users);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addUser({required String role}) async {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final isParent = role == 'parent';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isParent ? 'Neuer Elternteil' : 'Neues Kind'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: 'PIN (4-8 Ziffern)'),
              keyboardType: TextInputType.number,
              obscureText: true,
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
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final name = nameController.text.trim();
    final pin = pinController.text.trim();
    if (name.isEmpty || pin.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name und PIN (mind. 4 Ziffern) erforderlich')),
        );
      }
      return;
    }
    final api = ref.read(apiClientProvider);
    try {
      await api.createUser(name: name, role: role, pin: pin);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name wurde angelegt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UserEditorScreen(user: user),
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  Widget _buildDeviceChips(List<dynamic>? allowedDevices) {
    if (allowedDevices == null || allowedDevices.isEmpty) {
      return Builder(
        builder: (context) => Text(
          'Alle Geraete',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allowedDevices.whereType<String>().map((device) {
        return Builder(
          builder: (context) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _deviceIcons[device] ?? Icons.devices,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  _deviceLabels[device] ?? device,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isParent = user['role'] == 'parent';
    final isActive = user['is_active'] != false;
    final allowedDevices = user['allowed_devices'] as List<dynamic>?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => _editUser(user),
        leading: Builder(
          builder: (context) => CircleAvatar(
            backgroundColor: isParent
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.green.withValues(alpha: 0.15),
            child: Icon(
              isParent ? Icons.person : Icons.child_care,
              color: isParent ? Theme.of(context).colorScheme.primary : Colors.green,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              user['name'] ?? 'Unbekannt',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? null : Colors.grey,
                decoration: isActive ? null : TextDecoration.lineThrough,
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Inaktiv',
                  style: TextStyle(fontSize: 10, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
        subtitle: !isParent
            ? _buildDeviceChips(allowedDevices)
            : Text('ID: ${user['id']}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final parents = _users.where((u) => u['role'] == 'parent').toList();
    final children = _users.where((u) => u['role'] == 'child').toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addUser(role: 'child'),
                    icon: const Icon(Icons.child_care),
                    label: const Text('Kind'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _addUser(role: 'parent'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Elternteil'),
                  ),
                ),
              ],
            ),
          ),

          // Kinder
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Kinder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Keine Kinder'),
            )
          else
            ...children.map((user) => _buildUserCard(user as Map<String, dynamic>)),

          // Eltern
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Eltern', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (parents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Keine Eltern'),
            )
          else
            ...parents.map((user) => _buildUserCard(user as Map<String, dynamic>)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
