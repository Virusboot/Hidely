import 'package:flutter/foundation.dart';

/// Environment mode enum.
enum Environment { dev, staging, prod }

/// Centralized environment and API configuration manager.
class AppEnv {
  AppEnv._();

  /// Current running environment mode.
  static Environment currentEnvironment = kReleaseMode ? Environment.prod : Environment.dev;

  /// Resolves API Base URL according to active environment.
  static String get apiBaseUrl {
    switch (currentEnvironment) {
      case Environment.dev:
        return 'https://hidely-backend.onrender.com';
      case Environment.staging:
        return 'https://staging-hidely-backend.onrender.com';
      case Environment.prod:
        return 'https://hidely-backend.onrender.com';
    }
  }

  /// Local fallback servers for development testing.
  static List<String> get localDiscoveryUrls => const [
        'http://10.0.2.2:5050', // Android emulator (Port 5050)
        'http://localhost:5050', // iOS simulator / Web (Port 5050)
        'http://10.0.2.2:5000', // Android emulator (Port 5000 default)
        'http://localhost:5000', // iOS simulator / Web (Port 5000 default)
        'http://10.0.2.2:3000', // Android emulator (Port 3000 legacy)
        'http://localhost:3000', // iOS simulator / Web (Port 3000 legacy)
      ];

  /// API Key definitions.
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String armoniaMockApiToken = String.fromEnvironment('ARMONIA_MOCK_API_TOKEN');
}
