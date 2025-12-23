import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  int _currentTab = 0;

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final family = await api.createFamily(_familyNameController.text.trim());

      ref.read(sessionProvider.notifier).setFamily(
        familyId: family['id'] as int,
        familyName: family['name'] as String,
      );

      if (mounted) {
        context.go('/parent');
      }
    } catch (e) {
      setState(() {
        _error = 'Familie konnte nicht erstellt werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinFamily() async {
    if (!_joinFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.joinFamily(_inviteCodeController.text.trim().toUpperCase());

      ref.read(sessionProvider.notifier).setFamily(
        familyId: result['family']['id'] as int,
        familyName: result['family']['name'] as String,
      );

      if (mounted) {
        context.go('/parent');
      }
    } catch (e) {
      setState(() {
        _error = 'Einladungscode ungueltig oder abgelaufen.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familie einrichten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionProvider.notifier).clear();
              context.go('/welcome');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Neue Familie'),
                  icon: Icon(Icons.add_home),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Beitreten'),
                  icon: Icon(Icons.group_add),
                ),
              ],
              selected: {_currentTab},
              onSelectionChanged: (selection) {
                setState(() {
                  _currentTab = selection.first;
                  _error = null;
                });
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _currentTab == 0 ? _buildCreateForm(colorScheme) : _buildJoinForm(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(ColorScheme colorScheme) {
    return Form(
      key: _createFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.family_restroom,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Erstelle eine neue Familie',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Als Admin kannst du Kinder hinzufuegen und Aufgaben verwalten.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _familyNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Familienname',
              prefixIcon: Icon(Icons.home_outlined),
              border: OutlineInputBorder(),
              hintText: 'z.B. Familie Mueller',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bitte Familiennamen eingeben';
              }
              return null;
            },
          ),
          if (_error != null && _currentTab == 0) ...[
            const SizedBox(height: 16),
            _buildError(colorScheme),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _createFamily,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Familie erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinForm(ColorScheme colorScheme) {
    return Form(
      key: _joinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.group_add,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Einer Familie beitreten',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Gib den Einladungscode ein, den du erhalten hast.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Einladungscode',
              prefixIcon: Icon(Icons.vpn_key_outlined),
              border: OutlineInputBorder(),
              hintText: 'z.B. ABC123XY',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bitte Einladungscode eingeben';
              }
              return null;
            },
          ),
          if (_error != null && _currentTab == 1) ...[
            const SizedBox(height: 16),
            _buildError(colorScheme),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _joinFamily,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Beitreten'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
