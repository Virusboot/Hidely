import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/config/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:latlong2/latlong.dart';
import '../../services/local_storage_service.dart';
import '../../services/api_service.dart';
import '../../services/location_capture_service.dart';
import '../../domain/repositories/map_repository.dart';
import '../models/nearby_place.dart';
import '../models/route_data.dart';
import '../models/navigation_step.dart';

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
      final url = (kIsWeb || apiKey.isEmpty)
          ? Uri.parse('${ApiService().baseUrl}/api/map/geocode?address=${Uri.encodeComponent(address)}')
          : Uri.parse(
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

    // Fallback: Photon Geocoding API (Free OpenStreetMap based, no key required, CORS supported)
    try {
      debugPrint('[Geocode] Falling back to Photon for: $address');
      final fallbackUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(address)}&limit=1'
      );
      final fallbackResponse = await http.get(fallbackUrl).timeout(const Duration(seconds: 10));
      if (fallbackResponse.statusCode == 200) {
        final fallbackData = json.decode(fallbackResponse.body);
        if (fallbackData is Map && fallbackData['features'] is List && (fallbackData['features'] as List).isNotEmpty) {
          final first = (fallbackData['features'] as List)[0];
          final coords = first['geometry']?['coordinates'] as List? ?? [];
          if (coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final latLng = LatLng(lat, lng);
            
            _geocodingCache[cleanName] = latLng;
            _saveGeocodeToPrefs(cleanName, latLng);

            debugPrint('[Geocode] Photon succeeded: Lat $lat, Lng $lng');
            return latLng;
          }
        }
      }
    } catch (e) {
      debugPrint('Photon Geocoding fallback failed: $e');
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
    if (input.trim().isEmpty) return [];
    final List<Map<String, String>> predictions = [];
    final Set<String> addedNames = {};

    // 1. Instant local places & creator posts matching
    try {
      final queryLower = input.trim().toLowerCase();
      final localPlaces = await getNearbyPlaces(query: input);
      for (final place in localPlaces) {
        if (place.name.toLowerCase().contains(queryLower) || place.description.toLowerCase().contains(queryLower)) {
          final desc = place.name;
          if (!addedNames.contains(desc.toLowerCase())) {
            addedNames.add(desc.toLowerCase());
            predictions.add({
              'description': desc,
              'place_id': place.id.startsWith('post_') ? '' : place.id,
              'subtitle': place.description.isNotEmpty ? place.description : 'Hidden Place',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[Autocomplete] Local search lookup failed: $e');
    }

    // 2. Google Places / Backend Autocomplete API
    try {
      final url = Uri.parse('${ApiService().baseUrl}/api/map/autocomplete?input=${Uri.encodeComponent(input)}');
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          for (final pred in data['predictions']) {
            final desc = pred['description'] as String? ?? '';
            if (desc.isNotEmpty && !addedNames.contains(desc.toLowerCase())) {
              addedNames.add(desc.toLowerCase());
              predictions.add({
                'description': desc,
                'place_id': pred['place_id'] as String? ?? '',
                'subtitle': pred['structured_formatting']?['secondary_text'] as String? ?? 'Search Location',
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Autocomplete Backend/Google API failed: $e');
    }

    // 3. Fallback: Photon API for dynamic global & Indian location suggestions
    if (predictions.length < 3) {
      try {
        final fallbackUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(input)}&limit=8'
        );
        final res = await http.get(fallbackUrl).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data is Map && data['features'] is List) {
            for (final f in data['features']) {
              final props = f['properties'] as Map<String, dynamic>? ?? {};
              final geom = f['geometry'] as Map<String, dynamic>? ?? {};
              final coords = geom['coordinates'] as List? ?? [];

              final name = props['name']?.toString() ?? '';
              final street = props['street']?.toString() ?? '';
              final city = props['city']?.toString() ?? props['county']?.toString() ?? '';
              final state = props['state']?.toString() ?? '';
              final country = props['country']?.toString() ?? '';

              final parts = [name, street, city, state, country].where((s) => s.isNotEmpty).toSet().toList();
              final desc = parts.join(', ');

              if (desc.isNotEmpty && !addedNames.contains(desc.toLowerCase())) {
                addedNames.add(desc.toLowerCase());
                final lat = coords.length > 1 ? coords[1] : '';
                final lng = coords.isNotEmpty ? coords[0] : '';
                final placeId = (lat != '' && lng != '') ? 'photon_${lat}_$lng' : '';
                predictions.add({
                  'description': desc,
                  'place_id': placeId,
                  'subtitle': city.isNotEmpty ? '$city, $state' : (state.isNotEmpty ? '$state, $country' : 'Location'),
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[Autocomplete] Photon fallback error: $e');
      }
    }

    return predictions;
  }

  @override
  Future<LatLng?> getLatLngFromPlaceId(String placeId) async {
    // Instant resolution if place_id was created by Photon
    if (placeId.startsWith('photon_')) {
      final parts = placeId.split('_');
      if (parts.length >= 3) {
        final lat = double.tryParse(parts[1]);
        final lng = double.tryParse(parts[2]);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    }

    try {
      final url = Uri.parse('${ApiService().baseUrl}/api/map/details?place_id=$placeId');
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

          final rawLat = double.tryParse(post['latitude']?.toString() ?? '');
          final rawLng = double.tryParse(post['longitude']?.toString() ?? '');
          LatLng? coords;
          if (LocationCaptureService.isValidCoordinatePair(rawLat, rawLng)) {
            coords = LatLng(rawLat!, rawLng!);
          } else if (locName.isNotEmpty) {
            coords = await geocodeAddress(locName);
          }

          if (coords != null) {
            final effectiveLocName = locName.isNotEmpty
                ? locName
                : ((post['canonical_name'] as String?)?.isNotEmpty == true
                    ? post['canonical_name'] as String
                    : 'Hidden Place');
            double distM = _calculateHaversineDistance(lat, lng, coords.latitude, coords.longitude);
            // Enforce 100 KM radius filter for nearby spots when not doing an explicit text search
            if ((query == null || query.trim().isEmpty) && distM > 100000) {
              continue;
            }
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
                    : effectiveLocName,
                description: 'Uploaded by Creator • $effectiveLocName',
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
    final rad = radius ?? 25000.0;

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
          final url = (kIsWeb || apiKey.isEmpty)
              ? Uri.parse('${ApiService().baseUrl}/api/map/places/textsearch?query=${Uri.encodeComponent(query)}')
              : Uri.parse(
                  'https://maps.googleapis.com/maps/api/place/textsearch/json'
                  '?query=${Uri.encodeComponent(query)}'
                  '&key=$apiKey'
                );

          final response = await http.get(url).timeout(const Duration(seconds: 15));
          final List<NearbyPlace> searchedPlaces = [];
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null) {
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
                    placeImg = (kIsWeb || apiKey.isEmpty)
                        ? '${ApiService().baseUrl}/api/map/photo?maxwidth=800&photo_reference=$photoRef'
                        : 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$apiKey';
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
            }
          }

          // Fallback to Photon OpenStreetMap text search if Google Places returns 0 results
          if (searchedPlaces.isEmpty) {
            final osmQueryPlaces = await _fetchPlacesFromPhotonQuery(query, lat, lng);
            searchedPlaces.addAll(osmQueryPlaces);
          }

          if (searchedPlaces.isNotEmpty || creatorPlaces.isNotEmpty) {
            searchedPlaces.addAll(creatorPlaces);
            await _syncPlacesToIsar(searchedPlaces);
            return _filterPlacesLocally(searchedPlaces, category, query, skipQueryFilter: true);
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
            if (catLower.contains('restaurant') || catLower.contains('cafe') || catLower.contains('food')) {
              googleTypes = ['restaurant', 'cafe'];
            } else if (catLower.contains('hotel') || catLower.contains('lodging') || catLower.contains('stay') || catLower.contains('resort')) {
              googleTypes = ['lodging'];
            } else if (catLower.contains('museum')) {
              googleTypes = ['museum'];
            } else if (catLower.contains('monument') || catLower.contains('attraction') || catLower.contains('hidden') || catLower.contains('travel')) {
              googleTypes = ['tourist_attraction', 'point_of_interest'];
            } else {
              googleTypes = ['tourist_attraction'];
            }
          }

          final List<NearbyPlace> allParsedPlaces = [];
          final Set<String> uniqueIds = {};

          for (final googleType in googleTypes) {
            final url = (kIsWeb || apiKey.isEmpty)
                ? Uri.parse(
                    '${ApiService().baseUrl}/api/map/places/nearby'
                    '?location=$lat,$lng'
                    '&radius=${rad.toInt()}'
                    '&type=$googleType'
                  )
                : Uri.parse(
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
                        placeImg = (kIsWeb || apiKey.isEmpty)
                            ? '${ApiService().baseUrl}/api/map/photo?maxwidth=800&photo_reference=$photoRef'
                            : 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$apiKey';
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

          // Fallback to OpenStreetMap Photon & Nominatim if Google Places returned 0 results
          if (allParsedPlaces.isEmpty) {
            debugPrint('[Repository] Google Places returned 0 places, invoking OSM Photon & Nominatim fallback...');
            final osmPlaces = await _fetchPlacesFromOsmPhoton(lat, lng, category, rad);
            for (final p in osmPlaces) {
              if (!uniqueIds.contains(p.id)) {
                uniqueIds.add(p.id);
                allParsedPlaces.add(p);
              }
            }

            final nomPlaces = await _fetchAttractionsFromNominatim(lat, lng, rad);
            for (final np in nomPlaces) {
              if (!uniqueIds.contains(np.id)) {
                uniqueIds.add(np.id);
                allParsedPlaces.add(np);
              }
            }
          }

          // Fallback to curated seeds if still empty
          if (allParsedPlaces.isEmpty) {
            final curated = _getCuratedFallbackPlaces(lat, lng, rad);
            for (final cp in curated) {
              if (!uniqueIds.contains(cp.id)) {
                uniqueIds.add(cp.id);
                allParsedPlaces.add(cp);
              }
            }
          }

          if (allParsedPlaces.isNotEmpty) {
            // Merge creator places
            allParsedPlaces.addAll(creatorPlaces);

            // Cache to Isar
            await _syncPlacesToIsar(allParsedPlaces);
            return _filterPlacesLocally(allParsedPlaces, category, query, skipQueryFilter: true);
          } else if (creatorPlaces.isNotEmpty) {
            await _syncPlacesToIsar(creatorPlaces);
            return _filterPlacesLocally(creatorPlaces, category, query, skipQueryFilter: true);
          }
        } catch (e) {
          debugPrint('[Repository] Google Places Nearby search failed: $e. Falling back to local cache.');
        }
      }
    }

    // --- Offline Cache Fallback & On-Device Spatial Calculation ---
    if (!_storage.isInitialized) {
      debugPrint('[Repository] Isar is not initialized. Using curated fallback places.');
      final curated = _getCuratedFallbackPlaces(lat, lng, rad);
      return _filterPlacesLocally(curated, category, query);
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

      if (offlinePlaces.isEmpty) {
        final curated = _getCuratedFallbackPlaces(lat, lng, rad);
        offlinePlaces.addAll(curated);
      }

      return _filterPlacesLocally(offlinePlaces, category, query);
    } catch (e) {
      debugPrint('[Repository] Offline Isar query failed: $e');
      final curated = _getCuratedFallbackPlaces(lat, lng, rad);
      return _filterPlacesLocally(curated, category, query);
    }
  }

  Future<List<NearbyPlace>> _fetchPlacesFromPhotonQuery(String query, double userLat, double userLng) async {
    final List<NearbyPlace> results = [];
    try {
      final url = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$userLat&lon=$userLng&limit=25');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['features'] is List) {
          for (final item in (data['features'] as List)) {
            if (item is! Map) continue;
            final props = item['properties'] as Map? ?? {};
            final geom = item['geometry'] as Map? ?? {};
            final coords = geom['coordinates'] as List? ?? [];
            if (coords.length < 2) continue;

            final placeLng = (coords[0] as num).toDouble();
            final placeLat = (coords[1] as num).toDouble();
            final rawName = (props['name'] as String?)?.trim() ?? '';
            if (rawName.isEmpty) continue;

            final osmValue = (props['osm_value'] as String?)?.toLowerCase() ?? '';
            final osmKey = (props['osm_key'] as String?)?.toLowerCase() ?? '';

            String cat = 'attraction';
            if (osmKey == 'amenity' && (osmValue.contains('restaurant') || osmValue.contains('cafe') || osmValue.contains('food'))) {
              cat = 'restaurant';
            } else if (osmKey == 'tourism' && (osmValue.contains('hotel') || osmValue.contains('hostel') || osmValue.contains('guest_house') || osmValue.contains('motel'))) {
              cat = 'hotel';
            }

            final distM = _calculateHaversineDistance(userLat, userLng, placeLat, placeLng);
            final distText = distM < 1000 ? '${distM.round()}m' : '${(distM / 1000.0).toStringAsFixed(1)}km';

            final addressParts = [
              props['street'],
              props['locality'] ?? props['district'],
              props['city'],
              props['state'],
              props['country'],
            ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

            String imageUrl = '';
            if (cat == 'restaurant') {
              imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80';
            } else if (cat == 'hotel') {
              imageUrl = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80';
            } else {
              imageUrl = 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=500&q=80';
            }

            results.add(
              NearbyPlace(
                id: 'photon_${props['osm_type'] ?? 'N'}_${props['osm_id'] ?? DateTime.now().microsecondsSinceEpoch}',
                name: rawName,
                description: addressParts.isNotEmpty ? addressParts : rawName,
                category: cat,
                latitude: placeLat,
                longitude: placeLng,
                rating: 4.5,
                distanceText: distText,
                distanceM: distM.round(),
                imageUrl: imageUrl,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Repository] Photon query error: $e');
    }
    return results;
  }

  Future<List<NearbyPlace>> _fetchPlacesFromOsmPhoton(
    double lat,
    double lng,
    String? category,
    double radius,
  ) async {
    final List<String> searchTerms = [];
    final catLower = (category ?? 'all').toLowerCase();

    if (catLower == 'all') {
      searchTerms.addAll(['attraction', 'hotel', 'restaurant']);
    } else if (catLower.contains('restaurant') || catLower.contains('cafe') || catLower.contains('food')) {
      searchTerms.addAll(['restaurant', 'cafe']);
    } else if (catLower.contains('hotel') || catLower.contains('lodging') || catLower.contains('stay') || catLower.contains('resort')) {
      searchTerms.addAll(['hotel', 'resort']);
    } else if (catLower.contains('travel') || catLower.contains('hidden') || catLower.contains('monument') || catLower.contains('attraction') || catLower.contains('museum')) {
      searchTerms.addAll(['attraction', 'monument', 'museum']);
    } else {
      searchTerms.add('attraction');
    }

    final List<NearbyPlace> results = [];
    final Set<String> seenNames = {};

    for (final term in searchTerms) {
      try {
        final url = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(term)}&lat=$lat&lon=$lng&limit=25'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map && data['features'] is List) {
            for (final item in (data['features'] as List)) {
              if (item is! Map) continue;
              final props = item['properties'] as Map? ?? {};
              final geom = item['geometry'] as Map? ?? {};
              final coords = geom['coordinates'] as List? ?? [];
              if (coords.length < 2) continue;

              final placeLng = (coords[0] as num).toDouble();
              final placeLat = (coords[1] as num).toDouble();
              final rawName = (props['name'] as String?)?.trim() ?? '';
              if (rawName.isEmpty || rawName.toLowerCase() == term.toLowerCase()) continue;

              final cleanKey = rawName.toLowerCase();
              if (seenNames.contains(cleanKey)) continue;
              seenNames.add(cleanKey);

              final osmValue = (props['osm_value'] as String?)?.toLowerCase() ?? '';
              final osmKey = (props['osm_key'] as String?)?.toLowerCase() ?? '';

              String cat = 'attraction';
              if (term == 'restaurant' || term == 'cafe' || osmKey == 'amenity' || osmValue.contains('restaurant') || osmValue.contains('cafe')) {
                cat = 'restaurant';
              } else if (term == 'hotel' || term == 'resort' || osmValue.contains('hotel') || osmValue.contains('hostel') || osmValue.contains('guest_house') || osmValue.contains('motel')) {
                cat = 'hotel';
              } else if (term == 'museum' || osmValue.contains('museum')) {
                cat = 'museum';
              } else if (term == 'monument' || osmValue.contains('monument')) {
                cat = 'monument';
              }

              final distM = _calculateHaversineDistance(lat, lng, placeLat, placeLng);
              if (distM > radius * 1.8) continue;

              final distText = distM < 1000 ? '${distM.round()}m' : '${(distM / 1000.0).toStringAsFixed(1)}km';

              final addressParts = [
                props['street'],
                props['locality'] ?? props['district'],
                props['city'],
                props['state'],
              ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

              String imageUrl = '';
              if (cat == 'restaurant') {
                imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80';
              } else if (cat == 'hotel') {
                imageUrl = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80';
              } else {
                imageUrl = 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=500&q=80';
              }

              results.add(
                NearbyPlace(
                  id: 'osm_${props['osm_type'] ?? 'N'}_${props['osm_id'] ?? DateTime.now().microsecondsSinceEpoch}',
                  name: rawName,
                  description: addressParts.isNotEmpty ? addressParts : (props['country'] as String? ?? 'Nearby spot'),
                  category: cat,
                  latitude: placeLat,
                  longitude: placeLng,
                  rating: 4.3 + (Random().nextInt(6) * 0.1),
                  distanceText: distText,
                  distanceM: distM.round(),
                  imageUrl: imageUrl,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[Repository] OSM Photon search failed for $term: $e');
      }
    }

    return results;
  }

  Future<List<NearbyPlace>> _fetchAttractionsFromNominatim(
    double lat,
    double lng,
    double radius,
  ) async {
    final List<NearbyPlace> results = [];
    try {
      final double delta = (radius / 111111.0).clamp(0.05, 0.45);
      final double minLng = lng - delta;
      final double maxLng = lng + delta;
      final double minLat = lat - delta;
      final double maxLat = lat + delta;

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=attraction&format=json&viewbox=$minLng,$maxLat,$maxLng,$minLat&bounded=1&limit=25'
      );
      final response = await http.get(url, headers: {'User-Agent': 'HidelyApp/1.0'}).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          for (final item in data) {
            if (item is! Map) continue;
            final name = item['name'] as String? ?? '';
            final pLat = double.tryParse(item['lat']?.toString() ?? '');
            final pLng = double.tryParse(item['lon']?.toString() ?? '');
            if (name.isEmpty || pLat == null || pLng == null) continue;

            final distM = _calculateHaversineDistance(lat, lng, pLat, pLng);
            final distText = distM < 1000 ? '${distM.round()}m' : '${(distM / 1000.0).toStringAsFixed(1)}km';

            results.add(
              NearbyPlace(
                id: 'nom_${item['place_id'] ?? item['osm_id']}',
                name: name,
                description: item['display_name'] as String? ?? 'Attraction',
                category: 'attraction',
                latitude: pLat,
                longitude: pLng,
                rating: 4.6,
                distanceText: distText,
                distanceM: distM.round(),
                imageUrl: 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=500&q=80',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Repository] Nominatim search error: $e');
    }
    return results;
  }

  List<NearbyPlace> _getCuratedFallbackPlaces(double lat, double lng, double radius) {
    final List<Map<String, dynamic>> rawSeeds = [
      // Delhi NCR
      {'name': 'India Gate', 'desc': 'Rajpath, India Gate, New Delhi', 'lat': 28.6129, 'lng': 77.2295, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1587474260584-136574528ed5?w=500&q=80'},
      {'name': 'Red Fort', 'desc': 'Netaji Subhash Marg, Lal Qila, Old Delhi', 'lat': 28.6562, 'lng': 77.2410, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1592635196078-9fe3d54f2377?w=500&q=80'},
      {'name': 'Qutub Minar', 'desc': 'Seth Sarai, Mehrauli, New Delhi', 'lat': 28.5244, 'lng': 77.1855, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=500&q=80'},
      {'name': 'Humayun\'s Tomb', 'desc': 'Mathura Road, Nizamuddin East, New Delhi', 'lat': 28.5849, 'lng': 77.2483, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=500&q=80'},
      {'name': 'Lotus Temple', 'desc': 'Lotus Temple Rd, Bahapur, New Delhi', 'lat': 28.5535, 'lng': 77.2588, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=500&q=80'},
      {'name': 'The Imperial Hotel', 'desc': 'Janpath, Connaught Place, New Delhi', 'lat': 28.6234, 'lng': 77.2177, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80'},
      {'name': 'Taj Mahal Hotel', 'desc': 'Number One Mansingh Road, New Delhi', 'lat': 28.6042, 'lng': 77.2245, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=500&q=80'},
      {'name': 'Bukhara Restaurant', 'desc': 'ITC Maurya, Diplomatic Enclave, New Delhi', 'lat': 28.5973, 'lng': 77.1706, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80'},
      {'name': 'Karim\'s Jama Masjid', 'desc': 'Gali Kababian, Jama Masjid, Old Delhi', 'lat': 28.6508, 'lng': 77.2334, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&q=80'},
      {'name': 'Indian Accent', 'desc': 'The Lodhi, Lodhi Road, New Delhi', 'lat': 28.5908, 'lng': 77.2427, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=500&q=80'},

      // Agra
      {'name': 'Taj Mahal', 'desc': 'Dharmapuri, Forest Colony, Tajganj, Agra', 'lat': 27.1751, 'lng': 78.0421, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=500&q=80'},
      {'name': 'Agra Fort', 'desc': 'Agra Fort, Rakabganj, Agra', 'lat': 27.1795, 'lng': 78.0211, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1592635196078-9fe3d54f2377?w=500&q=80'},
      {'name': 'The Oberoi Amarvilas', 'desc': 'Taj East Gate Road, Agra', 'lat': 27.1701, 'lng': 78.0483, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80'},
      {'name': 'Pinch of Spice', 'desc': 'Fatehabad Road, Tajganj, Agra', 'lat': 27.1963, 'lng': 78.0069, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80'},

      // Jaipur
      {'name': 'Hawa Mahal', 'desc': 'Hawa Mahal Rd, Badi Choupad, Jaipur', 'lat': 26.9239, 'lng': 75.8267, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1603258849062-1087859844e1?w=500&q=80'},
      {'name': 'Amber Palace', 'desc': 'Devisinghpura, Amer, Jaipur', 'lat': 26.9855, 'lng': 75.8513, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1599661046289-e31897846e41?w=500&q=80'},
      {'name': 'Rambagh Palace', 'desc': 'Bhawani Singh Rd, Rambagh, Jaipur', 'lat': 26.8978, 'lng': 75.8086, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80'},
      {'name': 'Handi Restaurant', 'desc': 'MI Road, Opposite GPO, Jaipur', 'lat': 26.9168, 'lng': 75.8015, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80'},

      // Mumbai
      {'name': 'Gateway of India', 'desc': 'Apollo Bandar, Colaba, Mumbai', 'lat': 18.9220, 'lng': 72.8347, 'cat': 'monument', 'img': 'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=500&q=80'},
      {'name': 'Marine Drive', 'desc': 'Netaji Subhash Chandra Bose Road, Mumbai', 'lat': 18.9432, 'lng': 72.8230, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1567157577867-05ccb1388e66?w=500&q=80'},
      {'name': 'The Taj Mahal Palace', 'desc': 'Apollo Bunder, Colaba, Mumbai', 'lat': 18.9217, 'lng': 72.8332, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=500&q=80'},
      {'name': 'Leopold Cafe', 'desc': 'Colaba Causeway, Colaba, Mumbai', 'lat': 18.9228, 'lng': 72.8317, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80'},

      // Goa
      {'name': 'Fort Aguada', 'desc': 'Sinquerim, Candolim, Goa', 'lat': 15.4925, 'lng': 73.7736, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=500&q=80'},
      {'name': 'Baga Beach', 'desc': 'Baga, North Goa', 'lat': 15.5553, 'lng': 73.7517, 'cat': 'attraction', 'img': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80'},
      {'name': 'Taj Fort Aguada Resort', 'desc': 'Sinquerim, Candolim, Goa', 'lat': 15.4950, 'lng': 73.7750, 'cat': 'hotel', 'img': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&q=80'},
      {'name': 'Fisherman\'s Wharf', 'desc': 'Mobor Beach, Cavelossim, Goa', 'lat': 15.1611, 'lng': 73.9472, 'cat': 'restaurant', 'img': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&q=80'},
    ];

    final List<NearbyPlace> matched = [];
    for (final s in rawSeeds) {
      final sLat = s['lat'] as double;
      final sLng = s['lng'] as double;
      final distM = _calculateHaversineDistance(lat, lng, sLat, sLng);
      if (distM <= radius * 2.5) {
        final distText = distM < 1000 ? '${distM.round()}m' : '${(distM / 1000.0).toStringAsFixed(1)}km';
        matched.add(
          NearbyPlace(
            id: 'seed_${s['name'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: s['name'] as String,
            description: s['desc'] as String,
            category: s['cat'] as String,
            latitude: sLat,
            longitude: sLng,
            rating: 4.8,
            distanceText: distText,
            distanceM: distM.round(),
            imageUrl: s['img'] as String,
          ),
        );
      }
    }

    if (matched.isEmpty) {
      final sortedSeeds = List<Map<String, dynamic>>.from(rawSeeds);
      sortedSeeds.sort((a, b) {
        final dA = _calculateHaversineDistance(lat, lng, a['lat'] as double, a['lng'] as double);
        final dB = _calculateHaversineDistance(lat, lng, b['lat'] as double, b['lng'] as double);
        return dA.compareTo(dB);
      });
      for (final s in sortedSeeds.take(8)) {
        final sLat = s['lat'] as double;
        final sLng = s['lng'] as double;
        final distM = _calculateHaversineDistance(lat, lng, sLat, sLng);
        final distText = distM < 1000 ? '${distM.round()}m' : '${(distM / 1000.0).toStringAsFixed(1)}km';
        matched.add(
          NearbyPlace(
            id: 'seed_${s['name'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: s['name'] as String,
            description: s['desc'] as String,
            category: s['cat'] as String,
            latitude: sLat,
            longitude: sLng,
            rating: 4.8,
            distanceText: distText,
            distanceM: distM.round(),
            imageUrl: s['img'] as String,
          ),
        );
      }
    }

    return matched;
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

      final catLower = category?.toLowerCase() ?? 'all';
      final matchesCategory = catLower == 'all' ||
          ((catLower.contains('travel') || catLower.contains('hidden') || catLower.contains('monument') || catLower.contains('attraction') || catLower.contains('museum')) &&
              (pCat == 'monument' || pCat == 'museum' || pCat == 'attraction' || pCat == 'hidden')) ||
          ((catLower.contains('restaurant') || catLower.contains('cafe') || catLower.contains('food') || catLower.contains('dining')) &&
              (pCat == 'restaurant' || pCat == 'cafe')) ||
          ((catLower.contains('stay') || catLower.contains('hotel') || catLower.contains('lodging') || catLower.contains('resort')) &&
              (pCat == 'hotel' || pCat == 'lodging' || pCat == 'stay')) ||
          pCat == catLower;

      final matchesQuery = skipQueryFilter ||
          query == null ||
          query.trim().isEmpty ||
          place.name.toLowerCase().contains(query.toLowerCase()) ||
          place.description.toLowerCase().contains(query.toLowerCase());

      final isNearEnough = (query != null && query.trim().isNotEmpty) || place.distanceM <= 100000;

      return matchesCategory && matchesQuery && isNearEnough;
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
      // 1. Google Directions API with departure_time=now, traffic_model=best_guess & alternatives=true
      try {
        const apiKey = AppConstants.googleMapsApiKey;
        final googleMode = mode == 'transit'
            ? 'transit'
            : mode == 'driving'
                ? 'driving'
                : mode == 'bicycling'
                    ? 'bicycling'
                    : 'walking';
        final googleLang = language ?? 'en';
        final departureParam = mode == 'driving' ? '&departure_time=now&traffic_model=best_guess' : '';
        final url = (kIsWeb || apiKey.isEmpty)
            ? Uri.parse(
                '${ApiService().baseUrl}/api/map/directions'
                '?origin=${start.latitude},${start.longitude}'
                '&destination=${end.latitude},${end.longitude}'
                '&mode=$googleMode'
                '&language=$googleLang'
                '&alternatives=true'
              )
            : Uri.parse(
                'https://maps.googleapis.com/maps/api/directions/json'
                '?origin=${start.latitude},${start.longitude}'
                '&destination=${end.latitude},${end.longitude}'
                '&mode=$googleMode'
                '&language=$googleLang'
                '&alternatives=true'
                '$departureParam'
                '&key=$apiKey'
              );

        final response = await http.get(url).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
            final routesList = data['routes'] as List;
            final List<RouteOption> routeOptions = [];

            for (int rIdx = 0; rIdx < routesList.length; rIdx++) {
              final route = routesList[rIdx];
              final legs = route['legs'][0];
              final distanceKm = (legs['distance']['value'] as num) / 1000.0;
              final durationMin = ((legs['duration']['value'] as num) / 60.0).round();
              final durationInTrafficMin = legs['duration_in_traffic'] != null
                  ? ((legs['duration_in_traffic']['value'] as num) / 60.0).round()
                  : null;
              final summary = route['summary'] as String? ?? (rIdx == 0 ? 'Fastest Route' : 'Alternative $rIdx');

              List<LatLng> points = [];
              if (legs['steps'] != null) {
                for (final step in legs['steps']) {
                  if (step['polyline'] != null && step['polyline']['points'] != null) {
                    final stepPoints = _decodePolyline(step['polyline']['points'] as String);
                    points.addAll(stepPoints);
                  }
                }
              }
              if (points.isEmpty && route['overview_polyline'] != null) {
                points = _decodePolyline(route['overview_polyline']['points'] as String);
              }

              final List<NavigationStep> navSteps = [];
              final List<String> instructions = [];

              if (legs['steps'] != null) {
                for (final step in legs['steps']) {
                  final htmlInstruction = step['html_instructions'] as String? ?? '';
                  String cleanInstruction = htmlInstruction.replaceAll(RegExp(r'<[^>]*>'), '');
                  final stepDistM = (step['distance']['value'] as num).toDouble();
                  final stepDurSec = (step['duration']['value'] as num).toInt();
                  final startLoc = LatLng(step['start_location']['lat'] as double, step['start_location']['lng'] as double);
                  final endLoc = LatLng(step['end_location']['lat'] as double, step['end_location']['lng'] as double);

                  final rawManeuver = step['maneuver'] as String?;
                  final maneuverType = ManeuverType.fromString(rawManeuver);

                  String roadName = '';
                  final matchRoad = RegExp(r'(?:onto|on)\s+([A-Za-z0-9\s]+)').firstMatch(cleanInstruction);
                  if (matchRoad != null && matchRoad.group(1) != null) {
                    roadName = matchRoad.group(1)!.trim();
                  }

                  int? roundaboutExit;
                  if (maneuverType == ManeuverType.roundabout || cleanInstruction.toLowerCase().contains('roundabout')) {
                    final exitMatch = RegExp(r'(\d+)(?:st|nd|rd|th)?\s+exit').firstMatch(cleanInstruction.toLowerCase());
                    if (exitMatch != null) {
                      roundaboutExit = int.tryParse(exitMatch.group(1) ?? '');
                    }
                  }

                  navSteps.add(
                    NavigationStep(
                      startLocation: startLoc,
                      endLocation: endLoc,
                      distanceMeters: stepDistM,
                      durationSeconds: stepDurSec,
                      maneuverType: maneuverType,
                      instruction: cleanInstruction.trim(),
                      roadName: roadName,
                      roundaboutExitIndex: roundaboutExit,
                    ),
                  );

                  if (cleanInstruction.trim().isNotEmpty) {
                    instructions.add(cleanInstruction.trim());
                  }
                }
              }

              routeOptions.add(
                RouteOption(
                  id: 'google_route_$rIdx',
                  summary: summary,
                  coordinates: points,
                  distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                  durationMin: durationMin > 0 ? durationMin : 1,
                  durationInTrafficMin: durationInTrafficMin,
                  steps: navSteps,
                  instructions: instructions,
                ),
              );
            }

            final primaryOpt = routeOptions.first;
            return RouteData(
              coordinates: primaryOpt.coordinates,
              distanceKm: primaryOpt.distanceKm,
              durationMin: primaryOpt.durationMin,
              durationInTrafficMin: primaryOpt.durationInTrafficMin,
              elevationGainM: mode == 'walking' ? (primaryOpt.distanceKm * 20).round() : (primaryOpt.distanceKm * 5).round(),
              instructions: primaryOpt.instructions,
              steps: primaryOpt.steps,
              options: routeOptions,
              selectedOptionIndex: 0,
            );
          } else {
            debugPrint('[Repository] Google Directions API status not OK: ${data['status']}. Falling back to OSRM.');
          }
        }
      } catch (e) {
        debugPrint('[Repository] Google Directions API request failed: $e. Falling back to OSRM.');
      }

      // 2. OSRM Fallback with steps=true&annotations=true
      if (mode != 'transit') {
        try {
          final String osmProfile = mode == 'driving' ? 'routed-car' : mode == 'bicycling' ? 'routed-bike' : 'routed-foot';
          final String fallbackProfile = mode == 'driving' ? 'driving' : mode == 'bicycling' ? 'bicycle' : 'foot';

          final url = Uri.parse(
            'https://routing.openstreetmap.de/$osmProfile/route/v1/$fallbackProfile/'
            '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
            '?overview=full&geometries=geojson&steps=true&annotations=true',
          );

          http.Response response;
          try {
            response = await http.get(url).timeout(const Duration(seconds: 12));
            if (response.statusCode != 200) {
              throw Exception('OSM Routing Server returned ${response.statusCode}');
            }
          } catch (_) {
            final backupUrl = Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
              '?overview=full&geometries=geojson&steps=true&annotations=true',
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

              final List<NavigationStep> osrmSteps = [];
              final List<String> instructions = [];

              if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
                final legs = route['legs'][0];
                if (legs['steps'] != null) {
                  for (final step in legs['steps']) {
                    final stepDistM = (step['distance'] as num).toDouble();
                    final stepDurSec = (step['duration'] as num).toInt();
                    final stepName = step['name'] as String? ?? '';
                    final maneuver = step['maneuver'] ?? {};
                    final typeStr = maneuver['type'] as String? ?? 'turn';
                    final modifier = maneuver['modifier'] as String? ?? '';
                    final exitNum = maneuver['exit']?.toString();

                    final maneuverType = ManeuverType.fromString('$typeStr $modifier');

                    final startCoord = step['maneuver']['location'] as List;
                    final startLoc = LatLng(startCoord[1] as double, startCoord[0] as double);

                    String text = '';
                    if (typeStr == 'roundabout' || typeStr == 'rotary') {
                      text = exitNum != null
                          ? 'Enter roundabout and take exit $exitNum'
                          : 'Enter roundabout';
                    } else if (typeStr == 'arrive') {
                      text = 'Arrive at destination';
                    } else {
                      final action = modifier.isNotEmpty ? '$typeStr $modifier' : typeStr;
                      text = stepName.isNotEmpty
                          ? 'In ${stepDistM.round()}m, $action onto $stepName'
                          : 'In ${stepDistM.round()}m, $action';
                    }

                    osrmSteps.add(
                      NavigationStep(
                        startLocation: startLoc,
                        endLocation: startLoc,
                        distanceMeters: stepDistM,
                        durationSeconds: stepDurSec,
                        maneuverType: maneuverType,
                        instruction: text,
                        roadName: stepName,
                        exitNumber: exitNum,
                        roundaboutExitIndex: int.tryParse(exitNum ?? ''),
                      ),
                    );
                    instructions.add(text);
                  }
                }
              }

              if (osrmSteps.isEmpty) {
                instructions.addAll(_generateInstructionsForPoints(points, language));
              }

              final primaryOpt = RouteOption(
                id: 'osrm_route_0',
                summary: 'OSRM Route',
                coordinates: points,
                distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                durationMin: durationMin > 0 ? durationMin : 1,
                steps: osrmSteps,
                instructions: instructions,
              );

              return RouteData(
                coordinates: points,
                distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                durationMin: durationMin > 0 ? durationMin : 1,
                elevationGainM: mode == 'walking' ? (distanceKm * 20).round() : (distanceKm * 5).round(),
                instructions: instructions,
                steps: osrmSteps,
                options: [primaryOpt],
                selectedOptionIndex: 0,
              );
            }
          }
        } catch (e) {
          debugPrint('[Repository] Online OSRM routing failed: $e.');
        }
      }
    }

    final distanceKm = const Distance().as(LengthUnit.Meter, start, end) / 1000.0;
    final int durationMin = (distanceKm / 0.08).round().clamp(1, 1440);
    return RouteData(
      coordinates: [start, end],
      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      durationMin: durationMin > 0 ? durationMin : 1,
      elevationGainM: (distanceKm * 10).round(),
      instructions: ['Proceed towards destination.'],
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
