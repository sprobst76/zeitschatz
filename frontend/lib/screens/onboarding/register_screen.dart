import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      // Trigger password manager save prompt
      TextInput.finishAutofillContext();

      if (mounted) {
        // Show verification hint
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registrierung erfolgreich'),
            content: const Text(
              'Wir haben dir eine E-Mail zur Bestaetigung geschickt. '
              'Bitte klicke auf den Link in der E-Mail, um dein Konto zu aktivieren.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: const Text('Zum Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Registrierung fehlgeschlagen. Vielleicht ist die E-Mail bereits vergeben.';
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
        title: const Text('Registrieren'),
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
                Icons.person_add,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Name eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte E-Mail eingeben';
                  }
                  if (!value.contains('@')) {
                    return 'Bitte gueltige E-Mail eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Passwort eingeben';
                  }
                  if (value.length < 8) {
                    return 'Passwort muss mindestens 8 Zeichen haben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: 'Passwort bestaetigen',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwoerter stimmen nicht ueberein';
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
              FilledButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrieren'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bereits ein Konto?'),
                  TextButton(
                    onPressed: () => context.pushReplacement('/login'),
                    child: const Text('Anmelden'),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
