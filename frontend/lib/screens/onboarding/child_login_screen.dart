import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';

class ChildLoginScreen extends ConsumerStatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  ConsumerState<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends ConsumerState<ChildLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final code = _codeController.text.trim().toUpperCase();
      final tokens = await api.loginWithCode(code);

      // Set session first so apiClientProvider gets updated
      await ref.read(sessionProvider.notifier).setSession(
        token: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: 0, // Will be set from JWT claims
        role: 'child',
      );

      // Trigger password manager save prompt
      TextInput.finishAutofillContext();

      if (mounted) {
        context.go('/child');
      }
    } catch (e) {
      setState(() {
        _error = 'Login fehlgeschlagen. Bitte Code pruefen.';
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
        title: const Text('Kind-Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.child_care,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Hallo!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gib deinen Login-Code ein.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.username],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Login-Code',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: const OutlineInputBorder(),
                  hintText: 'TIGER-BLAU-42',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    fontSize: 20,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Code eingeben';
                  }
                  if (value.length < 8) {
                    return 'Code ist zu kurz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Frag deine Eltern nach dem Code!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Anmelden'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Text formatter to convert input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
