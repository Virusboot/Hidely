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
        'http://10.0.2.2:3000', // Android emulator
        'http://localhost:3000', // iOS simulator / Web
      ];

  /// API Key definitions.
  static const String googleMapsApiKey = 'AIzaSyB5ftUcwqjuC1BZtI26KrZsblQIF1Bl7t0';
  static const String armoniaMockApiToken = 'armonia_4f7d92b1c8e6a9f5d3e7b1c9a8f6d2e5b7c1a9f4d8e6b2c3f5a7d9e1b6c8f0';
}
