class CallConfig {
  // Supplied via --dart-define=ZEGO_APP_ID=... --dart-define=ZEGO_APP_SIGN=...
  static const int appId = int.fromEnvironment('ZEGO_APP_ID', defaultValue: 0);
  static const String appSign = String.fromEnvironment('ZEGO_APP_SIGN', defaultValue: '');

  static bool get isConfigured => appId > 0 && appSign.trim().isNotEmpty;
}
