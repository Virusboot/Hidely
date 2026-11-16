import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadQualityService {
  static final UploadQualityService _instance = UploadQualityService._internal();
  factory UploadQualityService() => _instance;
  UploadQualityService._internal();

  static const String _key = 'high_quality_uploads';
  bool _isHighQuality = false;
  bool _initialized = false;

  final ValueNotifier<bool> isHighQualityNotifier = ValueNotifier<bool>(false);

  bool get isHighQuality => _isHighQuality;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHighQuality = prefs.getBool(_key) ?? false;
      isHighQualityNotifier.value = _isHighQuality;
      _initialized = true;
    } catch (_) {
      _isHighQuality = false;
    }
  }

  Future<void> setHighQuality(bool value) async {
    _isHighQuality = value;
    isHighQualityNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  int get imageQuality => _isHighQuality ? 95 : 75;

  double? get maxDimension => _isHighQuality ? 2560.0 : 1440.0;
}

