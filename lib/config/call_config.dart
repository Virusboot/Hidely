class CallConfig {
  static const bool usesWebRtc = true;

  // Kept empty so no third-party calling secrets exist in source/binaries.
  static const int appId = int.fromEnvironment('ZEGO_APP_ID', defaultValue: 0);
  static const String appSign = String.fromEnvironment('ZEGO_APP_SIGN', defaultValue: '');

  static bool get isConfigured => appId > 0 && appSign.trim().isNotEmpty;

  static const List<Map<String, dynamic>> defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
  ];
}
