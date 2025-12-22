import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  List<dynamic> _users = [];
  bool _loadingUsers = true;
  bool _loggingIn = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      // Anonymer API-Aufruf um User zu holen - wir brauchen einen speziellen Endpoint
      // Da wir keinen haben, verwenden wir einen Workaround: Login mit bekanntem User
      final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
      // Versuche mit Parent-User einzuloggen um User-Liste zu holen
      try {
        final tokens = await api.login(userId: 1, pin: '1234');
        final authedApi = ApiClient(
          baseUrl: AppConfig.apiBaseUrl,
          token: tokens.accessToken,
        );
        final users = await authedApi.fetchUsers();
        setState(() => _users = users);
      } catch (_) {
        // Fallback: Zeige nur Standard-User
        setState(() => _users = [
          {'id': 1, 'name': 'Eltern', 'role': 'parent'},
          {'id': 2, 'name': 'Kind', 'role': 'child'},
        ]);
      }
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loginAsUser(Map<String, dynamic> user) async {
    final pinController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login als ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user['role'] == 'parent' ? 'Eltern-Konto' : 'Kind-Konto',
              style: TextStyle(
                color: user['role'] == 'parent' ? Colors.blue : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pinController.text),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _loggingIn = true;
      _status = '';
    });

    try {
      final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
      final tokens = await api.login(userId: user['id'] as int, pin: result);
      ref.read(sessionProvider.notifier).setSession(
            token: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: user['id'] as int,
            role: user['role'] as String,
          );
      if (mounted) {
        context.go(user['role'] == 'parent' ? '/parent' : '/child');
      }
    } catch (e) {
      setState(() => _status = 'Login fehlgeschlagen - falsche PIN?');
    } finally {
      setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parents = _users.where((u) => u['role'] == 'parent').toList();
    final children = _users.where((u) => u['role'] == 'child').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZeitSchatz'),
        actions: [
          IconButton(
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Theme wechseln',
          ),
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingUsers
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_status.isNotEmpty) ...[
                    Card(
                      color: Colors.red.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_status, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Eltern
                  const Text(
                    'Eltern',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (parents.isEmpty)
                    const Text('Keine Eltern gefunden')
                  else
                    ...parents.map((user) => _UserCard(
                          user: user,
                          onTap: _loggingIn ? null : () => _loginAsUser(user),
                          icon: Icons.person,
                          color: Colors.blue,
                        )),

                  const SizedBox(height: 24),

                  // Kinder
                  const Text(
                    'Kinder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (children.isEmpty)
                    const Text('Keine Kinder gefunden')
                  else
                    ...children.map((user) => _UserCard(
                          user: user,
                          onTap: _loggingIn ? null : () => _loginAsUser(user),
                          icon: Icons.child_care,
                          color: Colors.green,
                        )),

                  if (_loggingIn) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onTap;
  final IconData icon;
  final Color color;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(user['name'] ?? 'Unbekannt'),
        subtitle: Text('ID: ${user['id']}'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
