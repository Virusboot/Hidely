import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:exif/exif.dart';

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

  /// Extract GPS location from Image Bytes (EXIF metadata)
  Future<CapturedLocation?> extractLocationFromBytes(Uint8List bytes) async {
    try {
      final gps = await extractExifGps(bytes);
      if (gps != null) {
        final double lat = gps['latitude']!;
        final double lon = gps['longitude']!;
        final placeName = await reverseGeocode(lat, lon);

        return CapturedLocation(
          latitude: lat,
          longitude: lon,
          accuracyMeters: 5.0,
          capturedAt: DateTime.now(),
          displayName: placeName,
          source: 'photo_exif',
          confidence: LocationConfidence.high,
        );
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Error extracting photo location: $e');
    }
    return null;
  }

  /// Extract raw latitude and longitude from EXIF bytes
  Future<Map<String, double>?> extractExifGps(Uint8List bytes) async {
    try {
      final Map<String, IfdTag> data = await readExifFromBytes(bytes);
      if (data.isEmpty) return null;

      final latTag = data['GPS GPSLatitude'];
      final latRefTag = data['GPS GPSLatitudeRef'];
      final lonTag = data['GPS GPSLongitude'];
      final lonRefTag = data['GPS GPSLongitudeRef'];

      if (latTag == null || lonTag == null) return null;

      final latValues = latTag.values.toList();
      final lonValues = lonTag.values.toList();

      if (latValues.length < 3 || lonValues.length < 3) return null;

      double convertToDegrees(dynamic degrees, dynamic minutes, dynamic seconds) {
        double d = _ratioToDouble(degrees);
        double m = _ratioToDouble(minutes);
        double s = _ratioToDouble(seconds);
        return d + (m / 60.0) + (s / 3600.0);
      }

      double lat = convertToDegrees(latValues[0], latValues[1], latValues[2]);
      double lon = convertToDegrees(lonValues[0], lonValues[1], lonValues[2]);

      if (latRefTag != null && latRefTag.printable.toUpperCase().contains('S')) {
        lat = -lat;
      }
      if (lonRefTag != null && lonRefTag.printable.toUpperCase().contains('W')) {
        lon = -lon;
      }

      if (lat != 0.0 || lon != 0.0) {
        return {'latitude': lat, 'longitude': lon};
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] EXIF GPS extraction error: $e');
    }
    return null;
  }

  double _ratioToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is Ratio) return val.toDouble();
    try {
      final str = val.toString();
      if (str.contains('/')) {
        final parts = str.split('/');
        final n = double.tryParse(parts[0]) ?? 0;
        final d = double.tryParse(parts[1]) ?? 1;
        return d != 0 ? n / d : 0;
      }
      return double.tryParse(str) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Validate image integrity to block screenshots and unauthorized internet downloads
  Future<MediaValidationResult> validateMediaIntegrity({
    required Uint8List bytes,
    String? filename,
    required bool isOfficialUser,
  }) async {
    // Official Hidely verified accounts can upload internet downloads and curated media
    if (isOfficialUser) {
      return MediaValidationResult(
        isValid: true,
        isScreenshot: false,
        reason: 'Authorized Official Account',
      );
    }

    final nameLower = (filename ?? '').toLowerCase();

    // 1. Check Screenshot patterns in filename (Specifically targeting screenshots, NOT shared photos)
    final bool hasScreenshotName = nameLower.contains('screenshot') ||
        nameLower.contains('screen_shot') ||
        nameLower.contains('screen-shot') ||
        nameLower.contains('screencapture') ||
        nameLower.contains('screen_recording') ||
        nameLower.contains('screen-capture');

    if (hasScreenshotName) {
      return MediaValidationResult(
        isValid: false,
        isScreenshot: true,
        reason: 'Screenshots cannot be uploaded. Please choose real photos clicked with your camera.',
      );
    }

    // 2. Check EXIF software / metadata for screenshot signatures
    try {
      final Map<String, IfdTag> exifData = await readExifFromBytes(bytes);
      final software = (exifData['Image Software']?.printable ?? '').toLowerCase();
      if (software.contains('screenshot') || software.contains('screen capture')) {
        return MediaValidationResult(
          isValid: false,
          isScreenshot: true,
          reason: 'Screenshots cannot be uploaded. Please choose real photos clicked with your camera.',
        );
      }
    } catch (_) {}

    return MediaValidationResult(
      isValid: true,
      isScreenshot: false,
      reason: 'Valid original media',
    );
  }
}

class MediaValidationResult {
  final bool isValid;
  final bool isScreenshot;
  final String reason;

  MediaValidationResult({
    required this.isValid,
    required this.isScreenshot,
    required this.reason,
  });
}

