import 'package:flutter/foundation.dart';

class AppConfig {
  /// Returns the API base URL based on environment
  static String get apiBaseUrl {
    // For web, check if we have a configured URL
    if (kIsWeb) {
      // In production, API is at zeitschatz-api.DOMAIN
      // Check current host to determine API URL
      const configuredUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '',
      );
      if (configuredUrl.isNotEmpty) {
        return configuredUrl;
      }
      // Default for local development
      return 'http://localhost:8070';
    }

    // For mobile/desktop, use local network or configured URL
    const configuredUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.0.144:8070',
    );
    return configuredUrl;
  }
}
