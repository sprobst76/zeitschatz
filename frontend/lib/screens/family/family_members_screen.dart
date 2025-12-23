import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final members = await api.fetchFamilyMembers(session.familyId!);
      setState(() => _members = members);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(int userId, String name) async {
    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mitglied entfernen'),
        content: Text('Moechtest du "$name" wirklich aus der Familie entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.removeFamilyMember(session.familyId!, userId);
      await _loadMembers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name wurde entfernt')),
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

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'parent':
        return Icons.person;
      case 'child':
        return Icons.child_care;
      default:
        return Icons.person_outline;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'parent':
        return 'Elternteil';
      case 'child':
        return 'Kind';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familienmitglieder'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: _members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Mitglieder gefunden',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final userId = member['user_id'] as int;
                        final userName = member['user_name'] as String? ?? 'Unbekannt';
                        final role = member['role_in_family'] as String;
                        final isCurrentUser = userId == session.userId;
                        final isAdmin = role == 'admin';

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAdmin
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              child: Icon(
                                _getRoleIcon(role),
                                color: isAdmin
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(userName),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Du',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(_getRoleLabel(role)),
                            trailing: (!isCurrentUser && !isAdmin)
                                ? IconButton(
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      color: colorScheme.error,
                                    ),
                                    onPressed: () => _removeMember(userId, userName),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
