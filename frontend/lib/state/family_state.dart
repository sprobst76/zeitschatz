import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

class FamilyState {
  final List<dynamic> deviceProviders;
  final bool isLoading;

  const FamilyState({
    this.deviceProviders = const [],
    this.isLoading = false,
  });

  bool get hasKisiDevice {
    return deviceProviders.any((p) => p['provider_type'] == 'kisi');
  }

  bool get hasFamilyLinkDevice {
    return deviceProviders.any((p) => p['provider_type'] == 'family_link');
  }

  String? getProviderForDevice(String deviceType) {
    final config = deviceProviders.firstWhere(
      (p) => p['device_type'] == deviceType,
      orElse: () => null,
    );
    return config?['provider_type'];
  }

  FamilyState copyWith({
    List<dynamic>? deviceProviders,
    bool? isLoading,
  }) {
    return FamilyState(
      deviceProviders: deviceProviders ?? this.deviceProviders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FamilyStateNotifier extends StateNotifier<FamilyState> {
  final Ref _ref;

  FamilyStateNotifier(this._ref) : super(const FamilyState());

  Future<void> loadDeviceProviders() async {
    final session = _ref.read(sessionProvider);
    if (session.familyId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      final providers = await api.fetchDeviceProviders(session.familyId!);
      state = state.copyWith(deviceProviders: providers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void clear() {
    state = const FamilyState();
  }
}

final familyStateProvider = StateNotifierProvider<FamilyStateNotifier, FamilyState>((ref) {
  return FamilyStateNotifier(ref);
});
