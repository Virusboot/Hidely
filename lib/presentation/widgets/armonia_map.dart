import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'map_sizes.dart';

import '../../data/models/nearby_place.dart';
import '../../data/models/route_data.dart';
import '../state/map_providers.dart';

class AppColors {
  static const Color primaryPurple = Color(0xff2B1564);
  static const Color textGray = Color(0xFF6B657D);
}

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => AppLocalizations();

  String get offlineMapUnavailable => 'Offline Map Unavailable';
  String get offlineMapUnavailableMessage => 'The offline map is currently offline.';
}

// Helper coordinate mapping functions to resolve LatLng namespace conflicts
gmaps.LatLng _toGoogleLatLng(LatLng point) {
  return gmaps.LatLng(point.latitude, point.longitude);
}

class ArmoniaMap extends ConsumerStatefulWidget {
  final LatLng center;
  final List<NearbyPlace> places;
  final NearbyPlace? activeDestination;
  final RouteData? activeRoute;
  final LatLng? simulatedLocation;
  final Function(NearbyPlace) onSelectPlace;

  const ArmoniaMap({
    super.key,
    required this.center,
    required this.places,
    this.activeDestination,
    this.activeRoute,
    this.simulatedLocation,
    required this.onSelectPlace,
  });

  @override
  ConsumerState<ArmoniaMap> createState() => _ArmoniaMapState();
}

class _ArmoniaMapState extends ConsumerState<ArmoniaMap> {
  static const String _mapStyleJson = '''
[
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [ { "visibility": "off" } ]
  }
]
''';

  gmaps.GoogleMapController? _googleMapController;
  final fm.MapController _osmMapController = fm.MapController();
  // ignore: unused_field
  String? _offlineStyleString;
  String _offlineTilesPath = '';

  final Map<String, gmaps.BitmapDescriptor> _customMarkers = {};
  gmaps.BitmapDescriptor? _userLocationDescriptor;
  bool _isProgrammaticMove = false;
  Timer? _osmAnimationTimer;

  @override
  void initState() {
    super.initState();
    _initOfflineStyle();
    _loadCustomMarkers();
    // Retrieve initial travel mode to construct correct icon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialMode = ref.read(travelModeProvider);
        _updateUserLocationMarker(initialMode);
      }
    });
  }

  void _updateUserLocationMarker(String mode, {NavigationStatus? status}) {
    final currentStatus = status ?? ref.read(navigationStatusProvider);
    if (currentStatus == NavigationStatus.navigating) {
      _createTravelModeMarker(mode).then((descriptor) {
        if (mounted) {
          setState(() {
            _userLocationDescriptor = descriptor;
          });
        }
      }).catchError((e) {
        debugPrint('Failed to generate 3D travel mode user marker: $e');
      });
    } else {
      _createCategoryMarker(AppColors.primaryPurple, 'user').then((descriptor) {
        if (mounted) {
          setState(() {
            _userLocationDescriptor = descriptor;
          });
        }
      }).catchError((e) {
        debugPrint('Failed to generate simple dot user marker: $e');
      });
    }
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    _osmAnimationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initOfflineStyle() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final tilesPath = '${directory.path}/offline_map/tiles';
      // Search for locally stored offline map style JSON
      final offlineStyleFile = File('${directory.path}/offline_map/style.json');
      final exists = await offlineStyleFile.exists();
      
      debugPrint('[OfflineStyle] Checking for offline map style at: ${offlineStyleFile.path}');
      debugPrint('[OfflineStyle] Style file exists: $exists');

      if (exists) {
        final jsonString = await offlineStyleFile.readAsString();
        debugPrint('[OfflineStyle] Loaded style JSON content successfully! Length: ${jsonString.length} chars.');
        if (mounted) {
          setState(() {
            _offlineStyleString = jsonString;
            _offlineTilesPath = tilesPath;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _offlineStyleString = '';
            _offlineTilesPath = '';
          });
        }
      }
    } catch (e) {
      debugPrint('[OfflineStyle] Error locating/reading offline map style: $e');
      if (mounted) {
        setState(() {
          _offlineStyleString = '';
          _offlineTilesPath = '';
        });
      }
    }
  }

  IconData _getIconForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat == 'destination') {
      return Icons.star_rounded;
    }
    if (cat == 'user') {
      return Icons.my_location_rounded;
    }
    
    final bool hasRestaurant = cat.contains('restaurant') || cat.contains('food') || cat.contains('dining') || cat.contains('cafe');
    final bool hasStay = cat.contains('stay') || cat.contains('hotel') || cat.contains('hostel') || cat.contains('lodging') || cat.contains('resort');
    
    if (hasRestaurant && hasStay) {
      return Icons.room_service_rounded; // Combined Stay & Restaurant icon
    }
    if (hasRestaurant) {
      return Icons.restaurant_rounded;
    }
    if (hasStay) {
      return Icons.hotel_rounded;
    }
    if (cat.contains('mountain') || cat.contains('hill') || cat.contains('trek') || cat.contains('peak') || cat.contains('landscape') || cat.contains('terrain')) {
      return Icons.terrain_rounded;
    }
    if (cat.contains('river') || cat.contains('lake') || cat.contains('water') || cat.contains('boating') || cat.contains('pond')) {
      return Icons.waves_rounded;
    }
    if (cat.contains('waterfall') || cat.contains('falls')) {
      return Icons.water_drop_rounded;
    }
    if (cat.contains('monument') || cat.contains('museum') || cat.contains('history') || cat.contains('temple') || cat.contains('fort') || cat.contains('palace') || cat.contains('tomb')) {
      return Icons.account_balance_rounded;
    }
    return Icons.place_rounded;
  }

  Color _getColorForCategory(String category) {
    final cat = category.toLowerCase();
    
    final bool hasRestaurant = cat.contains('restaurant') || cat.contains('food') || cat.contains('dining') || cat.contains('cafe');
    final bool hasStay = cat.contains('stay') || cat.contains('hotel') || cat.contains('hostel') || cat.contains('lodging') || cat.contains('resort');
    
    if (hasRestaurant && hasStay) {
      return const Color(0xff009688); // Teal/Emerald for combined Stay + Restaurant
    }
    if (hasRestaurant) {
      return const Color(0xffF57C00); // Orange for Restaurant
    }
    if (hasStay) {
      return const Color(0xff0288D1); // Blue for Stay
    }
    if (cat.contains('mountain') || cat.contains('hill') || cat.contains('trek') || cat.contains('peak') || cat.contains('landscape') || cat.contains('terrain')) {
      return const Color(0xff795548); // Brown for Mountains
    }
    if (cat.contains('river') || cat.contains('lake') || cat.contains('water') || cat.contains('boating')) {
      return const Color(0xff00BCD4); // Cyan for River/Lake
    }
    if (cat.contains('waterfall') || cat.contains('falls')) {
      return const Color(0xff3F51B5); // Indigo for Waterfalls
    }
    if (cat.contains('monument') || cat.contains('museum') || cat.contains('history') || cat.contains('temple') || cat.contains('fort') || cat.contains('palace') || cat.contains('tomb')) {
      return const Color(0xff9C27B0); // Purple for Monuments
    }
    return const Color(0xff5B3EC8); // Default purple
  }

  Future<gmaps.BitmapDescriptor> _createCategoryMarker(Color color, String category) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    // Scale up the canvas size for crisp rendering on high-DPI devices
    final bool isUser = category == 'user';
    final double baseSize = isUser ? 12.0 : 20.0; // Dynamic size for user location marker
    const double pixelRatio = 1.0; // 1.0x ratio for true logical size mapping on Android
    final double size = baseSize * pixelRatio;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 1.0 * pixelRatio);
    canvas.drawCircle(Offset(size / 2, size / 2), (baseSize / 2 - 1.0) * pixelRatio, shadowPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), (baseSize / 2 - 1.0) * pixelRatio, whitePaint);

    final colorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), (baseSize / 2 - 2.5) * pixelRatio, colorPaint);

    final iconData = _getIconForCategory(category);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: (isUser ? 5.5 : 9.5) * pixelRatio, // Scaled with pixel ratio
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();

    final offset = Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<ui.Image> _loadUiImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<gmaps.BitmapDescriptor> _createTravelModeMarker(String travelMode) async {
    String assetPath;
    if (travelMode == 'driving') {
      assetPath = 'assets/images/car_3d.png';
    } else if (travelMode == 'bicycling') {
      assetPath = 'assets/images/bike_3d.png';
    } else {
      assetPath = 'assets/images/walk_3d.png';
    }

    try {
      final ui.Image image = await _loadUiImage(assetPath);
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Significantly reduced logical sizes (walking uses 22px, car/bike use 26px)
      final double baseSize = (travelMode == 'walking') ? 22.0 : 26.0;
      const double pixelRatio = 1.0; // 1.0x ratio for true logical size mapping on Android
      final double size = baseSize * pixelRatio;
      
      // Calculate scaled bounds to maintain perfect aspect ratio without stretching
      double imgWidth = image.width.toDouble();
      double imgHeight = image.height.toDouble();
      double scale = 1.0;
      
      if (imgWidth > imgHeight) {
        scale = size / imgWidth;
      } else {
        scale = size / imgHeight;
      }
      
      double drawWidth = imgWidth * scale;
      double drawHeight = imgHeight * scale;
      double dx = (size - drawWidth) / 2;
      double dy = (size - drawHeight) / 2;
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, imgWidth, imgHeight),
        Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
        Paint()..isAntiAlias = true..filterQuality = ui.FilterQuality.high,
      );

      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return gmaps.BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load 3D asset marker for $travelMode: $e. Falling back to default.');
    }
    return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure);
  }

  void _loadCustomMarkers() {
    final allPlaces = [
      if (widget.activeDestination != null) widget.activeDestination!,
      ...widget.places,
    ];

    final List<Future<void>> loadingFutures = [];

    for (final place in allPlaces) {
      final isDest = widget.activeDestination?.id == place.id;
      final cacheKey = isDest ? '${place.id}_dest' : place.id;
      if (_customMarkers.containsKey(cacheKey)) continue;

      // Add a placeholder to prevent duplicate builds
      _customMarkers[cacheKey] = gmaps.BitmapDescriptor.defaultMarker;

      final color = isDest ? const Color(0xff5B3EC8) : _getColorForCategory(place.category);
      final future = _createCategoryMarker(color, isDest ? 'destination' : place.category).then((descriptor) {
        _customMarkers[cacheKey] = descriptor;
      }).catchError((e) {
        debugPrint('Failed to load category marker for ${place.name}: $e');
      });
      loadingFutures.add(future);
    }

    if (loadingFutures.isNotEmpty) {
      Future.wait(loadingFutures).then((_) {
        if (mounted) {
          setState(() {
            // Rebuild the map once after all new markers are generated
          });
        }
      });
    }
  }


  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * pi / 180.0;
    final double lon1 = start.longitude * pi / 180.0;
    final double lat2 = end.latitude * pi / 180.0;
    final double lon2 = end.longitude * pi / 180.0;

    final double dLon = lon2 - lon1;

    final double y = sin(dLon) * cos(lat2);
    final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final double radians = atan2(y, x);
    return (radians * 180.0 / pi + 360.0) % 360.0;
  }

  void _animateOsmMap(LatLng destCenter, double destZoom, double destBearing) {
    final startCenter = _osmMapController.camera.center;
    final startZoom = _osmMapController.camera.zoom;
    final startBearing = _osmMapController.camera.rotation;

    const int steps = 12; // ~200ms animation duration for super responsive yet smooth transitions
    int currentStep = 0;

    _osmAnimationTimer?.cancel();
    _osmAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double t = currentStep / steps;
      final double ease = 1 - pow(1 - t, 3).toDouble(); // Cubic ease-out

      final lat = startCenter.latitude + (destCenter.latitude - startCenter.latitude) * ease;
      final lng = startCenter.longitude + (destCenter.longitude - startCenter.longitude) * ease;
      final zoom = startZoom + (destZoom - startZoom) * ease;

      double diff = destBearing - startBearing;
      while (diff < -180) {
        diff += 360;
      }
      while (diff > 180) {
        diff -= 360;
      }
      final bearing = startBearing + diff * ease;

      try {
        _osmMapController.moveAndRotate(LatLng(lat, lng), zoom, bearing);
      } catch (_) {}

      if (currentStep >= steps) {
        timer.cancel();
      }
    });
  }

  void _animateCameraSafe(gmaps.CameraUpdate update) {
    if (_googleMapController != null) {
      _isProgrammaticMove = true;
      _googleMapController!.animateCamera(update).then((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _isProgrammaticMove = false;
        });
      }).catchError((_) {
        _isProgrammaticMove = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ArmoniaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initOfflineStyle();

    final oldLocation = oldWidget.simulatedLocation ?? oldWidget.center;
    final newLocation = widget.simulatedLocation ?? widget.center;
    final locationChanged = oldLocation.latitude != newLocation.latitude ||
        oldLocation.longitude != newLocation.longitude;
    final oldDest = oldWidget.activeDestination;
    final newDest = widget.activeDestination;
    final oldPlaces = oldWidget.places;
    final newPlaces = widget.places;

    // React to changes in online maps
    final destChanged = oldDest?.location.latitude != newDest?.location.latitude ||
        oldDest?.location.longitude != newDest?.location.longitude;

    final mapEngine = ref.read(mapEngineProvider);
    if (mapEngine == MapEngine.googleMaps && _googleMapController != null) {
      final isNavigating = ref.read(navigationStatusProvider) == NavigationStatus.navigating;
      if (isNavigating && locationChanged) {
        final bearing = _calculateBearing(oldLocation, newLocation);
        _animateCameraSafe(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: _toGoogleLatLng(newLocation),
              zoom: 19.2,
              tilt: 45.0,
              bearing: bearing,
            ),
          ),
        );
      } else if (newDest != null && destChanged) {
        _animateCameraSafe(
          gmaps.CameraUpdate.newLatLng(_toGoogleLatLng(newDest.location)),
        );
      } else if (locationChanged) {
        _animateCameraSafe(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: _toGoogleLatLng(newLocation),
              zoom: 16.5,
              tilt: 0.0,
              bearing: 0.0,
            ),
          ),
        );
      }
    } else {
      // OSM map panning (works both online and offline)
      try {
        if (newDest != null && destChanged) {
          _animateOsmMap(newDest.location, 14.5, 0.0);
        } else if (locationChanged) {
          final isNavigating = ref.read(navigationStatusProvider) == NavigationStatus.navigating;
          if (isNavigating) {
            final bearing = _calculateBearing(oldLocation, newLocation);
            _animateOsmMap(newLocation, 18.5, bearing);
          } else {
            _animateOsmMap(newLocation, 16.5, 0.0);
          }
        }
      } catch (e) {
        debugPrint('[OSM Map] Failed to pan OSM map: $e');
      }
    }

    final placesChanged = oldPlaces != newPlaces || oldDest != newDest;
    if (placesChanged) {
      _loadCustomMarkers();
    }
  }

  bool _isPlaceNearRoute(LatLng placeLoc, List<LatLng> routeCoords, double thresholdMeters) {
    if (routeCoords.isEmpty) return false;
    final int step = (routeCoords.length / 50).ceil().clamp(1, 10);
    for (int i = 0; i < routeCoords.length; i += step) {
      final double distance = Geolocator.distanceBetween(
        placeLoc.latitude,
        placeLoc.longitude,
        routeCoords[i].latitude,
        routeCoords[i].longitude,
      );
      if (distance <= thresholdMeters) {
        return true;
      }
    }
    final double finalDistance = Geolocator.distanceBetween(
      placeLoc.latitude,
      placeLoc.longitude,
      routeCoords.last.latitude,
      routeCoords.last.longitude,
    );
    if (finalDistance <= thresholdMeters) {
      return true;
    }
    return false;
  }

  Set<gmaps.Marker> _buildGoogleMarkers(LatLng currentLocation, NearbyPlace? activeDestination) {
    final Set<gmaps.Marker> markers = {};

    // Simulated/current user location marker
    markers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('user_location'),
        position: _toGoogleLatLng(currentLocation),
        icon: _userLocationDescriptor ??
            gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
        infoWindow: const gmaps.InfoWindow(
          title: 'My Location',
        ),
      ),
    );

    // Destination marker
    if (activeDestination != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('destination'),
          position: _toGoogleLatLng(activeDestination.location),
          icon: _customMarkers['${activeDestination.id}_dest'] ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueViolet),
          infoWindow: gmaps.InfoWindow(
            title: activeDestination.name,
            snippet: activeDestination.category,
          ),
        ),
      );
    }

    final route = widget.activeRoute;
    final hasActiveRoute = route != null && route.coordinates.isNotEmpty;

    final activeCategory = ref.read(activeCategoryProvider).toLowerCase();

    // Nearby places markers
    for (final place in widget.places) {
      if (activeDestination?.id == place.id) continue;

      // Show if a specific filter is selected, OR if 'All' is selected and they are near the route path
      if (activeCategory == 'all' && (!hasActiveRoute || !_isPlaceNearRoute(place.location, route.coordinates, 300.0))) {
        continue;
      }

      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(place.id),
          position: _toGoogleLatLng(place.location),
          icon: _customMarkers[place.id] ??
              gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
          infoWindow: gmaps.InfoWindow(
            title: place.name,
            snippet: place.category,
          ),
          onTap: () => widget.onSelectPlace(place),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final travelMode = ref.watch(travelModeProvider);
    final mapEngine = ref.watch(mapEngineProvider);

    // Listen to changes in connection status (from offline to online)
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous != true) {
        // Connection went from offline/null to online!
        // Clear cached markers to force reloading them with remote images
        _customMarkers.clear();
        _loadCustomMarkers();
      }
    });

    // Listen to changes in travel mode to update user location marker icon dynamically
    ref.listen<String>(travelModeProvider, (previous, next) {
      _updateUserLocationMarker(next);
    });

    // Listen to explicit recenter trigger events
    ref.listen<int>(recenterTriggerProvider, (previous, next) {
      if (next > 0) {
        final userLoc = ref.read(userLocationProvider);
        if (isOnline && mapEngine == MapEngine.googleMaps && _googleMapController != null) {
          _googleMapController!.animateCamera(
            gmaps.CameraUpdate.newCameraPosition(
              gmaps.CameraPosition(
                target: _toGoogleLatLng(userLoc),
                zoom: 16.5,
                tilt: 0.0,
                bearing: 0.0,
              ),
            ),
          );
        } else {
          try {
            _animateOsmMap(userLoc, 16.5, 0.0);
          } catch (e) {
            debugPrint('[Recenter] Failed to recenter OSM: $e');
          }
        }
      }
    });

    // Listen to navigation status to tilt and zoom the camera for turn-by-turn navigation view
    ref.listen<NavigationStatus>(navigationStatusProvider, (previous, next) {
      // Dynamic user location marker update (toggles simple dot vs 3D icon)
      final mode = ref.read(travelModeProvider);
      _updateUserLocationMarker(mode, status: next);
      final mapEngine = ref.read(mapEngineProvider);
      final currentLocation = widget.simulatedLocation ?? widget.center;

      if (mapEngine == MapEngine.googleMaps && _googleMapController != null) {
        if (next == NavigationStatus.navigating) {
          _googleMapController!.animateCamera(
            gmaps.CameraUpdate.newCameraPosition(
              gmaps.CameraPosition(
                target: _toGoogleLatLng(currentLocation),
                zoom: 19.2,
                tilt: 45.0,
                bearing: 0.0,
              ),
            ),
          );
        } else if (next == NavigationStatus.idle) {
          _googleMapController!.animateCamera(
            gmaps.CameraUpdate.newCameraPosition(
              gmaps.CameraPosition(
                target: _toGoogleLatLng(currentLocation),
                zoom: 15.5,
                tilt: 0.0,
                bearing: 0.0,
              ),
            ),
          );
        }
      } else {
        try {
          if (next == NavigationStatus.navigating) {
            _animateOsmMap(currentLocation, 18.5, 0.0);
          } else if (next == NavigationStatus.idle) {
            _animateOsmMap(currentLocation, 15.5, 0.0);
          }
        } catch (_) {}
      }
    });

    const isTestMode = bool.fromEnvironment('FLUTTER_TEST');
    
    // In test environment, render a fallback container to prevent native rendering crash
    if (isTestMode) {
      return Container(
        color: const Color(0xFFECE6F0),
        child: Center(
          child: Icon(
            Icons.map_rounded,
            color: AppColors.primaryPurple.withOpacity(0.2),
            size: context.w(64),
          ),
        ),
      );
    }

    final currentLocation = widget.simulatedLocation ?? widget.center;
    final destinationTarget = widget.activeDestination?.location ?? const LatLng(28.6139, 77.2090);

    if (mapEngine == MapEngine.googleMaps) {
      // --- Online Mode: Google Maps ---
      final googleMapType = ref.watch(googleMapTypeProvider);
      return RepaintBoundary(
        child: gmaps.GoogleMap(
        mapType: googleMapType == 'satellite' ? gmaps.MapType.satellite : gmaps.MapType.normal,
        style: googleMapType == 'satellite' ? null : _mapStyleJson,
        initialCameraPosition: gmaps.CameraPosition(
          target: _toGoogleLatLng(currentLocation),
          zoom: 15.5,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        trafficEnabled: true,
        onMapCreated: (gmaps.GoogleMapController controller) {
          _googleMapController = controller;
          controller.animateCamera(
            gmaps.CameraUpdate.newLatLng(_toGoogleLatLng(currentLocation)),
          );
        },
        onCameraMoveStarted: () {
          if (!_isProgrammaticMove) {
            ref.read(isTrackingUserProvider.notifier).state = false;
          }
        },
        polylines: {
          if (widget.activeRoute != null && widget.activeRoute!.coordinates.isNotEmpty)
            gmaps.Polyline(
              polylineId: const gmaps.PolylineId('routing_line'),
              points: widget.activeRoute!.coordinates.map(_toGoogleLatLng).toList(),
              color: const Color(0xFF2563EB), // Vibrant Electric Blue navigation route
              width: 7,
              jointType: gmaps.JointType.round,
              startCap: gmaps.Cap.roundCap,
              endCap: gmaps.Cap.roundCap,
              patterns: travelMode == 'walking'
                  ? [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)]
                  : [],
            )
          else if (widget.activeDestination != null)
            gmaps.Polyline(
              polylineId: const gmaps.PolylineId('routing_line'),
              points: [_toGoogleLatLng(currentLocation), _toGoogleLatLng(destinationTarget)],
              color: const Color(0xFF2563EB), // Vibrant Electric Blue navigation route
              width: 7,
              jointType: gmaps.JointType.round,
              startCap: gmaps.Cap.roundCap,
              endCap: gmaps.Cap.roundCap,
              patterns: travelMode == 'walking'
                  ? [gmaps.PatternItem.dash(20), gmaps.PatternItem.gap(10)]
                  : [],
            ),
        },
        markers: _buildGoogleMarkers(currentLocation, widget.activeDestination),
        circles: _buildGoogleCircles(widget.places),
      ),
    );
    } else {
      // --- Offline/OSM Mode: Interactive Tile Map via flutter_map ---
      return fm.FlutterMap(
        mapController: _osmMapController,
        options: fm.MapOptions(
          initialCenter: currentLocation,
          initialZoom: 14.5,
          maxZoom: isOnline ? 19.5 : 15.0,
          minZoom: isOnline ? 1.0 : 13.0,
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) {
              ref.read(isTrackingUserProvider.notifier).state = false;
            }
          },
        ),
        children: [
          if (isOnline || _offlineTilesPath.isNotEmpty)
            fm.TileLayer(
              urlTemplate: isOnline 
                  ? 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png' 
                  : '$_offlineTilesPath/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              tileProvider: isOnline 
                  ? fm.NetworkTileProvider(
                      headers: {
                        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
                      },
                    ) 
                  : fm.FileTileProvider(),
              fallbackUrl: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            ),
          if (ref.watch(showHeatmapProvider))
            fm.CircleLayer(
              circles: _buildOfflineCircles(widget.places),
            ),
          fm.MarkerLayer(
            markers: _buildOfflineMapMarkers(currentLocation, widget.activeDestination),
          ),
          if (widget.activeRoute != null && widget.activeRoute!.coordinates.isNotEmpty)
            fm.PolylineLayer(
              polylines: _buildOfflinePolylines(widget.activeRoute!.coordinates, travelMode),
            )
          else if (widget.activeDestination != null)
            fm.PolylineLayer(
              polylines: _buildOfflinePolylines(
                [currentLocation, widget.activeDestination!.location],
                travelMode,
              ),
            ),
        ],
      );
    }
  }

  List<fm.Polyline> _buildOfflinePolylines(List<LatLng> coordinates, String travelMode) {
    if (coordinates.isEmpty) return [];

    return [
      fm.Polyline(
        points: coordinates,
        color: const Color(0xFF2563EB), // Vibrant Electric Blue navigation route
        strokeWidth: 7.0,
        isDotted: travelMode == 'walking',
      ),
    ];
  }

  List<fm.Marker> _buildOfflineMapMarkers(LatLng currentLocation, NearbyPlace? activeDestination) {
    final List<fm.Marker> markers = [];
    
    // User location marker
    markers.add(
      fm.Marker(
        point: currentLocation,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0080FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );

    // Destination marker
    if (activeDestination != null) {
      markers.add(
        fm.Marker(
          point: activeDestination.location,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xff5B3EC8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
    }

    final route = widget.activeRoute;
    final hasActiveRoute = route != null && route.coordinates.isNotEmpty;

    final activeCategory = ref.read(activeCategoryProvider).toLowerCase();

    // Nearby places markers
    for (final place in widget.places) {
      if (activeDestination != null && place.id == activeDestination.id) continue;

      // Show if a specific filter is selected, OR if 'All' is selected and they are near the route path
      if (activeCategory == 'all' && (!hasActiveRoute || !_isPlaceNearRoute(place.location, route.coordinates, 300.0))) {
        continue;
      }
      
      final color = _getColorForCategory(place.category);
      markers.add(
        fm.Marker(
          point: place.location,
          width: 24,
          height: 24,
          child: GestureDetector(
            onTap: () => widget.onSelectPlace(place),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForCategory(place.category),
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Set<gmaps.Circle> _buildGoogleCircles(List<NearbyPlace> places) {
    final showHeatmap = ref.watch(showHeatmapProvider);
    if (!showHeatmap) return {};

    final route = widget.activeRoute;
    final hasActiveRoute = route != null && route.coordinates.isNotEmpty;

    final activeCategory = ref.read(activeCategoryProvider).toLowerCase();

    final Set<gmaps.Circle> circles = {};
    for (final place in places) {
      if (activeCategory == 'all' && (!hasActiveRoute || !_isPlaceNearRoute(place.location, route.coordinates, 300.0))) {
        continue;
      }

      final googleLoc = _toGoogleLatLng(place.location);

      // Outer glow
      circles.add(
        gmaps.Circle(
          circleId: gmaps.CircleId('heatmap_outer_${place.id}'),
          center: googleLoc,
          radius: 180,
          fillColor: Colors.red.withOpacity(0.08),
          strokeWidth: 0,
        ),
      );

      // Mid glow
      circles.add(
        gmaps.Circle(
          circleId: gmaps.CircleId('heatmap_mid_${place.id}'),
          center: googleLoc,
          radius: 100,
          fillColor: Colors.orange.withOpacity(0.18),
          strokeWidth: 0,
        ),
      );

      // Inner core
      circles.add(
        gmaps.Circle(
          circleId: gmaps.CircleId('heatmap_inner_${place.id}'),
          center: googleLoc,
          radius: 40,
          fillColor: Colors.yellow.withOpacity(0.35),
          strokeWidth: 0,
        ),
      );
    }
    return circles;
  }

  List<fm.CircleMarker> _buildOfflineCircles(List<NearbyPlace> places) {
    final route = widget.activeRoute;
    final hasActiveRoute = route != null && route.coordinates.isNotEmpty;

    final activeCategory = ref.read(activeCategoryProvider).toLowerCase();

    final List<fm.CircleMarker> circles = [];
    for (final place in places) {
      if (activeCategory == 'all' && (!hasActiveRoute || !_isPlaceNearRoute(place.location, route.coordinates, 300.0))) {
        continue;
      }

      // Outer glow
      circles.add(
        fm.CircleMarker(
          point: place.location,
          radius: 180,
          useRadiusInMeter: true,
          color: Colors.red.withOpacity(0.08),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Mid glow
      circles.add(
        fm.CircleMarker(
          point: place.location,
          radius: 100,
          useRadiusInMeter: true,
          color: Colors.orange.withOpacity(0.18),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Inner core
      circles.add(
        fm.CircleMarker(
          point: place.location,
          radius: 40,
          useRadiusInMeter: true,
          color: Colors.yellow.withOpacity(0.35),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }
    return circles;
  }
}

class OfflinePolylinePainter extends CustomPainter {
  final List<LatLng> coordinates;
  final String travelMode;
  final Offset Function(LatLng, Size) getOffset;

  OfflinePolylinePainter({
    required this.coordinates,
    required this.travelMode,
    required this.getOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.isEmpty) return;

    final paint = Paint()
      ..color = travelMode == 'transit' ? const Color(0xFF0080FF) : AppColors.primaryPurple
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = ui.Path();
    final startOffset = getOffset(coordinates.first, size);
    path.moveTo(startOffset.dx, startOffset.dy);

    for (int i = 1; i < coordinates.length; i++) {
      final offset = getOffset(coordinates[i], size);
      path.lineTo(offset.dx, offset.dy);
    }

    if (travelMode == 'transit') {
      final dashPath = _buildDashPath(path, 15.0, 10.0);
      canvas.drawPath(dashPath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  ui.Path _buildDashPath(ui.Path source, double dashWidth, double gapWidth) {
    final ui.Path dest = ui.Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashWidth : gapWidth;
        final double nextDistance = (distance + len).clamp(0.0, metric.length);
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, nextDistance),
            Offset.zero,
          );
        }
        distance = nextDistance;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant OfflinePolylinePainter oldDelegate) {
    return oldDelegate.coordinates != coordinates || oldDelegate.travelMode != travelMode;
  }
}
