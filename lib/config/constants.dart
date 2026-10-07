class AppConstants {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyCNU24xs5Ky9uQ3pHfhyv9ofkjUd_o5_yI',
  );
  static const String armoniaMockApiToken = String.fromEnvironment('ARMONIA_MOCK_API_TOKEN');
}
