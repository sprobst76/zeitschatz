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
  final _familyCodeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<dynamic>? _children;
  int? _selectedChildId;

  @override
  void dispose() {
    _familyCodeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    if (_familyCodeController.text.length < 4) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // For now, we'll need to use the family code to get children
      // This would require a public endpoint or we skip this step
      // For simplicity, let's just proceed to PIN entry
      setState(() {
        _children = []; // Placeholder - in real app, fetch from API
      });
    } catch (e) {
      setState(() {
        _error = 'Familiencode ungueltig.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tokens = await api.loginWithPin(
        familyCode: _familyCodeController.text.trim().toUpperCase(),
        userId: _selectedChildId ?? 0,
        pin: _pinController.text,
      );

      ref.read(sessionProvider.notifier).setSession(
        token: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: _selectedChildId ?? 0,
        role: 'child',
      );

      if (mounted) {
        context.go('/child');
      }
    } catch (e) {
      setState(() {
        _error = 'Login fehlgeschlagen. Bitte Code und PIN pruefen.';
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
                'Gib den Familiencode und deine PIN ein.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _familyCodeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Familiencode',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'z.B. ABCD1234',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Familiencode eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onFieldSubmitted: (_) => _login(),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                  hintText: '****',
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
    );
  }
}
