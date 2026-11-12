import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:hidely_new/config/constants.dart';
import 'package:hidely_new/services/api_service.dart';

enum LocationConfidence { high, low, unavailable }

enum MediaSource { camera, gallery }

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String? displayName;
  final String source; // 'camera_capture', 'photo_exif', or 'manual'
  final LocationConfidence confidence;
  final String? canonicalName;
  final String? city;
  final String? state;
  final String? country;
  final String? landmarkType;

  CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.displayName,
    this.source = 'camera_capture',
    required this.confidence,
    this.canonicalName,
    this.city,
    this.state,
    this.country,
    this.landmarkType,
  });

  bool get isHighConfidence => confidence == LocationConfidence.high;

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  String get label {
    final name = displayName?.trim() ?? '';
    return name.isNotEmpty ? name : formattedCoordinates;
  }

  CapturedLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? capturedAt,
    String? displayName,
    String? source,
    LocationConfidence? confidence,
    String? canonicalName,
    String? city,
    String? state,
    String? country,
    String? landmarkType,
  }) {
    return CapturedLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAt: capturedAt ?? this.capturedAt,
      displayName: displayName ?? this.displayName,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      canonicalName: canonicalName ?? this.canonicalName,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      landmarkType: landmarkType ?? this.landmarkType,
    );
  }
}

class ReverseGeocodeResult {
  final String displayName;
  final String? canonicalName;
  final String? city;
  final String? state;
  final String? country;
  final String? landmarkType;

  const ReverseGeocodeResult({
    required this.displayName,
    this.canonicalName,
    this.city,
    this.state,
    this.country,
    this.landmarkType,
  });
}

class PlaceSuggestion {
  final String displayName;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? city;
  final String? state;
  final String? country;
  final String? landmarkType;

  const PlaceSuggestion({
    required this.displayName,
    this.subtitle = '',
    this.latitude,
    this.longitude,
    this.placeId,
    this.city,
    this.state,
    this.country,
    this.landmarkType,
  });

  bool get hasCoordinates =>
      LocationCaptureService.isValidCoordinatePair(latitude, longitude);
}

class LocationCaptureService {
  static final LocationCaptureService _instance = LocationCaptureService._internal();
  factory LocationCaptureService() => _instance;
  LocationCaptureService._internal();

  static const double preferredAccuracyMeters = 100.0;
  static const double targetRefinedAccuracyMeters = 20.0;
  static const double triggerRefinementAboveMeters = 30.0;

  static final Map<String, ReverseGeocodeResult> _reverseCache = {};
  static final Map<String, List<PlaceSuggestion>> _searchCache = {};

  @visibleForTesting
  http.Client? httpClientOverride;

  @visibleForTesting
  bool skipNativeGeocoderForTest = false;

  @visibleForTesting
  Future<ReverseGeocodeResult?> Function(double lat, double lon)? nativePlacemarkOverride;

  @visibleForTesting
  Duration? accuracyRefinementTimeoutOverride;

  String? lastErrorMessage;
  bool lastServiceEnabled = true;
  LocationPermission? lastPermission;

  @visibleForTesting
  static void clearCachesForTest() {
    _reverseCache.clear();
    _searchCache.clear();
  }

  http.Client get _http => httpClientOverride ?? http.Client();

  /// Check whether [lat]/[lon] form a finite, bounded, non-(0,0) coordinate pair.
  static bool isValidCoordinatePair(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (!lat.isFinite || !lon.isFinite) return false;
    if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) return false;
    if (lat.abs() < 0.0001 && lon.abs() < 0.0001) return false;
    return true;
  }

  static bool _isPlusCodeLike(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,4}$',
            caseSensitive: false)
        .hasMatch(trimmed);
  }

  LocationSettings _buildLocationSettings({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    Duration? timeLimit,
  }) {
    if (kIsWeb) {
      return LocationSettings(
        accuracy: accuracy == LocationAccuracy.bestForNavigation
            ? LocationAccuracy.best
            : accuracy,
        distanceFilter: 0,
        timeLimit: timeLimit,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        timeLimit: timeLimit,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: 0,
      timeLimit: timeLimit,
    );
  }

  /// Capture high-accuracy device location for live camera capture or explicit user GPS request.
  Future<CapturedLocation?> captureCameraLocation({
    bool forceFresh = false,
    bool refineAccuracy = true,
  }) async {
    lastErrorMessage = null;
    lastServiceEnabled = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      lastServiceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        lastErrorMessage =
            'Location services (GPS) are turned off. Please enable GPS to detect your current location.';
        debugPrint('[LocationCaptureService] Location services disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      lastPermission = permission;

      if (permission == LocationPermission.denied) {
        lastErrorMessage =
            'Location permission denied. Allow location access to tag your current spot.';
        debugPrint('[LocationCaptureService] Location permission denied.');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        lastErrorMessage =
            'Location permission is permanently denied. Enable it in App Settings.';
        debugPrint('[LocationCaptureService] Location permission denied forever.');
        return null;
      }

      Position? bestPosition;

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _buildLocationSettings(
            accuracy: kIsWeb ? LocationAccuracy.best : LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 7),
          ),
        );
        if (isValidCoordinatePair(pos.latitude, pos.longitude)) {
          bestPosition = pos;
        }
      } catch (e) {
        debugPrint(
            '[LocationCaptureService] High accuracy getCurrentPosition timeout or error: $e');
      }

      // Refine accuracy if initial fix is coarse (> 30m) or timed out (using brief position stream).
      final bool needsRefinement = refineAccuracy &&
          (bestPosition == null || bestPosition.accuracy > triggerRefinementAboveMeters);
      if (needsRefinement) {
        final timeout = accuracyRefinementTimeoutOverride ??
            (bestPosition == null
                ? const Duration(seconds: 5)
                : const Duration(seconds: 4));
        bestPosition = await _refineWithPositionStream(
          initialBest: bestPosition,
          timeout: timeout,
        );
      }

      bool usedLastKnownFallback = false;
      if (bestPosition == null) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null &&
              isValidCoordinatePair(lastKnown.latitude, lastKnown.longitude)) {
            final age = DateTime.now().difference(lastKnown.timestamp).abs();
            if (age.inHours <= 24 && (!forceFresh || age.inMinutes <= 60)) {
              bestPosition = lastKnown;
              usedLastKnownFallback = true;
            }
          }
        } catch (e) {
          debugPrint('[LocationCaptureService] getLastKnownPosition failed: $e');
        }
      }

      if (bestPosition == null) {
        lastErrorMessage =
            'Could not lock onto GPS signal yet. Move near a window/outdoors or pick a place manually.';
        return null;
      }

      final double accuracy = bestPosition.accuracy;
      final ageMinutes = DateTime.now().difference(bestPosition.timestamp).abs().inMinutes;
      final confidence = (!usedLastKnownFallback || ageMinutes <= 30) &&
              accuracy <= preferredAccuracyMeters
          ? LocationConfidence.high
          : LocationConfidence.low;

      final detailed = await reverseGeocodeDetailed(
        bestPosition.latitude,
        bestPosition.longitude,
      );

      return CapturedLocation(
        latitude: bestPosition.latitude,
        longitude: bestPosition.longitude,
        accuracyMeters: accuracy,
        capturedAt: bestPosition.timestamp,
        displayName: detailed?.displayName,
        canonicalName: detailed?.canonicalName,
        city: detailed?.city,
        state: detailed?.state,
        country: detailed?.country,
        landmarkType: detailed?.landmarkType,
        source: 'camera_capture',
        confidence: confidence,
      );
    } catch (e) {
      lastErrorMessage = 'Unable to get device location right now.';
      debugPrint('[LocationCaptureService] Error capturing location: $e');
      return null;
    }
  }

  Future<Position?> _refineWithPositionStream({
    Position? initialBest,
    required Duration timeout,
  }) async {
    Position? best = initialBest;
    final completer = Completer<Position?>();
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish() {
      if (!completer.isCompleted) {
        completer.complete(best);
      }
    }

    timer = Timer(timeout, finish);

    try {
      sub = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.best : LocationAccuracy.bestForNavigation,
        ),
      ).listen(
        (pos) {
          if (!isValidCoordinatePair(pos.latitude, pos.longitude)) return;
          if (best == null || pos.accuracy < best!.accuracy) {
            best = pos;
          }
          if (pos.accuracy <= targetRefinedAccuracyMeters) {
            finish();
          }
        },
        onError: (_) => finish(),
        onDone: finish,
        cancelOnError: true,
      );

      return await completer.future;
    } catch (_) {
      return best;
    } finally {
      timer.cancel();
      await sub?.cancel();
    }
  }

  /// Reverse geocode coordinates returning display name + city/state/country breakdown.
  Future<ReverseGeocodeResult?> reverseGeocodeDetailed(double lat, double lon) async {
    if (!isValidCoordinatePair(lat, lon)) return null;

    final cacheKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    final cached = _reverseCache[cacheKey];
    if (cached != null) return cached;

    ReverseGeocodeResult? resolved;

    // 1. Google Geocoding (via Backend proxy on Web, direct Google Geocoding API on Mobile)
    resolved ??= await _reverseWithGoogleOrProxy(lat, lon);

    // 2. OpenStreetMap Nominatim (zoom=18 for landmark/POI & neighborhood precision)
    resolved ??= await _reverseWithNominatim(lat, lon);

    // 3. Photon Reverse Geocoder
    resolved ??= await _reverseWithPhoton(lat, lon);

    // 4. Native Device Geocoder (Android Geocoder / iOS CLGeocoder)
    resolved ??= await _reverseWithNativePlacemark(lat, lon);

    if (resolved != null && resolved.displayName.trim().isNotEmpty) {
      _reverseCache[cacheKey] = resolved;
    }
    return resolved;
  }

  /// Reverse geocode coordinates returning a concise display string.
  Future<String?> reverseGeocode(double lat, double lon) async {
    final result = await reverseGeocodeDetailed(lat, lon);
    return result?.displayName;
  }

  Future<ReverseGeocodeResult?> _reverseWithGoogleOrProxy(double lat, double lon) async {
    try {
      const apiKey = AppConstants.googleMapsApiKey;
      final Uri url = (kIsWeb || apiKey.isEmpty)
          ? Uri.parse('${ApiService().baseUrl}/api/map/reverse-geocode?lat=$lat&lng=$lon')
          : Uri.parse(
              'https://maps.googleapis.com/maps/api/geocode/json'
              '?latlng=$lat,$lon&language=en&key=$apiKey',
            );

      final res = await _http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;

      // Backend /reverse-geocode response shape
      if (data['display_name'] != null && data['status'] == 'OK') {
        final display = data['display_name'].toString().trim();
        if (display.isNotEmpty) {
          return ReverseGeocodeResult(
            displayName: display,
            canonicalName: data['landmark']?.toString() ?? display,
            city: data['city']?.toString(),
            state: data['state']?.toString(),
            country: data['country']?.toString(),
            landmarkType: data['landmark_type']?.toString(),
          );
        }
      }

      // Google Geocoding API response shape
      if (data['status'] == 'OK' && data['results'] is List) {
        return _parseGoogleResults(data['results'] as List);
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Google/proxy reverse geocode error: $e');
    }
    return null;
  }

  ReverseGeocodeResult? _parseGoogleResults(List<dynamic> results) {
    if (results.isEmpty) return null;

    String? landmark;
    String? landmarkType;
    String? sublocality;
    String? route;
    String? city;
    String? state;
    String? country;

    const priorityTypes = <String>[
      'tourist_attraction',
      'natural_feature',
      'park',
      'point_of_interest',
      'establishment',
      'premise',
    ];

    for (final rawResult in results) {
      if (rawResult is! Map) continue;
      final components = rawResult['address_components'] as List?;
      if (components == null) continue;

      for (final rawComp in components) {
        if (rawComp is! Map) continue;
        final types = (rawComp['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final name = rawComp['long_name']?.toString().trim() ?? '';
        if (name.isEmpty || _isPlusCodeLike(name)) continue;

        if (landmark == null) {
          for (final t in priorityTypes) {
            if (types.contains(t)) {
              landmark = name;
              landmarkType = t;
              break;
            }
          }
        }
        sublocality ??= (types.contains('sublocality_level_1') ||
                types.contains('sublocality_level_2') ||
                types.contains('neighborhood') ||
                types.contains('sublocality'))
            ? name
            : null;
        route ??= types.contains('route') ? name : null;
        city ??= (types.contains('locality') || types.contains('postal_town')) ? name : null;
        city ??= types.contains('administrative_area_level_2') ? name : null;
        state ??= types.contains('administrative_area_level_1') ? name : null;
        country ??= types.contains('country') ? name : null;
      }
    }

    final firstFormatted = (results.first is Map)
        ? results.first['formatted_address']?.toString()
        : null;
    final chosenLandmark = landmark ?? sublocality ?? route;
    final display = _formatDisplayName(
      landmark: chosenLandmark,
      city: city,
      state: state,
      country: country,
      fallbackFormatted: firstFormatted,
    );
    if (display == null) return null;

    return ReverseGeocodeResult(
      displayName: display,
      canonicalName: chosenLandmark ?? city ?? state ?? display,
      city: city,
      state: state,
      country: country,
      landmarkType: landmarkType ?? (sublocality != null ? 'neighborhood' : 'locality'),
    );
  }

  Future<ReverseGeocodeResult?> _reverseWithNominatim(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final res = await _http.get(url, headers: {
        'User-Agent': 'HidelyTravelApp/1.0 (https://hidely.app)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final rawName = data['name']?.toString().trim();
            final landmark = (rawName != null && rawName.isNotEmpty ? rawName : null) ??
                addr['tourism']?.toString() ??
                addr['natural']?.toString() ??
                addr['attraction']?.toString() ??
                addr['historic']?.toString() ??
                addr['leisure']?.toString() ??
                addr['waterway']?.toString() ??
                addr['park']?.toString() ??
                addr['amenity']?.toString() ??
                addr['building']?.toString() ??
                addr['neighbourhood']?.toString() ??
                addr['quarter']?.toString() ??
                addr['suburb']?.toString() ??
                addr['city_district']?.toString() ??
                addr['road']?.toString() ??
                addr['hamlet']?.toString();
            final city = addr['city']?.toString() ??
                addr['town']?.toString() ??
                addr['village']?.toString() ??
                addr['municipality']?.toString() ??
                addr['county']?.toString() ??
                addr['state_district']?.toString();
            final state = addr['state']?.toString();
            final country = addr['country']?.toString();

            final display = _formatDisplayName(
              landmark: landmark,
              city: city,
              state: state,
              country: country,
              fallbackFormatted: data['display_name']?.toString(),
            );
            if (display != null) {
              return ReverseGeocodeResult(
                displayName: display,
                canonicalName: landmark ?? city ?? state ?? display,
                city: city,
                state: state,
                country: country,
                landmarkType: data['type']?.toString() ?? data['category']?.toString(),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Nominatim reverse geocode error: $e');
    }
    return null;
  }

  Future<ReverseGeocodeResult?> _reverseWithPhoton(double lat, double lon) async {
    try {
      final url = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lon&lang=en');
      final res = await _http.get(url, headers: {
        'User-Agent': 'HidelyTravelApp/1.0 (https://hidely.app)',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> &&
            data['features'] is List &&
            (data['features'] as List).isNotEmpty) {
          final props = (data['features'] as List).first['properties'] as Map?;
          if (props != null) {
            final landmark = props['name']?.toString() ??
                props['district']?.toString() ??
                props['locality']?.toString() ??
                props['street']?.toString();
            final city = props['city']?.toString() ?? props['county']?.toString();
            final state = props['state']?.toString();
            final country = props['country']?.toString();
            final display = _formatDisplayName(
              landmark: landmark,
              city: city,
              state: state,
              country: country,
            );
            if (display != null) {
              return ReverseGeocodeResult(
                displayName: display,
                canonicalName: landmark ?? city ?? state ?? display,
                city: city,
                state: state,
                country: country,
                landmarkType: props['osm_value']?.toString() ?? props['type']?.toString(),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Photon reverse geocode error: $e');
    }
    return null;
  }

  Future<ReverseGeocodeResult?> _reverseWithNativePlacemark(double lat, double lon) async {
    if (nativePlacemarkOverride != null) {
      return await nativePlacemarkOverride!(lat, lon);
    }
    if (kIsWeb || skipNativeGeocoderForTest) return null;

    try {
      final placemarks = await geocoding
          .placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 4));
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      final landmark = (p.subLocality?.trim().isNotEmpty == true)
          ? p.subLocality!.trim()
          : ((p.name?.trim().isNotEmpty == true && !_isPlusCodeLike(p.name!))
              ? p.name!.trim()
              : p.thoroughfare?.trim());
      final city = (p.locality?.trim().isNotEmpty == true)
          ? p.locality!.trim()
          : p.subAdministrativeArea?.trim();
      final state = p.administrativeArea?.trim();
      final country = p.country?.trim();

      final display = _formatDisplayName(
        landmark: landmark,
        city: city,
        state: state,
        country: country,
      );
      if (display == null) return null;

      return ReverseGeocodeResult(
        displayName: display,
        canonicalName: landmark ?? city ?? state ?? display,
        city: city,
        state: state,
        country: country,
        landmarkType: 'locality',
      );
    } catch (e) {
      debugPrint('[LocationCaptureService] Native geocoding error: $e');
      return null;
    }
  }

  String? _formatDisplayName({
    String? landmark,
    String? city,
    String? state,
    String? country,
    String? fallbackFormatted,
  }) {
    final List<String> parts = [];

    void addUnique(String? raw) {
      final clean = raw?.trim() ?? '';
      if (clean.isEmpty || _isPlusCodeLike(clean)) return;
      final cleanLower = clean.toLowerCase();
      final alreadyIncluded = parts.any(
        (existing) =>
            existing.toLowerCase() == cleanLower ||
            existing.toLowerCase().contains(cleanLower),
      );
      if (!alreadyIncluded) {
        parts.add(clean);
      }
    }

    addUnique(landmark);
    addUnique(city);
    if (parts.length < 2) addUnique(state);
    if (parts.isEmpty) addUnique(country);

    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    if (parts.length == 1) {
      return parts[0];
    }

    if (fallbackFormatted != null && fallbackFormatted.trim().isNotEmpty) {
      final rawParts = fallbackFormatted
          .split(',')
          .map((e) => e.trim())
          .where((e) =>
              e.isNotEmpty && !_isPlusCodeLike(e) && !RegExp(r'^\d{5,6}$').hasMatch(e))
          .toList();
      if (rawParts.length >= 2) {
        return '${rawParts[0]}, ${rawParts[1]}';
      }
      if (rawParts.isNotEmpty) {
        return rawParts.first;
      }
    }
    return null;
  }

  /// Extract GPS location from Gallery AssetEntity (MediaStore / PHAsset `latlngAsync()` + EXIF/Video fallback).
  Future<CapturedLocation?> extractLocationFromAsset(pm.AssetEntity asset) async {
    try {
      double? lat;
      double? lon;
      double accuracyMeters = 10.0;
      DateTime capturedAt = asset.createDateTime;

      // 1. OS media library metadata (`latlngAsync` handles Android 10+ & iOS PHAsset)
      try {
        final pm.LatLng? mediaLatLng = await asset.latlngAsync();
        if (mediaLatLng != null &&
            isValidCoordinatePair(mediaLatLng.latitude, mediaLatLng.longitude)) {
          lat = mediaLatLng.latitude;
          lon = mediaLatLng.longitude;
        }
      } catch (e) {
        debugPrint('[LocationCaptureService] asset.latlngAsync error: $e');
      }

      // 2. Fallback: Read unredacted original bytes/file if latlngAsync returned null/(0,0)
      if (!isValidCoordinatePair(lat, lon) && !kIsWeb) {
        if (asset.type == pm.AssetType.video) {
          final videoFile = await asset.originFile ?? await asset.file;
          if (videoFile != null) {
            final gps = await extractVideoGpsFromFile(videoFile);
            if (gps != null) {
              lat = gps['latitude'];
              lon = gps['longitude'];
            }
          }
        } else {
          Uint8List? originBytes;
          try {
            originBytes = await asset.originBytes;
          } catch (_) {}
          if (originBytes != null && originBytes.isNotEmpty) {
            final exifMeta = await extractExifGpsWithMetadata(originBytes);
            if (exifMeta != null) {
              lat = exifMeta['latitude'] as double?;
              lon = exifMeta['longitude'] as double?;
              accuracyMeters = (exifMeta['accuracyMeters'] as double?) ?? 10.0;
              capturedAt = (exifMeta['capturedAt'] as DateTime?) ?? capturedAt;
            }
          }
          if (!isValidCoordinatePair(lat, lon)) {
            final imgFile = await asset.originFile ?? await asset.file;
            if (imgFile != null) {
              try {
                final fileBytes = await imgFile.readAsBytes();
                final exifMeta = await extractExifGpsWithMetadata(fileBytes);
                if (exifMeta != null) {
                  lat = exifMeta['latitude'] as double?;
                  lon = exifMeta['longitude'] as double?;
                  accuracyMeters = (exifMeta['accuracyMeters'] as double?) ?? 10.0;
                  capturedAt = (exifMeta['capturedAt'] as DateTime?) ?? capturedAt;
                }
              } catch (_) {}
            }
          }
        }
      }

      if (!isValidCoordinatePair(lat, lon)) return null;

      final detailed = await reverseGeocodeDetailed(lat!, lon!);
      return CapturedLocation(
        latitude: lat,
        longitude: lon,
        accuracyMeters: accuracyMeters,
        capturedAt: capturedAt,
        displayName: detailed?.displayName,
        canonicalName: detailed?.canonicalName,
        city: detailed?.city,
        state: detailed?.state,
        country: detailed?.country,
        landmarkType: detailed?.landmarkType,
        source: 'photo_exif',
        confidence: LocationConfidence.high,
      );
    } catch (e) {
      debugPrint('[LocationCaptureService] extractLocationFromAsset error: $e');
      return null;
    }
  }

  /// Extract GPS location from either an image or video File without loading large videos into RAM.
  Future<CapturedLocation?> extractLocationFromFile(
    File file, {
    Uint8List? bytesHint,
  }) async {
    try {
      final pathLower = file.path.toLowerCase();
      final bool isVideo = pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.m4v') ||
          pathLower.endsWith('.3gp') ||
          pathLower.endsWith('.mkv') ||
          pathLower.endsWith('.avi') ||
          pathLower.endsWith('.webm') ||
          pathLower.contains('/video/');

      if (isVideo) {
        final gps = await extractVideoGpsFromFile(file);
        if (gps == null) return null;
        final lat = gps['latitude']!;
        final lon = gps['longitude']!;
        final detailed = await reverseGeocodeDetailed(lat, lon);
        return CapturedLocation(
          latitude: lat,
          longitude: lon,
          accuracyMeters: 10.0,
          capturedAt: DateTime.now(),
          displayName: detailed?.displayName,
          canonicalName: detailed?.canonicalName,
          city: detailed?.city,
          state: detailed?.state,
          country: detailed?.country,
          landmarkType: detailed?.landmarkType,
          source: 'photo_exif',
          confidence: LocationConfidence.high,
        );
      }

      final bytes = bytesHint ?? await file.readAsBytes();
      return await extractLocationFromBytes(bytes);
    } catch (e) {
      debugPrint('[LocationCaptureService] extractLocationFromFile error: $e');
      return null;
    }
  }

  /// Extract GPS location from Image or small Video Bytes (EXIF or ISO-6709 metadata).
  Future<CapturedLocation?> extractLocationFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final exifMeta = await extractExifGpsWithMetadata(bytes);
      double? lat = exifMeta?['latitude'] as double?;
      double? lon = exifMeta?['longitude'] as double?;
      double accuracyMeters = (exifMeta?['accuracyMeters'] as double?) ?? 10.0;
      DateTime capturedAt = (exifMeta?['capturedAt'] as DateTime?) ?? DateTime.now();

      if (!isValidCoordinatePair(lat, lon)) {
        final videoGps = extractVideoIso6709Gps(bytes);
        if (videoGps != null) {
          lat = videoGps['latitude'];
          lon = videoGps['longitude'];
        }
      }

      if (isValidCoordinatePair(lat, lon)) {
        final detailed = await reverseGeocodeDetailed(lat!, lon!);
        return CapturedLocation(
          latitude: lat,
          longitude: lon,
          accuracyMeters: accuracyMeters,
          capturedAt: capturedAt,
          displayName: detailed?.displayName,
          canonicalName: detailed?.canonicalName,
          city: detailed?.city,
          state: detailed?.state,
          country: detailed?.country,
          landmarkType: detailed?.landmarkType,
          source: 'photo_exif',
          confidence: LocationConfidence.high,
        );
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Error extracting photo location: $e');
    }
    return null;
  }

  /// Extract EXIF GPS coordinates along with positioning error & capture timestamp if present.
  Future<Map<String, dynamic>?> extractExifGpsWithMetadata(Uint8List bytes) async {
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
        final double d = _ratioToDouble(degrees);
        final double m = _ratioToDouble(minutes);
        final double s = _ratioToDouble(seconds);
        if (d < 0) {
          return -(d.abs() + (m.abs() / 60.0) + (s.abs() / 3600.0));
        }
        return d + (m / 60.0) + (s / 3600.0);
      }

      double lat = convertToDegrees(latValues[0], latValues[1], latValues[2]);
      double lon = convertToDegrees(lonValues[0], lonValues[1], lonValues[2]);

      if (latRefTag != null && latRefTag.printable.toUpperCase().contains('S') && lat > 0) {
        lat = -lat;
      }
      if (lonRefTag != null && lonRefTag.printable.toUpperCase().contains('W') && lon > 0) {
        lon = -lon;
      }

      if (!isValidCoordinatePair(lat, lon)) return null;

      double accuracyMeters = 10.0;
      final hErrTag =
          data['GPS GPSHPositioningError'] ?? data['GPS Tag 0x001F'];
      if (hErrTag != null && hErrTag.values.toList().isNotEmpty) {
        final parsedErr = _ratioToDouble(hErrTag.values.toList().first);
        if (parsedErr.isFinite && parsedErr > 0) {
          accuracyMeters = parsedErr;
        }
      }

      DateTime? capturedAt;
      final dateStr = data['EXIF DateTimeOriginal']?.printable ??
          data['Image DateTime']?.printable ??
          data['EXIF DateTimeDigitized']?.printable;
      if (dateStr != null) {
        capturedAt = _parseExifDateTime(dateStr);
      }

      return {
        'latitude': lat,
        'longitude': lon,
        'accuracyMeters': accuracyMeters,
        if (capturedAt != null) 'capturedAt': capturedAt,
      };
    } catch (e) {
      debugPrint('[LocationCaptureService] EXIF GPS extraction error: $e');
      return null;
    }
  }

  /// Extract raw latitude and longitude from EXIF bytes.
  Future<Map<String, double>?> extractExifGps(Uint8List bytes) async {
    final meta = await extractExifGpsWithMetadata(bytes);
    if (meta == null) return null;
    return {
      'latitude': meta['latitude'] as double,
      'longitude': meta['longitude'] as double,
    };
  }

  /// Extract GPS coordinates from an MP4/MOV video file by inspecting header and tail atoms.
  Future<Map<String, double>?> extractVideoGpsFromFile(File file) async {
    if (kIsWeb) return null;
    RandomAccessFile? raf;
    try {
      if (!await file.exists()) return null;
      final int length = await file.length();
      if (length <= 0) return null;

      // Read first 2MB and last 2MB where QuickTime moov/udta/©xyz atoms reside
      const int maxSliceBytes = 2 * 1024 * 1024;
      if (length <= maxSliceBytes * 2) {
        final bytes = await file.readAsBytes();
        return extractVideoIso6709Gps(bytes);
      }

      raf = await file.open(mode: FileMode.read);
      final head = await raf.read(maxSliceBytes);
      final fromHead = extractVideoIso6709Gps(head);
      if (fromHead != null) return fromHead;

      await raf.setPosition(length - maxSliceBytes);
      final tail = await raf.read(maxSliceBytes);
      return extractVideoIso6709Gps(tail);
    } catch (e) {
      debugPrint('[LocationCaptureService] Video GPS file extraction error: $e');
      return null;
    } finally {
      await raf?.close();
    }
  }

  /// Parse MP4/MOV ISO-6709 GPS coordinates (e.g. `©xyz` box payload `+28.6139+077.2090/`).
  Map<String, double>? extractVideoIso6709Gps(Uint8List bytes) {
    if (bytes.length < 12) return null;
    try {
      final text = latin1.decode(bytes, allowInvalid: true);

      // Prefer explicit `©xyz` (`\xA9xyz`) or Apple QuickTime ISO6709 tag context
      final xyzPattern = RegExp(
        r'(?:\xA9xyz|com\.apple\.quicktime\.location\.ISO6709|location)[^\r\n]{0,32}?([+-]\d{1,2}\.\d{3,})([+-]\d{1,3}\.\d{3,})(?:[+-]\d+(?:\.\d+)?)?/?',
      );
      for (final match in xyzPattern.allMatches(text)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        if (isValidCoordinatePair(lat, lon)) {
          return {'latitude': lat!, 'longitude': lon!};
        }
      }

      // Generic strict ISO-6709 pattern ending with `/`
      final isoPattern = RegExp(
        r'([+-](?:90(?:\.0+)?|[0-8]?\d\.\d{3,}))([+-](?:180(?:\.0+)?|1[0-7]\d\.\d{3,}|0?\d{1,2}\.\d{3,}))(?:[+-]\d+(?:\.\d+)?)?/',
      );
      for (final match in isoPattern.allMatches(text)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        if (isValidCoordinatePair(lat, lon)) {
          return {'latitude': lat!, 'longitude': lon!};
        }
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] ISO-6709 parse error: $e');
    }
    return null;
  }

  DateTime? _parseExifDateTime(String raw) {
    // Standard EXIF format: "YYYY:MM:DD HH:MM:SS"
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
        .firstMatch(raw.trim());
    if (match == null) return null;
    final y = int.tryParse(match.group(1)!);
    final mo = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);
    final h = int.tryParse(match.group(4)!);
    final mi = int.tryParse(match.group(5)!);
    final s = int.tryParse(match.group(6)!);
    if (y == null || mo == null || d == null || h == null || mi == null || s == null) {
      return null;
    }
    return DateTime(y, mo, d, h, mi, s);
  }

  double _ratioToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.isFinite ? val.toDouble() : 0.0;
    if (val is Ratio) {
      final result = val.toDouble();
      return result.isFinite ? result : 0.0;
    }
    try {
      final str = val.toString();
      if (str.contains('/')) {
        final parts = str.split('/');
        final n = double.tryParse(parts[0]) ?? 0.0;
        final d = double.tryParse(parts[1]) ?? 1.0;
        if (d == 0.0) return 0.0;
        final result = n / d;
        return result.isFinite ? result : 0.0;
      }
      final parsed = double.tryParse(str) ?? 0.0;
      return parsed.isFinite ? parsed : 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Autocomplete place suggestions for manual location search (includes coordinates & structured fields).
  Future<List<PlaceSuggestion>> searchPlaceSuggestions(
    String query, {
    double? biasLat,
    double? biasLon,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final cacheKey =
        '${cleanQuery.toLowerCase()}|${biasLat?.toStringAsFixed(2) ?? ''}|${biasLon?.toStringAsFixed(2) ?? ''}';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final List<PlaceSuggestion> results = [];
    final Set<String> seenNames = {};

    void addSuggestion(PlaceSuggestion s) {
      final key = s.displayName.trim().toLowerCase();
      if (key.isEmpty || seenNames.contains(key)) return;
      seenNames.add(key);
      results.add(s);
    }

    // 1. Try Hidely Backend Autocomplete (uses Google Places + Photon fallback)
    try {
      final biasParams = isValidCoordinatePair(biasLat, biasLon)
          ? '&lat=$biasLat&lng=$biasLon'
          : '';
      final backendUrl = Uri.parse(
        '${ApiService().baseUrl}/api/map/autocomplete?input=${Uri.encodeComponent(cleanQuery)}$biasParams',
      );
      final res = await _http.get(backendUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'OK' && data['predictions'] is List) {
          for (final pred in (data['predictions'] as List)) {
            if (pred is! Map) continue;
            final mainText = pred['structured_formatting']?['main_text']?.toString() ?? '';
            final secondaryText =
                pred['structured_formatting']?['secondary_text']?.toString() ?? '';
            final desc = pred['description']?.toString() ?? mainText;
            final placeId = pred['place_id']?.toString();
            final geomLoc = pred['geometry']?['location'];
            double? lat = (geomLoc?['lat'] as num?)?.toDouble();
            double? lng = (geomLoc?['lng'] as num?)?.toDouble();

            if (!isValidCoordinatePair(lat, lng) &&
                placeId != null &&
                placeId.startsWith('photon_')) {
              final parts = placeId.split('_');
              if (parts.length >= 3) {
                lat = double.tryParse(parts[1]);
                lng = double.tryParse(parts[2]);
              }
            }

            addSuggestion(
              PlaceSuggestion(
                displayName: desc,
                subtitle: secondaryText,
                latitude: isValidCoordinatePair(lat, lng) ? lat : null,
                longitude: isValidCoordinatePair(lat, lng) ? lng : null,
                placeId: placeId,
                city: pred['city']?.toString(),
                state: pred['state']?.toString(),
                country: pred['country']?.toString(),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationCaptureService] Backend autocomplete error: $e');
    }

    // 2. Direct Photon search fallback (returns instant coords & city/state/country)
    if (results.length < 3) {
      try {
        final bias = isValidCoordinatePair(biasLat, biasLon)
            ? '&lat=$biasLat&lon=$biasLon'
            : '';
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=8&lang=en$bias',
        );
        final res = await _http.get(photonUrl, headers: {
          'User-Agent': 'HidelyTravelApp/1.0 (https://hidely.app)',
        }).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['features'] is List) {
            for (final feature in (data['features'] as List)) {
              if (feature is! Map) continue;
              final props = feature['properties'] as Map? ?? {};
              final coords = feature['geometry']?['coordinates'] as List? ?? [];
              final lon = coords.isNotEmpty ? (coords[0] as num?)?.toDouble() : null;
              final lat = coords.length > 1 ? (coords[1] as num?)?.toDouble() : null;
              if (!isValidCoordinatePair(lat, lon)) continue;

              final name = props['name']?.toString().trim() ?? '';
              final city = (props['city'] ?? props['county'])?.toString().trim() ?? '';
              final state = props['state']?.toString().trim() ?? '';
              final country = props['country']?.toString().trim() ?? '';
              final display = _formatDisplayName(
                landmark: name.isNotEmpty ? name : props['street']?.toString(),
                city: city,
                state: state,
                country: country,
              );
              if (display == null) continue;

              final subtitle = [city, state, country]
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .join(', ');
              addSuggestion(
                PlaceSuggestion(
                  displayName: display,
                  subtitle: subtitle,
                  latitude: lat,
                  longitude: lon,
                  placeId: 'photon_${lat}_$lon',
                  city: city.isNotEmpty ? city : null,
                  state: state.isNotEmpty ? state : null,
                  country: country.isNotEmpty ? country : null,
                  landmarkType:
                      props['osm_value']?.toString() ?? props['type']?.toString(),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[LocationCaptureService] Photon autocomplete error: $e');
      }
    }

    // 3. OpenStreetMap Nominatim Search fallback
    if (results.isEmpty) {
      try {
        final nomUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(cleanQuery)}&limit=5&addressdetails=1',
        );
        final res = await _http.get(nomUrl, headers: {
          'User-Agent': 'HidelyTravelApp/1.0 (https://hidely.app)',
          'Accept-Language': 'en',
        }).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) {
            for (final item in data) {
              if (item is! Map) continue;
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');
              if (!isValidCoordinatePair(lat, lon)) continue;
              final addr = item['address'] as Map? ?? {};
              final name = item['name']?.toString();
              final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'])
                  ?.toString();
              final state = addr['state']?.toString();
              final country = addr['country']?.toString();
              final display = _formatDisplayName(
                landmark: name,
                city: city,
                state: state,
                country: country,
                fallbackFormatted: item['display_name']?.toString(),
              );
              if (display == null) continue;
              addSuggestion(
                PlaceSuggestion(
                  displayName: display,
                  subtitle: item['display_name']?.toString() ?? '',
                  latitude: lat,
                  longitude: lon,
                  city: city,
                  state: state,
                  country: country,
                  landmarkType: item['type']?.toString(),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[LocationCaptureService] Nominatim search error: $e');
      }
    }

    if (results.isNotEmpty) {
      _searchCache[cacheKey] = results;
    }
    return results;
  }

  /// Resolve a picked [PlaceSuggestion] to a full [CapturedLocation] with verified coordinates.
  Future<CapturedLocation?> resolvePlaceSuggestion(PlaceSuggestion suggestion) async {
    double? lat = suggestion.latitude;
    double? lon = suggestion.longitude;
    String? city = suggestion.city;
    String? state = suggestion.state;
    String? country = suggestion.country;

    if (!isValidCoordinatePair(lat, lon) &&
        suggestion.placeId != null &&
        suggestion.placeId!.isNotEmpty) {
      if (suggestion.placeId!.startsWith('photon_')) {
        final parts = suggestion.placeId!.split('_');
        if (parts.length >= 3) {
          lat = double.tryParse(parts[1]);
          lon = double.tryParse(parts[2]);
        }
      } else {
        try {
          final url = Uri.parse(
            '${ApiService().baseUrl}/api/map/details?place_id=${Uri.encodeComponent(suggestion.placeId!)}',
          );
          final res = await _http.get(url).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data is Map && data['status'] == 'OK' && data['result'] is Map) {
              final loc = data['result']['geometry']?['location'];
              lat = (loc?['lat'] as num?)?.toDouble();
              lon = (loc?['lng'] as num?)?.toDouble();
            }
          }
        } catch (e) {
          debugPrint('[LocationCaptureService] Place details resolve error: $e');
        }
      }
    }

    if (!isValidCoordinatePair(lat, lon)) {
      return geocodePlace(suggestion.displayName);
    }

    if ((city == null || state == null || country == null)) {
      final rev = await reverseGeocodeDetailed(lat!, lon!);
      city ??= rev?.city;
      state ??= rev?.state;
      country ??= rev?.country;
    }

    return CapturedLocation(
      latitude: lat!,
      longitude: lon!,
      accuracyMeters: 25.0,
      capturedAt: DateTime.now(),
      displayName: suggestion.displayName,
      canonicalName: suggestion.displayName.split(',').first.trim(),
      city: city,
      state: state,
      country: country,
      landmarkType: suggestion.landmarkType ?? 'manual_place',
      source: 'manual',
      confidence: LocationConfidence.high,
    );
  }

  /// Forward-geocode a custom typed place name to a [CapturedLocation].
  Future<CapturedLocation?> geocodePlace(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final suggestions = await searchPlaceSuggestions(clean);
    for (final s in suggestions) {
      if (s.hasCoordinates) {
        return resolvePlaceSuggestion(s);
      }
    }

    if (!kIsWeb && !skipNativeGeocoderForTest) {
      try {
        final locs = await geocoding
            .locationFromAddress(clean)
            .timeout(const Duration(seconds: 4));
        if (locs.isNotEmpty) {
          final first = locs.first;
          if (isValidCoordinatePair(first.latitude, first.longitude)) {
            final detailed = await reverseGeocodeDetailed(first.latitude, first.longitude);
            return CapturedLocation(
              latitude: first.latitude,
              longitude: first.longitude,
              accuracyMeters: 50.0,
              capturedAt: DateTime.now(),
              displayName: clean,
              canonicalName: clean.split(',').first.trim(),
              city: detailed?.city,
              state: detailed?.state,
              country: detailed?.country,
              landmarkType: detailed?.landmarkType ?? 'manual_place',
              source: 'manual',
              confidence: LocationConfidence.high,
            );
          }
        }
      } catch (e) {
        debugPrint('[LocationCaptureService] Native forward geocode error: $e');
      }
    }
    return null;
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
        reason:
            'Screenshots cannot be uploaded. Please choose real photos clicked with your camera.',
      );
    }

    // 2. Check EXIF software / metadata for screenshot signatures (skip for video/empty payloads)
    final bool isVideo = nameLower.endsWith('.mp4') ||
        nameLower.endsWith('.mov') ||
        nameLower.endsWith('.m4v') ||
        nameLower.endsWith('.mkv') ||
        nameLower.endsWith('.avi');
    if (!isVideo && bytes.isNotEmpty) {
      try {
        final Map<String, IfdTag> exifData = await readExifFromBytes(bytes);
        final software = (exifData['Image Software']?.printable ?? '').toLowerCase();
        if (software.contains('screenshot') || software.contains('screen capture')) {
          return MediaValidationResult(
            isValid: false,
            isScreenshot: true,
            reason:
                'Screenshots cannot be uploaded. Please choose real photos clicked with your camera.',
          );
        }
      } catch (_) {}
    }

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
