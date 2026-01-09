import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routing/app_router.dart';
import 'state/app_state.dart';
import 'services/session_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZeitSchatzApp()));
}

class ZeitSchatzApp extends ConsumerStatefulWidget {
  const ZeitSchatzApp({super.key});

  @override
  ConsumerState<ZeitSchatzApp> createState() => _ZeitSchatzAppState();
}

class _ZeitSchatzAppState extends ConsumerState<ZeitSchatzApp> {
  bool _initialized = false;
  bool _needsBiometric = false;
  bool _biometricFailed = false;

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final sessionNotifier = ref.read(sessionProvider.notifier);
    await sessionNotifier.initialize();

    final session = ref.read(sessionProvider);
    final storage = SessionStorage();

    // Check if we need biometric auth for returning parent users
    if (session.isAuthenticated && session.role == 'parent') {
      final biometricEnabled = await storage.isBiometricEnabled();
      final biometricAvailable = await storage.isBiometricAvailable();

      if (biometricEnabled && biometricAvailable) {
        setState(() {
          _needsBiometric = true;
        });
        await _authenticateWithBiometric();
        return;
      }
    }

    setState(() {
      _initialized = true;
    });
  }

  Future<void> _authenticateWithBiometric() async {
    final storage = SessionStorage();
    final success = await storage.authenticateWithBiometrics(
      reason: 'Bitte mit Fingerabdruck anmelden',
    );

    if (success) {
      setState(() {
        _initialized = true;
        _needsBiometric = false;
      });
    } else {
      setState(() {
        _biometricFailed = true;
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).clear();
    setState(() {
      _initialized = true;
      _needsBiometric = false;
      _biometricFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    // Show loading screen while initializing
    if (!_initialized) {
      if (_needsBiometric) {
        return MaterialApp(
          title: 'ZeitSchatz',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeMode,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 80, color: Colors.teal),
                  const SizedBox(height: 24),
                  const Text(
                    'Bitte authentifizieren',
                    style: TextStyle(fontSize: 18),
                  ),
                  if (_biometricFailed) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _authenticateWithBiometric,
                      child: const Text('Erneut versuchen'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _logout,
                      child: const Text('Abmelden'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      return MaterialApp(
        title: 'ZeitSchatz',
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: themeMode,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ZeitSchatz',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
