import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  final _pinController = TextEditingController();
  String _status = '';
  bool _loading = false;

  Future<void> _login({required String role}) async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final userId = role == 'parent' ? 1 : 2; // Seed IDs aus Backend
      final api = ApiClient();
      final token = await api.login(userId: userId, pin: _pinController.text);
      ref.read(sessionProvider.notifier).setSession(token: token, userId: userId, role: role);
      if (mounted) {
        context.go(role == 'parent' ? '/parent' : '/child');
      }
    } catch (e) {
      setState(() => _status = 'Login fehlgeschlagen');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZeitSchatz – Rolle wählen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PIN (Seed: Eltern 1234, Kind 0000)'),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'PIN'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : () => _login(role: 'parent'),
                  child: const Text('Ich bin Eltern'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : () => _login(role: 'child'),
                  child: const Text('Ich bin Kind'),
                ),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_status, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
