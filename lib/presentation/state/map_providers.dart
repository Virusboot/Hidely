import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
  final bool isInfoBrief;
  final String? actionLabel;

  const MapAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.isInfoBrief = false,
    this.actionLabel,
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
  final navStatus = ref.watch(navigationStatusProvider);
  final navIndex = ref.watch(navigationIndexProvider); // Watch active step index to show situation-aware alerts
  
  if (destination == null) return [];

  final List<MapAlert> alerts = [];

  // Active Navigation Real-Time Situational Alerts (triggered sequentially/situationally during navigation)
  if (navStatus == NavigationStatus.navigating) {
    // 1. Weak Network Warning (Shown only at early steps: step 1 or 2)
    if (navIndex == 1 || navIndex == 2) {
      alerts.add(
        const MapAlert(
          title: '⚠️ Low Mobile Network Zone Ahead (2 km)',
          message: 'Weak signal expected ahead. Download offline map pack now to avoid losing signal.',
          icon: Icons.signal_cellular_connected_no_internet_4_bar_rounded,
          color: Color(0xFFD97706), // Amber
          actionLabel: 'Download Offline Map',
        ),
      );
    }

    // 2. Traffic Delay Caution (Shown only around step 4)
    if (navIndex == 4) {
      alerts.add(
        const MapAlert(
          title: '🚦 Traffic Slowdown 1.5 km Ahead',
          message: 'Moderate congestion near toll plaza. Keep right lane for smooth bypass.',
          icon: Icons.traffic_rounded,
          color: Color(0xFFDC2626), // Red
        ),
      );
    }

    // 3. Weather & Mountain Road Caution (Shown only around step 7)
    if (navIndex == 7) {
      alerts.add(
        const MapAlert(
          title: '🌫️ Weather & Winding Road Caution',
          message: 'Patchy fog & steep turns ahead. Drive slow with low beams.',
          icon: Icons.wb_cloudy_rounded,
          color: Color(0xFF4B5563), // Slate
        ),
      );
    }

    // 4. Fuel & Rest Area Alert (Shown only around step 10)
    if (navIndex == 10) {
      alerts.add(
        const MapAlert(
          title: '⛽ Last Fuel & Rest Area Ahead',
          message: 'Final petrol pump & service station before 25 km mountain stretch.',
          icon: Icons.local_gas_station_rounded,
          color: Color(0xFF2563EB), // Blue
        ),
      );
    }
  }

  // 3. Crowd Density Alert (when not navigating)
  if (navStatus != NavigationStatus.navigating) {
    final cat = destination.category.toLowerCase();
    if (cat == 'monument' || cat == 'attraction' || cat == 'monuments') {
      alerts.add(
        const MapAlert(
          title: 'Optimal Visit Time',
          message: 'Venue is currently at low crowd levels. Entry queue < 5 minutes.',
          icon: Icons.people_outline_rounded,
          color: Color(0xFF16A34A), // Green
        ),
      );
    }
  }

  // 4. Destination Distance Notice
  final routeAsync = ref.watch(routeDataProvider);
  final route = routeAsync.valueOrNull;
  if (route != null && route.distanceKm > 1000.0) {
    alerts.add(
      const MapAlert(
        title: 'Destination Distance Notice',
        message: 'Current GPS location is very far from destination. Ensure location settings are precise.',
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
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // 1 meter high precision filter
      intervalDuration: const Duration(seconds: 1), // 1 second update rate
    );
  } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // 1 meter high precision filter
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 1,
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
final travelModeProvider = StateProvider<String>((ref) {
  if (!kIsWeb && Platform.isAndroid) {
    return 'bicycling';
  }
  return 'walking';
}); // 'walking', 'driving', 'transit'

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
