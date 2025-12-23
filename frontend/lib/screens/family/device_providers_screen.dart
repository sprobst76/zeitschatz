import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

class DeviceProvidersScreen extends ConsumerStatefulWidget {
  const DeviceProvidersScreen({super.key});

  @override
  ConsumerState<DeviceProvidersScreen> createState() => _DeviceProvidersScreenState();
}

class _DeviceProvidersScreenState extends ConsumerState<DeviceProvidersScreen> {
  List<dynamic> _deviceProviders = [];
  List<dynamic> _availableProviders = [];
  bool _isLoading = true;

  static const _deviceTypes = ['phone', 'pc', 'tablet', 'console'];

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
        api.fetchDeviceProviders(session.familyId!),
        api.fetchAvailableProviders(),
      ]);

      setState(() {
        _deviceProviders = results[0] as List<dynamic>;
        _availableProviders = results[1] as List<dynamic>;
      });
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

  String? _getProviderForDevice(String deviceType) {
    final config = _deviceProviders.firstWhere(
      (p) => p['device_type'] == deviceType,
      orElse: () => null,
    );
    return config?['provider_type'];
  }

  Future<void> _setProvider(String deviceType, String providerType) async {
    final session = ref.read(sessionProvider);
    if (session.familyId == null) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.setDeviceProvider(session.familyId!, deviceType, providerType);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provider fuer ${_getDeviceLabel(deviceType)} gespeichert')),
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

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'phone':
        return Icons.phone_android;
      case 'pc':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      case 'console':
        return Icons.videogame_asset;
      default:
        return Icons.devices;
    }
  }

  String _getDeviceLabel(String deviceType) {
    switch (deviceType) {
      case 'phone':
        return 'Handy';
      case 'pc':
        return 'PC/Laptop';
      case 'tablet':
        return 'Tablet';
      case 'console':
        return 'Konsole';
      default:
        return deviceType;
    }
  }

  IconData _getProviderIcon(String providerType) {
    switch (providerType) {
      case 'kisi':
        return Icons.pin;
      case 'family_link':
        return Icons.family_restroom;
      case 'manual':
        return Icons.edit_note;
      default:
        return Icons.settings;
    }
  }

  String _getProviderLabel(String providerType) {
    switch (providerType) {
      case 'kisi':
        return 'Salfeld Kisi (TAN)';
      case 'family_link':
        return 'Google Family Link';
      case 'manual':
        return 'Manuell';
      default:
        return providerType;
    }
  }

  String _getProviderDescription(String providerType) {
    switch (providerType) {
      case 'kisi':
        return 'TAN-Codes aus dem Pool verwenden';
      case 'family_link':
        return 'Zeit manuell in Family Link freigeben';
      case 'manual':
        return 'Einfaches Tracking ohne externes System';
      default:
        return '';
    }
  }

  void _showProviderPicker(String deviceType) {
    final currentProvider = _getProviderForDevice(deviceType);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Provider fuer ${_getDeviceLabel(deviceType)}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              ..._availableProviders.map((provider) {
                final code = provider['code'] as String;
                final isSelected = code == currentProvider;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _getProviderIcon(code),
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(_getProviderLabel(code)),
                  subtitle: Text(_getProviderDescription(code)),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _setProvider(deviceType, code);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geraete-Provider'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Waehle fuer jedes Geraet, wie Belohnungen verwaltet werden sollen.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._deviceTypes.map((deviceType) {
                    final currentProvider = _getProviderForDevice(deviceType);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _getDeviceIcon(deviceType),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(_getDeviceLabel(deviceType)),
                        subtitle: Text(
                          currentProvider != null
                              ? _getProviderLabel(currentProvider)
                              : 'Nicht konfiguriert',
                          style: TextStyle(
                            color: currentProvider != null
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showProviderPicker(deviceType),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Hinweis',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kisi: TANs werden aus dem importierten Pool verwendet.\n\n'
                            'Family Link: Du gibst die Zeit manuell in der Family Link App frei.\n\n'
                            'Manuell: Nur zur Zeiterfassung, keine externe Integration.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
