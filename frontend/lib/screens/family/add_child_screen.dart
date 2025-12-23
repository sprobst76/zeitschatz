import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    if (!_formKey.currentState!.validate()) return;

    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.addChildToFamily(
        session.familyId!,
        name: _nameController.text.trim(),
        pin: _pinController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameController.text} wurde hinzugefuegt')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Kind konnte nicht hinzugefuegt werden.';
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
        title: const Text('Kind hinzufuegen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.child_care,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Neues Kind hinzufuegen',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Das Kind kann sich dann mit dem Familiencode und seiner PIN anmelden.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name des Kindes',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'z.B. Max',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Namen eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                  hintText: '4-6 Ziffern',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte PIN eingeben';
                  }
                  if (value.length < 4) {
                    return 'PIN muss mindestens 4 Ziffern haben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onFieldSubmitted: (_) => _addChild(),
                decoration: const InputDecoration(
                  labelText: 'PIN bestaetigen',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != _pinController.text) {
                    return 'PINs stimmen nicht ueberein';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
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
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading ? null : _addChild,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Kind hinzufuegen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
