import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/local_storage_service.dart';
import '../../data/models/nearby_place.dart';
import '../../data/models/route_data.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../domain/repositories/map_repository.dart';

class MapAlert {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const MapAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityStreamProvider);
  return connectivityAsync.maybeWhen(
    data: (results) {
      if (results.isEmpty) return true;
      return results.any((r) => r != ConnectivityResult.none);
    },
    orElse: () => true,
  );
});

final navigationAlertsProvider = Provider<List<MapAlert>>((ref) {
  final destination = ref.watch(activeDestinationProvider);
  final mode = ref.watch(travelModeProvider);
  
  if (destination == null) return [];

  final List<MapAlert> alerts = [];

  // 1. Crowd Warning Alert
  final cat = destination.category.toLowerCase();
  if (cat == 'monument' || cat == 'attraction' || cat == 'monuments') {
    alerts.add(
      const MapAlert(
        title: 'High Venue Crowds',
        message: 'Acropolis area is currently very crowded. Expect longer entry queues.',
        icon: Icons.people_outline_rounded,
        color: Color(0xFFE65100), // Dark Orange
      ),
    );
  } else if (cat == 'restaurant' || cat == 'cafe') {
    alerts.add(
      const MapAlert(
        title: 'Busy Dining Hours',
        message: 'Peak lunch/dinner time. Average waiting time: 20-30 mins.',
        icon: Icons.restaurant_menu_rounded,
        color: Color(0xFF0D47A1), // Blue
      ),
    );
  }

  // 2. Traffic Congestion Alert
  if (mode == 'driving') {
    alerts.add(
      const MapAlert(
        title: 'Route Traffic Alert',
        message: 'Heavy traffic detected on center streets. Alternate lanes suggested.',
        icon: Icons.traffic_rounded,
        color: Color(0xFFB71C1C), // Deep Red
      ),
    );
  }

  // 3. Best Season Warning Alert
  final currentMonth = DateTime.now().month;
  if (cat == 'monument' || cat == 'attraction' || cat == 'monuments') {
    // High summer months (June = 6, July = 7, August = 8)
    if (currentMonth >= 6 && currentMonth <= 8) {
      alerts.add(
        const MapAlert(
          title: 'Seasonal Weather Alert',
          message: 'Extreme temperature warning (38°C). Not the best season for daytime walking.',
          icon: Icons.wb_sunny_rounded,
          color: Color(0xFFFF8F00), // Amber
        ),
      );
    }
  }

  // 4. Destination Too Far / Simulator Location Alert
  final routeAsync = ref.watch(routeDataProvider);
  final route = routeAsync.valueOrNull;
  if (route != null && route.distanceKm > 1000.0) {
    alerts.add(
      const MapAlert(
        title: 'Destination Too Far',
        message: 'Your current GPS location is very far from the destination (e.g. Cupertino, USA vs. India). Set your device GPS to Noida/local area to calculate valid street routes.',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFD32F2F),
      ),
    );
  }

  return alerts;
});

final localizationProvider = Provider<Locale>((ref) => const Locale('en'));

enum MapEngine { googleMaps, openStreetMap }
final mapEngineProvider = StateProvider<MapEngine>((ref) => MapEngine.googleMaps);

enum NavigationStatus { idle, ready, navigating }

// Repository Provider
final mapRepositoryProvider = Provider<MapRepository>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return MapRepositoryImpl(storage);
});

// Search & Filtering State
final searchQueryProvider = StateProvider<String>((ref) => '');
final activeCategoryProvider = StateProvider<String>((ref) => 'All');
// Nearby Places List Provider
final nearbyPlacesProvider = FutureProvider<List<NearbyPlace>>((ref) async {
  final repository = ref.watch(mapRepositoryProvider);
  final category = ref.watch(activeCategoryProvider);
  final query = ref.watch(searchQueryProvider);
  final location = ref.watch(mapCenterProvider); // Watch mapCenterProvider
  
  return repository.getNearbyPlaces(
    category: category, 
    query: query,
    userLocation: location,
  );
});


// Location State Settings and Stream Providers
final locationSettingsProvider = Provider<LocationSettings>((ref) {
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 10 meters distance filter for responsive rerouting
  );
});

final userLocationStreamProvider = StreamProvider<LatLng>((ref) async* {
  // Check permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      yield const LatLng(28.6139, 77.2090); // Fallback to New Delhi, India
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    yield const LatLng(28.6139, 77.2090);
    return;
  }

  bool serviceEnabled = false;
  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
  } catch (e) {
    debugPrint("Geolocator service check failed: $e");
  }
  if (!serviceEnabled) {
    yield const LatLng(28.6139, 77.2090);
    return;
  }

  // Get current position initially
  LatLng? initialLoc;
  try {
    final Position? lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      initialLoc = LatLng(lastKnown.latitude, lastKnown.longitude);
      yield initialLoc;
    }
  } catch (e) {
    debugPrint('[GPS Shift] Last known position failed: $e');
  }

  try {
    final settings = ref.read(locationSettingsProvider);
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    ).timeout(const Duration(seconds: 5));
    final currentLoc = LatLng(position.latitude, position.longitude);
    if (currentLoc != initialLoc) {
      initialLoc = currentLoc;
      debugPrint('[GPS Shift] Initial user location: Lat: ${initialLoc.latitude}, Lng: ${initialLoc.longitude}');
      yield initialLoc;
    }
  } catch (e) {
    // If GPS failed/timed out, and user is stuck on default Cupertino simulator location,
    // fallback defensively to New Delhi, India so routing works in developer's local region.
    final bool isCupertino = initialLoc != null &&
        (initialLoc.latitude >= 37.32 && initialLoc.latitude <= 37.34) &&
        (initialLoc.longitude >= -122.04 && initialLoc.longitude <= -122.02);
    if (initialLoc == null || isCupertino) {
      debugPrint('[GPS Shift] GPS failed/timed out on Cupertino coordinates, yielding New Delhi.');
      yield const LatLng(28.6139, 77.2090);
    }
  }

  final settings = ref.watch(locationSettingsProvider);
  yield* Geolocator.getPositionStream(locationSettings: settings).map((Position position) {
    final newLoc = LatLng(position.latitude, position.longitude);
    debugPrint('[GPS Shift] User location updated: Lat: ${newLoc.latitude}, Lng: ${newLoc.longitude}');
    return newLoc;
  });
});

// Location State (Default starting point: India / New Delhi)
final userLocationProvider = Provider<LatLng>((ref) {
  final locationAsync = ref.watch(userLocationStreamProvider);
  return locationAsync.maybeWhen(
    data: (location) => location,
    orElse: () => const LatLng(28.6139, 77.2090),
  );
});

// Map center provider (defaults to user location, but can be updated when geocoding a searched city)
final mapCenterProvider = StateProvider<LatLng>((ref) {
  final userLoc = ref.watch(userLocationProvider);
  return userLoc;
});

// Travel Selection State
final activeDestinationProvider = StateProvider<NearbyPlace?>((ref) => null);
final travelModeProvider = StateProvider<String>((ref) => 'walking'); // 'walking', 'driving', 'transit'

// Provider to cache original online route coordinates
final originalRouteCoordinatesProvider = StateProvider<List<LatLng>>((ref) => []);

// Route Calculations Provider
final routeDataProvider = FutureProvider<RouteData>((ref) async {
  final repository = ref.watch(mapRepositoryProvider);
  final navStatus = ref.watch(navigationStatusProvider);
  final start = (navStatus == NavigationStatus.navigating)
      ? ref.read(userLocationProvider)
      : ref.watch(userLocationProvider);
  final destination = ref.watch(activeDestinationProvider);
  final mode = ref.watch(travelModeProvider);

  if (destination == null) {
    Future.microtask(() {
      ref.read(originalRouteCoordinatesProvider.notifier).state = [];
    });
    return RouteData.empty();
  }

  // Monitor the network state reactively
  final isOnline = ref.watch(isOnlineProvider);
  final langCode = ref.watch(localizationProvider).languageCode;

  if (isOnline) {
    final route = await repository.getRoute(
      start: start,
      end: destination.location,
      mode: mode,
      language: langCode,
    );
    // Cache the online route coordinates
    Future.microtask(() {
      ref.read(originalRouteCoordinatesProvider.notifier).state = route.coordinates;
    });
    return route;
  } else {
    // Offline Mode: Attempt to trim current online cached route if available
    final cachedCoordinates = ref.read(originalRouteCoordinatesProvider);
    if (cachedCoordinates.isNotEmpty) {
      int closestIndex = 0;
      double minDistance = double.infinity;
      for (int i = 0; i < cachedCoordinates.length; i++) {
        final dist = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          cachedCoordinates[i].latitude,
          cachedCoordinates[i].longitude,
        );
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }

      final remainingCoords = [start, ...cachedCoordinates.sublist(closestIndex)];

      // Estimate remaining parameters proportionally
      final totalDistM = Geolocator.distanceBetween(
        cachedCoordinates.first.latitude,
        cachedCoordinates.first.longitude,
        cachedCoordinates.last.latitude,
        cachedCoordinates.last.longitude,
      );
      final remainingDistM = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        cachedCoordinates.last.latitude,
        cachedCoordinates.last.longitude,
      );

      final proportion = totalDistM > 0 ? (remainingDistM / totalDistM).clamp(0.0, 1.0) : 1.0;

      final baseRoute = await repository.getRoute(
        start: start,
        end: destination.location,
        mode: mode,
        language: langCode,
      );

      return RouteData(
        coordinates: remainingCoords,
        distanceKm: double.parse((baseRoute.distanceKm * proportion).toStringAsFixed(1)),
        durationMin: (baseRoute.durationMin * proportion).round().clamp(1, 120),
        elevationGainM: (baseRoute.elevationGainM * proportion).round(),
        instructions: baseRoute.instructions,
      );
    } else {
      // Completely offline fallback -> Return direct straight line route
      return repository.getRoute(
        start: start,
        end: destination.location,
        mode: mode,
        language: langCode,
      );
    }
  }
});

// Navigation Simulation State
final navigationStatusProvider = StateProvider<NavigationStatus>((ref) => NavigationStatus.idle);
final navigationIndexProvider = StateProvider<int>((ref) => 0);
final simulatedLocationProvider = StateProvider<LatLng?>((ref) => null);
final voiceEnabledProvider = StateProvider<bool>((ref) => true);

// Autocomplete Predictions Provider
final autocompletePredictionsProvider = FutureProvider.family<List<Map<String, String>>, String>((ref, input) async {
  if (input.trim().isEmpty) return [];
  final repository = ref.watch(mapRepositoryProvider);
  return repository.getAutocompletePredictions(input);
});

// Provider to toggle Heatmap Layer
final showHeatmapProvider = StateProvider<bool>((ref) => false);

// Provider to manage Google Maps View Type (normal vs satellite)
final googleMapTypeProvider = StateProvider<String>((ref) => 'normal');

// Provider to trigger recentering
final recenterTriggerProvider = StateProvider<int>((ref) => 0);

// Provider to manage user GPS tracking mode state (active/inactive)
final isTrackingUserProvider = StateProvider<bool>((ref) => true);
