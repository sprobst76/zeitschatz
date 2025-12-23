import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';

class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  Map<String, dynamic>? _family;
  List<dynamic> _members = [];
  List<dynamic> _deviceProviders = [];
  bool _isLoading = true;
  String? _inviteCode;
  bool _generatingCode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.fetchFamily(session.familyId!),
        api.fetchFamilyMembers(session.familyId!),
        api.fetchDeviceProviders(session.familyId!),
      ]);

      setState(() {
        _family = results[0] as Map<String, dynamic>;
        _members = results[1] as List<dynamic>;
        _deviceProviders = results[2] as List<dynamic>;
        _inviteCode = _family?['invite_code'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteCode() async {
    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    setState(() => _generatingCode = true);

    try {
      final api = ref.read(apiClientProvider);
      final code = await api.generateInviteCode(session.familyId!);
      setState(() => _inviteCode = code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neuer Einladungscode erstellt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      setState(() => _generatingCode = false);
    }
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code kopiert')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familie verwalten'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Family Name Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.family_restroom, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Familie',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            session.familyName ?? _family?['name'] ?? 'Unbekannt',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invite Code Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.share, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Einladungscode',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_inviteCode != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _inviteCode!,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: _copyInviteCode,
                                    tooltip: 'Kopieren',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Teile diesen Code, um andere einzuladen.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Kein aktiver Einladungscode.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _generatingCode ? null : _generateInviteCode,
                            icon: _generatingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(_inviteCode != null ? 'Neuen Code erstellen' : 'Code erstellen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Members Section
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.people, color: colorScheme.primary),
                          title: const Text('Mitglieder'),
                          subtitle: Text('${_members.length} Personen'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/family/members'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Device Providers Section
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.devices, color: colorScheme.primary),
                          title: const Text('Geraete-Provider'),
                          subtitle: Text('${_deviceProviders.length} konfiguriert'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/family/devices'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Add Child Button
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.child_care, color: colorScheme.primary),
                          title: const Text('Kind hinzufuegen'),
                          trailing: const Icon(Icons.add),
                          onTap: () => context.push('/family/add-child'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
