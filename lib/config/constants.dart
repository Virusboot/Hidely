class AppConstants {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  static const String armoniaMockApiToken = String.fromEnvironment('ARMONIA_MOCK_API_TOKEN');
}
