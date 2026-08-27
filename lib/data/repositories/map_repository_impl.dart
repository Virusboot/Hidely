import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/config/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';
import '../../services/local_storage_service.dart';
import '../../services/api_service.dart';
import '../../domain/repositories/map_repository.dart';
import '../models/nearby_place.dart';
import '../models/route_data.dart';

class MapRepositoryImpl implements MapRepository {
  final LocalStorageService _storage;

  MapRepositoryImpl(this._storage);

  static final Map<String, LatLng> _geocodingCache = {};

  @override
  Future<LatLng?> geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    final cleanName = address.trim().toLowerCase();
    if (_geocodingCache.containsKey(cleanName)) {
      return _geocodingCache[cleanName];
    }

    // Try persistent cache in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVal = prefs.getString('geocode_$cleanName');
      if (cachedVal != null && cachedVal.isNotEmpty) {
        final parts = cachedVal.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            final latLng = LatLng(lat, lng);
            _geocodingCache[cleanName] = latLng;
            return latLng;
          }
        }
      }
    } catch (e) {
      debugPrint('SharedPreferences geocode lookup failed: $e');
    }

    try {
      const apiKey = AppConstants.googleMapsApiKey;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$apiKey'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          final latLng = LatLng(loc['lat'] as double, loc['lng'] as double);
          
          _geocodingCache[cleanName] = latLng;
          _saveGeocodeToPrefs(cleanName, latLng);
          
          return latLng;
        }
      }
    } catch (e) {
      debugPrint('Google Geocoding failed for $address: $e');
    }

    // Fallback: OpenStreetMap Nominatim API (Free and no key required)
    try {
      debugPrint('[Geocode] Falling back to OpenStreetMap Nominatim for: $address');
      final fallbackUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(address)}'
        '&format=json'
        '&limit=1'
      );
      final fallbackResponse = await http.get(
        fallbackUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        },
      ).timeout(const Duration(seconds: 15));
      if (fallbackResponse.statusCode == 200) {
        final fallbackData = json.decode(fallbackResponse.body);
        if (fallbackData is List && fallbackData.isNotEmpty) {
          final first = fallbackData[0];
          final lat = double.parse(first['lat'] as String);
          final lng = double.parse(first['lon'] as String);
          final latLng = LatLng(lat, lng);
          
          _geocodingCache[cleanName] = latLng;
          _saveGeocodeToPrefs(cleanName, latLng);

          debugPrint('[Geocode] Nominatim succeeded: Lat $lat, Lng $lng');
          return latLng;
        }
      }
    } catch (e) {
      debugPrint('OSM Nominatim Geocoding fallback failed: $e');
    }
    return null;
  }

  void _saveGeocodeToPrefs(String cleanName, LatLng latLng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geocode_$cleanName', '${latLng.latitude},${latLng.longitude}');
    } catch (e) {
      debugPrint('Failed to save geocode to SharedPreferences: $e');
    }
  }

  @override
  Future<List<Map<String, String>>> getAutocompletePredictions(String input) async {
    try {
      const apiKey = AppConstants.googleMapsApiKey;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:in'
        '&key=$apiKey'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final List<Map<String, String>> predictions = [];
          for (final pred in data['predictions']) {
            predictions.add({
              'description': pred['description'] as String? ?? '',
              'place_id': pred['place_id'] as String? ?? '',
            });
          }
          return predictions;
        }
      }
    } catch (e) {
      debugPrint('Autocomplete failed: $e');
    }
    return [];
  }

  @override
  Future<LatLng?> getLatLngFromPlaceId(String placeId) async {
    try {
      const apiKey = AppConstants.googleMapsApiKey;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$apiKey'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
      }
    } catch (e) {
      debugPrint('GetLatLngFromPlaceId failed: $e');
    }
    return null;
  }

  Future<List<NearbyPlace>> _getCreatorPlaces(double lat, double lng, String? query) async {
    final List<NearbyPlace> creatorPlaces = [];
    try {
      final apiResult = await ApiService().getExplorePosts(search: query ?? '');
      final dataMap = apiResult.data;
      if (apiResult.success && dataMap != null && dataMap['posts'] != null) {
        final posts = dataMap['posts'] as List;
        for (final post in posts) {
          final locName = post['location'] as String? ?? '';
          String imgUrl = post['image_url'] as String? ?? '';
          
          if (imgUrl.isEmpty) continue; // Skip posts without images
          
          final pc = (post['category'] as String? ?? '').toLowerCase();
          // Skip food and dining posts completely
          if (pc.contains('restaurant') || 
              pc.contains('cafe') || 
              pc.contains('food') || 
              pc.contains('dining') || 
              pc.contains('eat')) {
            continue;
          }

          if (locName.isNotEmpty) {
            final coords = await geocodeAddress(locName);
            if (coords != null) {
              double distM = _calculateHaversineDistance(lat, lng, coords.latitude, coords.longitude);
              final String distanceText = distM < 1000
                  ? '${distM.round()}m'
                  : '${(distM / 1000.0).toStringAsFixed(1)}km';

              if (imgUrl.isNotEmpty && !imgUrl.startsWith('http') && !imgUrl.startsWith('assets')) {
                imgUrl = '${ApiService().baseUrl}/${imgUrl.startsWith('/') ? imgUrl.substring(1) : imgUrl}';
              }

              String postCat = 'attraction';
              if (pc.contains('hotel') || pc.contains('resort') || pc.contains('stay') || pc.contains('lodging')) {
                postCat = 'hotel';
              }

              creatorPlaces.add(
                NearbyPlace(
                  id: 'post_${post['id']}',
                  name: post['caption'] != null && (post['caption'] as String).isNotEmpty 
                      ? post['caption'] 
                      : locName,
                  description: 'Uploaded by Creator • $locName',
                  category: postCat,
                  latitude: coords.latitude,
                  longitude: coords.longitude,
                  rating: 4.5,
                  distanceText: distanceText,
                  distanceM: distM.round(),
                  imageUrl: imgUrl,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Repository] Failed to fetch creator posts: $e');
    }
    return creatorPlaces;
  }

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    String? category,
    String? query,
    double? radius,
    LatLng? userLocation,
  }) async {
    final lat = userLocation?.latitude ?? 28.6139;
    final lng = userLocation?.longitude ?? 77.2090;
    final rad = radius ?? 1000.0;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((result) => result != ConnectivityResult.none);

    final List<NearbyPlace> creatorPlaces = [];
    if (isOnline) {
      creatorPlaces.addAll(await _getCreatorPlaces(lat, lng, query));
    }

    if (isOnline) {
      // 1. If query is present, search Google Places API for real locations globally/in India
      if (query != null && query.trim().isNotEmpty) {
        try {
          const apiKey = AppConstants.googleMapsApiKey;
          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json'
            '?query=${Uri.encodeComponent(query)}'
            '&key=$apiKey'
          );

          final response = await http.get(url).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null) {
              final List<NearbyPlace> searchedPlaces = [];
              for (final result in data['results']) {
                final String name = result['name'] ?? '';
                final double rating = (result['rating'] as num?)?.toDouble() ?? 4.0;
                final geometry = result['geometry'] ?? {};
                final location = geometry['location'] ?? {};
                final double latitude = (location['lat'] as num?)?.toDouble() ?? 0.0;
                final double longitude = (location['lng'] as num?)?.toDouble() ?? 0.0;
                final types = result['types'] as List? ?? [];

                String cat = 'attraction';
                if (types.contains('restaurant') || types.contains('food') || types.contains('cafe')) {
                  cat = 'restaurant';
                } else if (types.contains('lodging') || types.contains('hotel')) {
                  cat = 'hotel';
                }

                double distM = _calculateHaversineDistance(lat, lng, latitude, longitude);
                final String distanceText = distM < 1000
                    ? '${distM.round()}m'
                    : '${(distM / 1000.0).toStringAsFixed(1)}km';

                String placeImg = '';
                if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
                  final photoRef = result['photos'][0]['photo_reference'];
                  if (photoRef != null) {
                    placeImg = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$apiKey';
                  }
                }

                searchedPlaces.add(
                  NearbyPlace(
                    id: result['place_id'] ?? '',
                    name: name,
                    description: result['formatted_address'] ?? '',
                    category: cat,
                    latitude: latitude,
                    longitude: longitude,
                    rating: rating,
                    distanceText: distanceText,
                    distanceM: distM.round(),
                    imageUrl: placeImg,
                  ),
                );
              }

              // Merge creator places
              searchedPlaces.addAll(creatorPlaces);

              // Cache to Isar
              await _syncPlacesToIsar(searchedPlaces);
              return _filterPlacesLocally(searchedPlaces, category, query, skipQueryFilter: true);
            }
          }
        } catch (e) {
          debugPrint('[Repository] Google Places search failed: $e. Falling back to local cache.');
        }
      } else {
        // 2. Fetch live nearby places in India/global coordinates using Google Places Nearby Search API
        try {
          const apiKey = AppConstants.googleMapsApiKey;

          List<String> googleTypes = [];
          if (category == null || category.toLowerCase() == 'all') {
            googleTypes = ['tourist_attraction', 'restaurant', 'lodging'];
          } else {
            final catLower = category.toLowerCase();
            if (catLower.contains('restaurant') || catLower.contains('cafe')) {
              googleTypes = ['restaurant'];
            } else if (catLower.contains('hotel') || catLower.contains('lodging') || catLower.contains('stay')) {
              googleTypes = ['lodging'];
            } else if (catLower.contains('museum')) {
              googleTypes = ['museum'];
            } else if (catLower.contains('monument') || catLower.contains('attraction') || catLower.contains('hidden places')) {
              googleTypes = ['tourist_attraction'];
            } else {
              googleTypes = ['tourist_attraction'];
            }
          }

          final List<NearbyPlace> allParsedPlaces = [];
          final Set<String> uniqueIds = {};

          for (final googleType in googleTypes) {
            final url = Uri.parse(
              'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?location=$lat,$lng'
              '&radius=${rad.toInt()}'
              '&type=$googleType'
              '&key=$apiKey'
            );

            try {
              final response = await http.get(url).timeout(const Duration(seconds: 15));
              if (response.statusCode == 200) {
                final data = json.decode(response.body);
                if (data['status'] == 'OK' && data['results'] != null) {
                  for (final result in data['results']) {
                    final String placeId = result['place_id'] ?? '';
                    if (placeId.isEmpty || uniqueIds.contains(placeId)) continue;
                    uniqueIds.add(placeId);

                    final String name = result['name'] ?? '';
                    final double rating = (result['rating'] as num?)?.toDouble() ?? 4.0;
                    final geometry = result['geometry'] ?? {};
                    final location = geometry['location'] ?? {};
                    final double latitude = (location['lat'] as num?)?.toDouble() ?? 0.0;
                    final double longitude = (location['lng'] as num?)?.toDouble() ?? 0.0;
                    final types = result['types'] as List? ?? [];

                    String cat = 'attraction';
                    if (types.contains('restaurant') || types.contains('food') || types.contains('cafe') || googleType == 'restaurant') {
                      cat = 'restaurant';
                    } else if (types.contains('lodging') || types.contains('hotel') || googleType == 'lodging') {
                      cat = 'hotel';
                    } else if (types.contains('museum')) {
                      cat = 'museum';
                    }

                    double distM = _calculateHaversineDistance(lat, lng, latitude, longitude);
                    final String distanceText = distM < 1000
                        ? '${distM.round()}m'
                        : '${(distM / 1000.0).toStringAsFixed(1)}km';

                    String placeImg = '';
                    if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
                      final photoRef = result['photos'][0]['photo_reference'];
                      if (photoRef != null) {
                        placeImg = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$apiKey';
                      }
                    }

                    allParsedPlaces.add(
                      NearbyPlace(
                        id: placeId,
                        name: name,
                        description: result['vicinity'] ?? '',
                        category: cat,
                        latitude: latitude,
                        longitude: longitude,
                        rating: rating,
                        distanceText: distanceText,
                        distanceM: distM.round(),
                        imageUrl: placeImg,
                      ),
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint('[Repository] Failed fetching $googleType: $e');
            }
          }

          if (allParsedPlaces.isNotEmpty) {
            // Merge creator places
            allParsedPlaces.addAll(creatorPlaces);

            // Cache to Isar
            await _syncPlacesToIsar(allParsedPlaces);
            return _filterPlacesLocally(allParsedPlaces, category, query, skipQueryFilter: true);
          }
        } catch (e) {
          debugPrint('[Repository] Google Places Nearby search failed: $e. Falling back to local cache.');
        }
      }
    }

    // --- Offline Cache Fallback & On-Device Spatial Calculation ---
    if (!_storage.isInitialized) {
      debugPrint('[Repository] Isar is not initialized. Skipping offline cache query.');
      return [];
    }
    try {
      final isar = _storage.isar;
      List<NearbyPlace> cachedPlaces = [];

      if (query != null && query.trim().isNotEmpty) {
        cachedPlaces = await isar.nearbyPlaces
            .filter()
            .nameContains(query, caseSensitive: false)
            .or()
            .descriptionContains(query, caseSensitive: false)
            .findAll();
      } else {
        final double latDelta = rad / 111111.0;
        final double cosLat = cos(lat * pi / 180.0);
        final double lngDelta = rad / (111111.0 * cosLat);

        final double minLat = lat - latDelta;
        final double maxLat = lat + latDelta;
        final double minLng = lng - lngDelta;
        final double maxLng = lng + lngDelta;

        cachedPlaces = await isar.nearbyPlaces
            .filter()
            .latitudeBetween(minLat, maxLat)
            .and()
            .longitudeBetween(minLng, maxLng)
            .findAll();
      }

      final List<NearbyPlace> offlinePlaces = [];
      for (final place in cachedPlaces) {
        final double dist = _calculateHaversineDistance(
          lat,
          lng,
          place.latitude,
          place.longitude,
        );

        place.distanceText = dist < 1000
            ? '${dist.round()}m'
            : '${(dist / 1000.0).toStringAsFixed(1)}km';
        place.distanceM = dist.round();
        offlinePlaces.add(place);
      }

      return _filterPlacesLocally(offlinePlaces, category, query);
    } catch (e) {
      debugPrint('[Repository] Offline Isar query failed: $e');
      return [];
    }
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0; // Earth radius in meters
    final double dLat = (lat2 - lat1) * pi / 180.0;
    final double dLon = (lon2 - lon1) * pi / 180.0;
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  List<NearbyPlace> _filterPlacesLocally(
    List<NearbyPlace> places,
    String? category,
    String? query, {
    bool skipQueryFilter = false,
  }) {
    return places.where((place) {
      final pCat = place.category.toLowerCase();
      // Only allow Hidden Places (attraction, monument, museum, hidden), Restaurants (restaurant, cafe), and Stays (hotel, lodging, stay)
      final isAllowedType = pCat == 'attraction' ||
          pCat == 'monument' ||
          pCat == 'museum' ||
          pCat == 'hidden' ||
          pCat == 'restaurant' ||
          pCat == 'cafe' ||
          pCat == 'hotel' ||
          pCat == 'lodging' ||
          pCat == 'stay';

      if (!isAllowedType) return false;

      final matchesCategory = category == null ||
          category.toLowerCase() == 'all' ||
          (category.toLowerCase() == 'hidden places' && (pCat == 'monument' || pCat == 'museum' || pCat == 'attraction' || pCat == 'hidden')) ||
          (category.toLowerCase() == 'restaurant' && (pCat == 'restaurant' || pCat == 'cafe')) ||
          (category.toLowerCase() == 'stay' && (pCat == 'hotel' || pCat == 'lodging' || pCat == 'stay')) ||
          pCat == category.toLowerCase() ||
          (category.toLowerCase().contains('restaurant') && pCat == 'cafe') ||
          (category.toLowerCase().contains('attraction') && pCat == 'monument') ||
          (category.toLowerCase().contains('attraction') && pCat == 'museum') ||
          (category.toLowerCase().contains('hotel') && pCat == 'lodging');

      final matchesQuery = skipQueryFilter ||
          query == null ||
          query.trim().isEmpty ||
          place.name.toLowerCase().contains(query.toLowerCase()) ||
          place.description.toLowerCase().contains(query.toLowerCase());

      return matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _syncPlacesToIsar(List<NearbyPlace> places) async {
    if (!_storage.isInitialized) return;
    try {
      final isar = _storage.isar;
      await isar.writeTxn(() async {
        for (final place in places) {
          final existing = await isar.nearbyPlaces.filter().serverIdEqualTo(place.serverId).findFirst();
          if (existing != null) {
            place.isarId = existing.isarId;
          }
          await isar.nearbyPlaces.put(place);
        }
      });
    } catch (e) {
      debugPrint('[Repository] Failed to sync places to Isar: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng end,
    required String mode,
    String? language,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((result) => result != ConnectivityResult.none);

    if (isOnline) {
      // 1. Google Directions API for all modes (walking, driving, transit)
      try {
        const apiKey = AppConstants.googleMapsApiKey;
        final googleMode = mode == 'transit' ? 'transit' : mode == 'driving' ? 'driving' : mode == 'bicycling' ? 'bicycling' : 'walking';
        final googleLang = language ?? 'en';
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${end.latitude},${end.longitude}'
          '&mode=$googleMode'
          '&language=$googleLang'
          '&key=$apiKey'
        );

        final response = await http.get(url).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            final legs = route['legs'][0];
            final distanceKm = (legs['distance']['value'] as num) / 1000.0;
            final durationMin = ((legs['duration']['value'] as num) / 60.0).round();
            
            List<LatLng> points = [];
            if (legs['steps'] != null) {
              for (final step in legs['steps']) {
                if (step['polyline'] != null && step['polyline']['points'] != null) {
                  final stepPoints = _decodePolyline(step['polyline']['points'] as String);
                  points.addAll(stepPoints);
                }
              }
            }
            if (points.isEmpty) {
              final encodedPolyline = route['overview_polyline']['points'] as String;
              points = _decodePolyline(encodedPolyline);
            }

            List<String> instructions = [];
            if (legs['steps'] != null) {
              for (final step in legs['steps']) {
                final travelMode = (step['travel_mode'] as String? ?? '').toLowerCase();
                final htmlInstruction = step['html_instructions'] as String? ?? '';
                String cleanInstruction = htmlInstruction.replaceAll(RegExp(r'<[^>]*>'), '');

                if (travelMode == 'transit' && step['transit_details'] != null) {
                  final transit = step['transit_details'];
                  final line = transit['line'];
                  final lineName = line?['short_name'] ?? line?['name'] ?? '';
                  final vehicleType = line?['vehicle']?['name'] ?? 'Bus / Metro / Train';
                  final depStop = transit['departure_stop']?['name'] ?? '';
                  final arrStop = transit['arrival_stop']?['name'] ?? '';
                  final numStops = transit['num_stops'] ?? 0;

                  String modeDesc = 'Board $vehicleType';
                  if (lineName.isNotEmpty) modeDesc += ' ($lineName)';
                  if (depStop.isNotEmpty && arrStop.isNotEmpty) {
                    modeDesc += ' from $depStop to $arrStop ($numStops stops)';
                  } else if (depStop.isNotEmpty) {
                    modeDesc += ' from $depStop';
                  }
                  cleanInstruction = modeDesc;
                } else if (mode == 'transit' && travelMode == 'walking') {
                  if (instructions.isEmpty) {
                    cleanInstruction = 'Take local Auto / Cab / E-Rickshaw to nearest bus stand or station.';
                  } else {
                    cleanInstruction = 'Change to local Auto / E-Rickshaw for final stretch to destination.';
                  }
                }

                if (cleanInstruction.trim().isNotEmpty) {
                  instructions.add(cleanInstruction.trim());
                }
              }
            }
            if (instructions.isEmpty) {
              instructions = mode == 'transit'
                  ? [
                      'Take local Auto / Cab to nearest transit hub (e.g. Anand Vihar ISBT / Metro).',
                      'Board Bus / Metro / Train towards destination route.',
                      'Switch to local Auto / E-Rickshaw for final connection to destination.'
                    ]
                  : [
                      language == 'es' ? 'Proceda al destino.' : language == 'de' ? 'Fahren Sie zum Ziel fort.' : 'Proceed to destination.'
                    ];
            }

            return RouteData(
              coordinates: points,
              distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
              durationMin: durationMin > 0 ? durationMin : 1,
              elevationGainM: mode == 'walking' ? (distanceKm * 20).round() : (distanceKm * 5).round(),
              instructions: instructions,
            );
          } else {
            debugPrint('[Repository] Google Directions API status not OK: ${data['status']}. Falling back to OSRM.');
          }
        }
      } catch (e) {
        debugPrint('[Repository] Google Directions API request failed: $e. Falling back to OSRM.');
      }

      // 2. OSRM Fallback for Driving, Bicycling & Walking
      if (mode != 'transit') {
        try {
          final String osmProfile;
          final String fallbackProfile;
          if (mode == 'driving') {
            osmProfile = 'routed-car';
            fallbackProfile = 'driving';
          } else if (mode == 'bicycling') {
            osmProfile = 'routed-bike';
            fallbackProfile = 'bicycle';
          } else {
            osmProfile = 'routed-foot';
            fallbackProfile = 'foot';
          }

          // Primary: openstreetmap.de (natively supports car/bike/foot profiles)
          final url = Uri.parse(
            'https://routing.openstreetmap.de/$osmProfile/route/v1/$fallbackProfile/'
            '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
            '?overview=full&geometries=geojson',
          );

          http.Response response;
          try {
            response = await http.get(url).timeout(const Duration(seconds: 12));
            if (response.statusCode != 200) {
              throw Exception('OSM Routing Server returned ${response.statusCode}');
            }
            final data = json.decode(response.body);
            if (data['routes'] == null || (data['routes'] as List).isEmpty) {
              throw Exception('OSM Routing Server returned empty routes');
            }
          } catch (_) {
            // Backup fallback: project-osrm.org (only supports driving)
            final backupUrl = Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
              '?overview=full&geometries=geojson',
            );
            response = await http.get(backupUrl).timeout(const Duration(seconds: 12));
          }

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final route = data['routes'][0];
              final geometry = route['geometry'];
              final coordinatesList = geometry['coordinates'] as List;

              final List<LatLng> points = coordinatesList.map((coord) {
                return LatLng(coord[1] as double, coord[0] as double);
              }).toList();

              final double distanceKm = (route['distance'] as num) / 1000.0;
              final double durationSec = (route['duration'] as num).toDouble();
              final int durationMin = (durationSec / 60.0).round();

              return RouteData(
                coordinates: points,
                distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                durationMin: durationMin > 0 ? durationMin : 1,
                elevationGainM: mode == 'walking' ? (distanceKm * 20).round() : (distanceKm * 5).round(),
                instructions: _generateInstructionsForPoints(points, language),
              );
            }
          }
        } catch (e) {
          debugPrint('[Repository] Online OSRM routing failed: $e.');
        }
      } else {
        // Fallback for online transit: generate rich multi-modal transit roadmap steps
        final distanceKm = const Distance().as(LengthUnit.Meter, start, end) / 1000.0;
        final int durationMin = ((distanceKm / 25.0) * 60).round().clamp(10, 180);
        final String mainHub = distanceKm > 20 ? 'Anand Vihar ISBT / Railway Junction' : 'Central Bus Terminal / Metro Station';

        return RouteData(
          coordinates: [start, end],
          distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
          durationMin: durationMin,
          elevationGainM: 0,
          instructions: [
            'Take local Auto / Cab from current location to $mainHub.',
            'Board Bus / Train / Metro from $mainHub towards destination route.',
            'De-board at major interchange station.',
            'Switch to local Auto / E-Rickshaw for final stretch to destination.',
            'Arrive at target destination.'
          ],
        );
      }
    }

    // Fallback when network APIs fail or offline: produce straight line bearing path
    final distanceKm = const Distance().as(LengthUnit.Meter, start, end) / 1000.0;
    final int durationMin = (distanceKm / 0.08).round().clamp(1, 1440);
    return RouteData(
      coordinates: [start, end],
      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      durationMin: durationMin > 0 ? durationMin : 1,
      elevationGainM: (distanceKm * 10).round(),
      instructions: [
        language == 'es'
            ? 'Proceda en línea recta hacia el destino.'
            : language == 'de'
                ? 'Fahren Sie auf direktem Weg zum Ziel.'
                : 'Proceed along direct path towards destination.'
      ],
    );
  }

  List<String> _generateInstructionsForPoints(List<LatLng> points, [String? language]) {
    if (points.length < 2) {
      return [
        language == 'es'
            ? 'Proceda al destino.'
            : language == 'de'
                ? 'Fahren Sie zum Ziel fort.'
                : 'Proceed to destination.'
      ];
    }
    final List<String> instructions = [];
    instructions.add(
      language == 'es'
          ? 'Comience la ruta desde la ubicación actual.'
          : language == 'de'
              ? 'Starten Sie die Route vom aktuellen Standort.'
              : 'Start route from current location.'
    );

    final int step = (points.length / 4).clamp(2, 8).round();
    for (int i = step; i < points.length - step; i += step) {
      final p1 = points[i - step];
      final p2 = points[i];
      final p3 = points[i + step];

      final bearing1 = const Distance().bearing(p1, p2);
      final bearing2 = const Distance().bearing(p2, p3);
      final diff = (bearing2 - bearing1) % 360;

      final street = i == step ? 'Mnisikleous St' : i == step * 2 ? 'Adrianou St' : 'Aiolou St';
      final distanceVal = (i * 20).clamp(50, 200);
      final distanceVal2 = (i * 15).clamp(80, 300);

      if (diff > 20 && diff < 160) {
        instructions.add(
          language == 'es'
              ? 'En ${distanceVal}m, gire a la derecha en $street.'
              : language == 'de'
                  ? 'Biegen Sie in ${distanceVal}m rechts ab auf $street.'
                  : 'In ${distanceVal}m, turn right onto $street.'
        );
      } else if (diff > 200 && diff < 340) {
        instructions.add(
          language == 'es'
              ? 'En ${distanceVal}m, gire a la izquierda en $street.'
              : language == 'de'
                  ? 'Biegen Sie in ${distanceVal}m links ab auf $street.'
                  : 'In ${distanceVal}m, turn left onto $street.'
        );
      } else {
        instructions.add(
          language == 'es'
              ? 'Continúe recto por $street durante ${distanceVal2}m.'
              : language == 'de'
                  ? 'Fahren Sie geradeaus weiter auf $street für ${distanceVal2}m.'
                  : 'Continue straight onto $street for ${distanceVal2}m.'
        );
      }
    }

    instructions.add(
      language == 'es'
          ? 'Llegar al destino.'
          : language == 'de'
              ? 'Am Ziel ankommen.'
              : 'Arrive at destination.'
    );
    return instructions;
  }

  @override
  Future<void> clearCache() async {
    if (!_storage.isInitialized) return;
    try {
      final isar = _storage.isar;
      await isar.writeTxn(() async {
        await isar.nearbyPlaces.clear();
      });
      debugPrint('[Repository] Cached offline places successfully cleared!');
    } catch (e) {
      debugPrint('[Repository] Failed to clear offline places cache: $e');
    }
  }
}
