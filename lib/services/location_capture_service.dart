import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum LocationConfidence { high, low, unavailable }
enum MediaSource { camera, gallery }

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String? displayName;
  final String source; // 'camera_capture' or 'manual'
  final LocationConfidence confidence;

  CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.displayName,
    this.source = 'camera_capture',
    required this.confidence,
  });

  bool get isHighConfidence => confidence == LocationConfidence.high;
}

class LocationCaptureService {
  static final LocationCaptureService _instance = LocationCaptureService._internal();
  factory LocationCaptureService() => _instance;
  LocationCaptureService._internal();

  static const double preferredAccuracyMeters = 100.0;

  /// Capture high-accuracy device location for camera media capture
  Future<CapturedLocation?> captureCameraLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationCaptureService] Location services disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationCaptureService] Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationCaptureService] Location permission denied forever.');
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: kIsWeb ? LocationAccuracy.high : LocationAccuracy.best,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('[LocationCaptureService] High accuracy getCurrentPosition timeout or error: $e');
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (position == null) {
        return null;
      }

      final accuracy = position.accuracy;
      final confidence = accuracy <= preferredAccuracyMeters
          ? LocationConfidence.high
          : LocationConfidence.low;

      final placeName = await reverseGeocode(position.latitude, position.longitude);

      return CapturedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: accuracy,
        capturedAt: position.timestamp,
        displayName: placeName,
        source: 'camera_capture',
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[LocationCaptureService] Error capturing location: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates using OpenStreetMap Nominatim
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
      final res = await http.get(url, headers: {
        'User-Agent': 'HidelyApp/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final landmark = addr['tourism'] ?? addr['amenity'] ?? addr['attraction'] ?? addr['building'] ?? addr['natural'] ?? addr['park'] ?? addr['suburb'] ?? addr['neighbourhood'];
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'];
          final state = addr['state'];

          if (landmark != null && city != null) {
            return '$landmark, $city';
          } else if (city != null && state != null) {
            return '$city, $state';
          } else if (data['display_name'] != null) {
            final parts = data['display_name'].toString().split(',');
            if (parts.length >= 2) {
              return '${parts[0].trim()}, ${parts[1].trim()}';
            }
            return parts[0].trim();
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Reverse geocode error: $e');
    }
    return null;
  }
}
