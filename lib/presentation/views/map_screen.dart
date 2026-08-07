import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../state/map_providers.dart';
import '../../data/models/nearby_place.dart';
import '../../data/models/route_data.dart';
import '../widgets/armonia_map.dart';
import '../widgets/route_info_card.dart';
import '../widgets/map_sizes.dart';
import '../widgets/map_header_bar.dart';

class AppColors {
  static const Color primaryPurple = Color(0xff2B1564);
  static const Color textGray = Color(0xFF6B657D);
}

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => AppLocalizations();

  String get offlineMapPackDownloaded => 'Offline map downloaded successfully!';
  String failedToDownloadOfflineMap(String e) => 'Failed to download offline map: $e';
  String get offlineMapPackDeleted => 'Offline map deleted successfully!';
  String failedToDeleteOfflineMap(String e) => 'Failed to delete offline map: $e';
  String get offlineMapPack => 'Offline Map Pack';
  String get offlineMapPackDescription => 'Offline map data for navigation without internet.';
  String get close => 'Close';
  String get deleteMapPack => 'Delete Map';
  String get destinationReached => 'Destination Reached!';
  String get arrivedSafeMessage => 'You have arrived safely at your destination.';
  String get connectionRequired => 'Connection Required';
  String get connectToDownloadMapMessage => 'Please connect to the internet to download the map.';
  String get ok => 'OK';
  String get internetLostOfflineMapUnavailable => 'Internet connection lost. Offline map is unavailable.';
  String get offlineMapUnavailable => 'Offline Map Unavailable';
  String get offlineMapUnavailableMessage => 'The offline map is currently unavailable.';
  String get searchPlaceholder => 'Search wonders...';
  String get voiceComingSoon => 'Voice search coming soon';
  String get walking => 'Walking';
  String get driving => 'Driving';
  String get transit => 'Transit';
  String get biking => 'Biking';
  String get all => 'All';
  String get restaurants => 'Restaurants';
  String get monuments => 'Monuments';
  String get museums => 'Museums';
}

class MapScreen extends ConsumerStatefulWidget {
  final bool showNearbyOnly;
  final bool isPushed;
  final String? initialSearchQuery;
  final bool startNavigationDirectly;

  const MapScreen({
    super.key,
    this.showNearbyOnly = false,
    this.isPushed = false,
    this.initialSearchQuery,
    this.startNavigationDirectly = false,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  Timer? _navigationTimer;
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isMapDownloaded = false;
  bool _isDownloadingMap = false;
  bool _isSelectingSuggestion = false;
  bool _isBottomSheetOpen = false;

  // Voice Search variables
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final Set<String> _dismissedAlerts = {};
  bool _isNavPanelCollapsed = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final navStatus = ref.read(navigationStatusProvider);
      if (navStatus == NavigationStatus.navigating) {
        debugPrint('[MapScreen] App unlocked/resumed - Navigating session seamlessly continuing...');
      }
    }
  }

  Future<void> _speakInstruction(String text) async {
    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '');
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.speak(cleanText);
  }

  void _stopSpeaking() async {
    await _flutterTts.stop();
  }

  // Core Brand Colors extracted for easy modification
  static const Color _primaryDark = AppColors.primaryPurple;

  void _handleInitialSearchQuery(String query, bool startNav) {
    _isSelectingSuggestion = true;
    _searchController.text = query;
    ref.read(mapRepositoryProvider).geocodeAddress(query).then((coords) {
      if (coords != null && mounted) {
        _dismissedAlerts.clear();
        ref.read(mapCenterProvider.notifier).state = coords;
        
        final destPlace = NearbyPlace(
          id: 'initial_target_${DateTime.now().millisecondsSinceEpoch}',
          name: query,
          description: 'Selected Destination',
          category: 'attraction',
          latitude: coords.latitude,
          longitude: coords.longitude,
          rating: 4.5,
          distanceText: '',
          distanceM: 0,
        );

        ref.read(activeDestinationProvider.notifier).state = destPlace;
        
        if (startNav) {
          ref.read(navigationStatusProvider.notifier).state = NavigationStatus.ready;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkMapDownloadStatus();
    _initSpeech();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showNearbyOnly) {
        ref.read(activeCategoryProvider.notifier).state = 'Hidden Places';
      }
      if (!widget.isPushed) {
        ref.read(activeDestinationProvider.notifier).state = null;
        ref.read(navigationStatusProvider.notifier).state = NavigationStatus.idle;
        ref.read(navigationIndexProvider.notifier).state = 0;
        ref.read(simulatedLocationProvider.notifier).state = null;
      }
      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
        _handleInitialSearchQuery(widget.initialSearchQuery!, widget.startNavigationDirectly);
      }
    });

    _searchController.addListener(() {
      if (_isSelectingSuggestion) {
        _isSelectingSuggestion = false;
        return;
      }
      if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(searchQueryProvider.notifier).state = _searchController.text;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkMapDownloadStatus();
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty &&
        widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      _handleInitialSearchQuery(widget.initialSearchQuery!, widget.startNavigationDirectly);
    }
  }

  Future<void> _checkMapDownloadStatus() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/offline_map/style.json');
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _isMapDownloaded = exists;
        });
      }
    } catch (e) {
      debugPrint('Error checking map download status: $e');
    }
  }

  int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * pow(2, zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    return ((1.0 - log(tan(lat * pi / 180.0) + 1.0 / cos(lat * pi / 180.0)) / pi) / 2.0 * pow(2, zoom)).floor();
  }


  Future<void> _downloadOfflineMap() async {
    if (mounted) {
      setState(() {
        _isDownloadingMap = true;
      });
    }

    try {
      debugPrint("========");
      debugPrint("📥 OFFLINE MAP DOWNLOAD STARTED");
      debugPrint("==================================================");

      // 1. GET DYNAMIC USER LOCATION FROM RIVERPOD
      final currentLocation = ref.read(userLocationProvider);
      final double currentLat = currentLocation.latitude;
      final double currentLng = currentLocation.longitude;

      debugPrint("[Download] Fetching tiles around Lat: $currentLat, Lng: $currentLng");

      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory('${directory.path}/offline_map');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 2. Download the actual map tiles to local storage
      final client = http.Client();
      try {
        final zoomLevels = [13, 14, 15];
        final List<Map<String, int>> tilesToDownload = [];

        for (final z in zoomLevels) {
          // Use dynamic coordinates to calculate center tile
          final centerX = _lonToTileX(currentLng, z);
          final centerY = _latToTileY(currentLat, z);

          // Download a 5x5 grid around the user's current tile (approx 6km x 6km area)
          for (int x = centerX - 2; x <= centerX + 2; x++) {
            for (int y = centerY - 2; y <= centerY + 2; y++) {
              tilesToDownload.add({'z': z, 'x': x, 'y': y});
            }
          }
        }

        final totalTiles = tilesToDownload.length;
        int completedTiles = 0;
        int nextProgressMilestone = 20;

        const batchSize = 5;
        for (int i = 0; i < totalTiles; i += batchSize) {
          final batch = tilesToDownload.sublist(i, min(i + batchSize, totalTiles));
          await Future.wait(batch.map((tile) async {
            final z = tile['z']!;
            final x = tile['x']!;
            final y = tile['y']!;
            final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
            final filePath = '${dir.path}/tiles/$z/$x/$y.png';
            final file = File(filePath);

            if (!await file.exists()) {
              try {
                final response = await client.get(
                  Uri.parse(url),
                  headers: {'User-Agent': 'com.codeflies.odysai'},
                );
                if (response.statusCode == 200) {
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(response.bodyBytes);
                }
              } catch (e) {
                debugPrint('Failed to download tile $z/$x/$y: $e');
              }
            }
          }));

          completedTiles += batch.length;
          final percentage = (completedTiles * 100) ~/ totalTiles;
          while (percentage >= nextProgressMilestone && nextProgressMilestone <= 100) {
            debugPrint("[Download] Progress: $nextProgressMilestone%...");
            nextProgressMilestone += 20;
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }
      } finally {
        client.close();
      }

      // 3. GENERATE DYNAMIC STYLE.JSON POINTING TO LOCAL TILES
      // We instruct MapLibre to use a 'raster' source pointing to our local directory URI
      final file = File('${dir.path}/style.json');

      final basicStyle = '''{
  "version": 8,
  "name": "Odys AI Offline Style",
  "sources": {
    "offline_tiles": {
      "type": "raster",
      "tiles": [
        "file://${dir.path}/tiles/{z}/{x}/{y}.png"
      ],
      "tileSize": 256,
      "minzoom": 13,
      "maxzoom": 15
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#ECE6F0"
      }
    },
    {
      "id": "offline_tiles_layer",
      "type": "raster",
      "source": "offline_tiles"
    }
  ]
}''';

      await file.writeAsString(basicStyle);

      debugPrint("[Download] Wrote dynamic style JSON file successfully!");
      debugPrint("[Download] File location: ${file.path}");
      debugPrint("==================================================");
      debugPrint("✅ OFFLINE MAP DOWNLOAD COMPLETED SUCCESSFULLY");
      debugPrint("==================================================");

      if (!mounted) return;
      setState(() {
        _isMapDownloaded = true;
        _isDownloadingMap = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.offlineMapPackDownloaded),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloadingMap = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToDownloadOfflineMap(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteOfflineMap() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/offline_map/style.json');
      if (await file.exists()) {
        await file.delete();
      }
      final tilesDir = Directory('${directory.path}/offline_map/tiles');
      if (await tilesDir.exists()) {
        await tilesDir.delete(recursive: true);
      }
      if (!mounted) return;
      setState(() {
        _isMapDownloaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.offlineMapPackDeleted),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToDeleteOfflineMap(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfflineMapOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context)!.offlineMapPack,
            style: const TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalizations.of(context)!.offlineMapPackDescription,
            style: const TextStyle(fontFamily: 'PublicSans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close, style: const TextStyle(color: AppColors.primaryPurple)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteOfflineMap();
              },
              child: Text(AppLocalizations.of(context)!.deleteMapPack, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (val) => debugPrint('onSpeechError: $val'),
      onStatus: (val) {
        debugPrint('onSpeechStatus: $val');
        if (val == 'notListening' || val == 'done') {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    // Request microphone permission dynamically
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!_speechEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }
    
    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _searchController.text = result.recognizedWords;
          });
          // Only search if final result is acquired
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            // Trigger the search logic
            _searchController.text = result.recognizedWords;
            _isSelectingSuggestion = true;
            ref.read(searchQueryProvider.notifier).state = result.recognizedWords;
            _isSelectingSuggestion = false;
            
            // Auto-submit search after voice recognition
            Future.delayed(const Duration(milliseconds: 500), () {
              // The submit logic from _buildSearchBar
              final query = result.recognizedWords;
              if (query.trim().isNotEmpty) {
                _performSearch(query);
              }
            });
          }
        }
      },
    );
    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _performSearch(String query) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Searching for "$query"...'),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      final repo = ref.read(mapRepositoryProvider);
      final coords = await repo.geocodeAddress(query);
      if (coords != null) {
        _dismissedAlerts.clear();
        ref.read(mapCenterProvider.notifier).state = coords;
        ref.read(searchQueryProvider.notifier).state = query;
        ref.read(activeDestinationProvider.notifier).state = NearbyPlace(
          id: 'searched_${DateTime.now().millisecondsSinceEpoch}',
          name: query,
          description: 'Searched location',
          category: 'attraction',
          location: coords,
        );
        _stopNavigation();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location not found. Try another city.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }
  }

  void _clearNavigationCache() {
    ref.read(mapRepositoryProvider).clearCache();
    ref.read(originalRouteCoordinatesProvider.notifier).state = [];
    debugPrint('[MapScreen] Navigation cache cleared successfully.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _stopSpeaking();
    super.dispose();
  }

  void _startNavigation() {
    final routeAsync = ref.read(routeDataProvider);
    final route = routeAsync.valueOrNull;
    if (route == null || route.coordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start navigation: route is loading or empty.')),
      );
      return;
    }

    ref.read(navigationStatusProvider.notifier).state = NavigationStatus.navigating;
    ref.read(navigationIndexProvider.notifier).state = 0;

    _navigationTimer?.cancel();
    ref.read(simulatedLocationProvider.notifier).state = null; // Set to null to use real user location

    final userLoc = ref.read(userLocationProvider);
    ref.read(mapCenterProvider.notifier).state = userLoc;
  }

  void _stopNavigation() {
    _navigationTimer?.cancel();
    _stopSpeaking();
    ref.read(navigationStatusProvider.notifier).state = NavigationStatus.idle;
    ref.read(navigationIndexProvider.notifier).state = 0;
    ref.read(simulatedLocationProvider.notifier).state = null;
  }

  void _showReachedDestinationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: const Color(0xFFF7F5FC),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9DDFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryPurple,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.destinationReached,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1B20),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.arrivedSafeMessage,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    color: Color(0xFF49454F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _clearNavigationCache();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.close,
                      style: const TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI Builders ---

  Widget _buildAlertsBanner(List<MapAlert> alerts) {
    final visibleAlerts = alerts.where((alert) => !_dismissedAlerts.contains(alert.title)).toList();
    if (visibleAlerts.isEmpty) return const SizedBox.shrink();

    // Show ONLY ONE notification banner at a time so screen isn't flooded
    final alert = visibleAlerts.first;

    return Padding(
      padding: EdgeInsets.only(top: context.h(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            margin: EdgeInsets.only(bottom: context.h(6)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: alert.color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: alert.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    alert.icon,
                                    color: alert.color,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontFamily: 'PublicSans',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: alert.color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      alert.message,
                                      style: const TextStyle(
                                        fontFamily: 'PublicSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF3C3C43),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Close/Dismiss Button
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _dismissedAlerts.add(alert.title);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.black.withOpacity(0.4),
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (alert.actionLabel != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                _downloadOfflineMap();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: alert.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  alert.actionLabel!,
                                  style: const TextStyle(
                                    fontFamily: 'PublicSans',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions(List<Map<String, String>> predictions) {
    if (predictions.isEmpty) {
      return Container(
        margin: EdgeInsets.only(top: context.h(8)),
        padding: EdgeInsets.symmetric(vertical: context.h(16), horizontal: context.w(16)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No cities or places found',
            style: TextStyle(
              fontFamily: 'PublicSans',
              color: Color(0xFF6B657D),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: context.h(8)),
      constraints: BoxConstraints(maxHeight: context.h(280)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: context.h(8)),
          itemCount: predictions.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2D6F8)),
          itemBuilder: (context, index) {
            final pred = predictions[index];
            final description = pred['description'] ?? '';

            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xffECE6F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_city_rounded, color: _primaryDark, size: 18),
              ),
              title: Text(
                description,
                style: const TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _primaryDark,
                ),
              ),
              onTap: () async {
                final placeId = pred['place_id'] ?? '';
                
                setState(() {
                  _isSelectingSuggestion = true;
                  _searchController.text = description;
                  _dismissedAlerts.clear();
                });
                ref.read(searchQueryProvider.notifier).state = '';
                FocusScope.of(context).unfocus();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Loading places in $description...'),
                    duration: const Duration(seconds: 2),
                  ),
                );

                final repo = ref.read(mapRepositoryProvider);
                LatLng? coords;
                if (placeId.isNotEmpty) {
                  coords = await repo.getLatLngFromPlaceId(placeId);
                }
                coords ??= await repo.geocodeAddress(description);

                if (coords != null) {
                  ref.read(mapCenterProvider.notifier).state = coords;
                  ref.read(activeDestinationProvider.notifier).state = NearbyPlace(
                    id: 'searched_${DateTime.now().millisecondsSinceEpoch}',
                    name: description,
                    description: 'Searched location',
                    category: 'attraction',
                    location: coords,
                  );
                  _stopNavigation();
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not load location coordinates.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return MapHeaderBar(
      searchController: _searchController,
      isListening: _isListening,
      searchPlaceholder: l10n.searchPlaceholder,
      isPushed: widget.isPushed,
      onBackPressed: () => Navigator.maybePop(context),
      onSearchSubmitted: (val) => _performSearch(val),
      onVoicePressed: () {
        if (_isListening) {
          _stopListening();
        } else {
          _startListening();
        }
      },
    );
  }

  Widget _buildTravelModeRow(String currentMode, AppLocalizations l10n) {
    final modes = [
      {'id': 'walking', 'label': l10n.walking, 'icon': Icons.directions_walk_rounded},
      {'id': 'bicycling', 'label': l10n.biking, 'icon': Icons.directions_bike_rounded},
      {'id': 'driving', 'label': l10n.driving, 'icon': Icons.directions_car_rounded},
      {'id': 'transit', 'label': l10n.transit, 'icon': Icons.directions_transit_rounded},
    ];

    final int selectedIndex = modes.indexWhere((m) => m['id'] == currentMode).clamp(0, 3);
    final double alignX = -1.0 + (selectedIndex * (2.0 / 3.0));

    return Container(
      height: context.h(40),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xffEEEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 1. Sliding Pill Indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment(alignX, 0.0),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 2. Interactive Mode Items Overlay
          Row(
            children: modes.map((mode) {
              final isSelected = currentMode == mode['id'];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref.read(travelModeProvider.notifier).state = mode['id'] as String;
                    _stopNavigation();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mode['icon'] as IconData,
                          color: isSelected ? _primaryDark : Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mode['label'] as String,
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            color: isSelected ? Colors.black : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterSheet(AppLocalizations l10n) {
    final categories = [
      {'key': 'All', 'label': l10n.all, 'icon': Icons.explore_outlined, 'color': _primaryDark},
      {'key': 'Hidden Places', 'label': 'Hidden Places', 'icon': Icons.location_on_outlined, 'color': _primaryDark},
      {'key': 'Restaurant', 'label': l10n.restaurants, 'icon': Icons.restaurant_outlined, 'color': _primaryDark},
      {'key': 'Stay', 'label': 'Stays', 'icon': Icons.hotel_outlined, 'color': _primaryDark},
      {'key': 'Most Popular', 'label': 'Most Popular', 'icon': Icons.local_fire_department_rounded, 'color': _primaryDark},
    ];

    setState(() {
      _isBottomSheetOpen = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentCategory = ref.read(activeCategoryProvider);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Filter by Category',
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff1A1235),
                        ),
                      ),
                      const Spacer(),
                      if (currentCategory.toLowerCase() != 'all')
                        GestureDetector(
                          onTap: () {
                            ref.read(activeCategoryProvider.notifier).state = 'All';
                            ref.read(showHeatmapProvider.notifier).state = false;
                            setSheetState(() {});
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xffF5F3FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontFamily: 'PublicSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primaryDark,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...categories.map((cat) {
                    final key = cat['key'] as String;
                    final label = cat['label'] as String;
                    final icon = cat['icon'] as IconData;
                    final accentColor = cat['color'] as Color;
                    final isSelected = currentCategory.toLowerCase() == key.toLowerCase();
                    final isMostPopular = key == 'Most Popular';

                    return GestureDetector(
                      onTap: () {
                        ref.read(activeCategoryProvider.notifier).state = key;
                        ref.read(showHeatmapProvider.notifier).state = isMostPopular;
                        setSheetState(() {});
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(bottom: isMostPopular ? 0 : 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor : const Color(0xffF5F3FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? accentColor : const Color(0xffE8E3F5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : accentColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                icon,
                                size: 18,
                                color: isSelected ? Colors.white : accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'PublicSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xff1A1235),
                                  ),
                                ),
                                if (isMostPopular)
                                  Text(
                                    'Shows heatmap of trending spots',
                                    style: TextStyle(
                                      fontFamily: 'PublicSans',
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.8)
                                          : const Color(0xff8E8AA0),
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    });
  }

  Widget _buildFilterFAB(AppLocalizations l10n) {
    if (_isBottomSheetOpen) return const SizedBox.shrink();
    final activeCategory = ref.watch(activeCategoryProvider);
    final hasActiveFilter = activeCategory.toLowerCase() != 'all';

    return GestureDetector(
      onTap: () => _showCategoryFilterSheet(l10n),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: hasActiveFilter ? _primaryDark : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: hasActiveFilter ? Colors.white : _primaryDark,
              size: 22,
            ),
            if (hasActiveFilter)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xffFF3B30), // iOS System Red
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchCarNavigation(LatLng dest) async {
    final lat = dest.latitude;
    final lng = dest.longitude;

    final googleMapsUri = Uri.parse('google.navigation:q=$lat,$lng');
    final appleMapsUri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (Platform.isAndroid) {
        if (await canLaunchUrl(googleMapsUri)) {
          await launchUrl(googleMapsUri);
          return;
        }
      } else if (Platform.isIOS) {
        if (await canLaunchUrl(appleMapsUri)) {
          await launchUrl(appleMapsUri);
          return;
        }
      }

      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch navigation.';
      }
    } catch (e) {
      debugPrint('Error launching car navigation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open external navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMapLayersSheet() {
    final engine = ref.read(mapEngineProvider);
    final mapType = ref.read(googleMapTypeProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Map Type & Layers',
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1C0D5A),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLayerOptionItem(
                    icon: Icons.map_outlined,
                    label: 'Default',
                    isSelected: engine == MapEngine.googleMaps && mapType == 'normal',
                    onTap: () {
                      ref.read(mapEngineProvider.notifier).state = MapEngine.googleMaps;
                      ref.read(googleMapTypeProvider.notifier).state = 'normal';
                      Navigator.pop(context);
                    },
                  ),
                  _buildLayerOptionItem(
                    icon: Icons.satellite_outlined,
                    label: 'Satellite',
                    isSelected: engine == MapEngine.googleMaps && mapType == 'satellite',
                    onTap: () {
                      ref.read(mapEngineProvider.notifier).state = MapEngine.googleMaps;
                      ref.read(googleMapTypeProvider.notifier).state = 'satellite';
                      Navigator.pop(context);
                    },
                  ),
                  _buildLayerOptionItem(
                    icon: Icons.wifi_off_rounded,
                    label: 'Offline Map',
                    isSelected: engine == MapEngine.openStreetMap,
                    onTap: () {
                      ref.read(mapEngineProvider.notifier).state = MapEngine.openStreetMap;
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayerOptionItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xff2B1564) : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xff2B1564) : const Color(0xffCBD5E1),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xff1C0D5A),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xff2B1564) : const Color(0xff475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapEngineToggle() {
    return GestureDetector(
      onTap: _showMapLayersSheet,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.layers_rounded,
            color: _primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadMapButton(bool isOnline) {
    return GestureDetector(
      onTap: () {
        if (_isMapDownloaded) {
          _showOfflineMapOptions();
        } else {
          if (isOnline) {
            _downloadOfflineMap();
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(AppLocalizations.of(context)!.connectionRequired),
                content: Text(AppLocalizations.of(context)!.connectToDownloadMapMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.ok, style: const TextStyle(color: AppColors.primaryPurple)),
                  ),
                ],
              ),
            );
          }
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: _isDownloadingMap
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryDark),
                  ),
                )
              : Icon(
                  _isMapDownloaded ? Icons.cloud_done_rounded : Icons.cloud_download_rounded,
                  color: _primaryDark,
                  size: 22,
                ),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: () {
        ref.read(isTrackingUserProvider.notifier).state = true;
        ref.read(recenterTriggerProvider.notifier).state++;
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.gps_fixed_rounded,
            color: _primaryDark,
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOnline = ref.watch(isOnlineProvider);

    // Auto-switch to offline map if there is no internet connection
    if (!isOnline && ref.read(mapEngineProvider) != MapEngine.openStreetMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(mapEngineProvider) != MapEngine.openStreetMap && mounted) {
          ref.read(mapEngineProvider.notifier).state = MapEngine.openStreetMap;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: Automatically switched to Offline Map.'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }

    final center = ref.watch(mapCenterProvider);
    final activeDestination = ref.watch(activeDestinationProvider);
    final travelMode = ref.watch(travelModeProvider);
    final placesAsync = ref.watch(nearbyPlacesProvider);
    final routeAsync = ref.watch(routeDataProvider);
    final route = routeAsync.valueOrNull;

    final navStatus = ref.watch(navigationStatusProvider);
    final userLoc = ref.watch(userLocationProvider);

    RouteData? displayRouteData;
    if (route != null) {
      if (navStatus == NavigationStatus.navigating) {
        int closestIndex = 0;
        double minDistance = double.infinity;
        for (int i = 0; i < route.coordinates.length; i++) {
          final dist = Geolocator.distanceBetween(
            userLoc.latitude,
            userLoc.longitude,
            route.coordinates[i].latitude,
            route.coordinates[i].longitude,
          );
          if (dist < minDistance) {
            minDistance = dist;
            closestIndex = i;
          }
        }

        double sumMeters = Geolocator.distanceBetween(
          userLoc.latitude,
          userLoc.longitude,
          route.coordinates[closestIndex].latitude,
          route.coordinates[closestIndex].longitude,
        );
        for (int i = closestIndex; i < route.coordinates.length - 1; i++) {
          sumMeters += Geolocator.distanceBetween(
            route.coordinates[i].latitude,
            route.coordinates[i].longitude,
            route.coordinates[i + 1].latitude,
            route.coordinates[i + 1].longitude,
          );
        }

        final double remainingDistanceKm = double.parse((sumMeters / 1000.0).toStringAsFixed(1));
        int remainingDurationMin = route.durationMin;
        if (route.distanceKm > 0) {
          final double ratio = remainingDistanceKm / route.distanceKm;
          remainingDurationMin = (route.durationMin * ratio).round().clamp(1, route.durationMin);
        }

        displayRouteData = RouteData(
          coordinates: route.coordinates,
          distanceKm: remainingDistanceKm,
          durationMin: remainingDurationMin,
          elevationGainM: route.elevationGainM,
          instructions: route.instructions,
        );
      } else {
        displayRouteData = route;
      }
    }

    final activeInstructionIndex = ref.watch(navigationIndexProvider);
    final simulatedLoc = ref.watch(simulatedLocationProvider);
    final alerts = ref.watch(navigationAlertsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isSearching = searchQuery.trim().isNotEmpty && ref.watch(activeDestinationProvider) == null;
    final bool isSearchFocused = _searchFocusNode.hasFocus;

    ref.listen<int>(navigationIndexProvider, (previous, next) {
      final isVoiceEnabled = ref.read(voiceEnabledProvider);
      if (isVoiceEnabled) {
        final routeAsync = ref.read(routeDataProvider);
        final route = routeAsync.valueOrNull;
        if (route != null && next >= 0 && next < route.instructions.length) {
          final instruction = route.instructions[next];
          _speakInstruction(instruction);
        }
      }
    });

    ref.listen<LatLng>(userLocationProvider, (previous, next) {
      final currentNavStatus = ref.read(navigationStatusProvider);
      if (currentNavStatus == NavigationStatus.navigating) {
        // 1. Follow user's real-time position on map
        ref.read(mapCenterProvider.notifier).state = next;

        // 2. Check if reached destination
        final dest = ref.read(activeDestinationProvider);
        if (dest != null) {
          final distance = Geolocator.distanceBetween(
            next.latitude,
            next.longitude,
            dest.location.latitude,
            dest.location.longitude,
          );
          if (distance < 15) {
            _stopNavigation();
            _showReachedDestinationDialog();
            return;
          }
        }

        // 3. Dynamically update instruction index based on proximity to route coordinates
        final routeAsync = ref.read(routeDataProvider);
        final route = routeAsync.valueOrNull;
        if (route != null && route.coordinates.isNotEmpty) {
          final totalCoords = route.coordinates.length;
          final totalInstructions = route.instructions.isNotEmpty ? route.instructions.length : 1;

          int closestIndex = 0;
          double minDistance = double.infinity;
          for (int i = 0; i < totalCoords; i++) {
            final dist = Geolocator.distanceBetween(
              next.latitude,
              next.longitude,
              route.coordinates[i].latitude,
              route.coordinates[i].longitude,
            );
            if (dist < minDistance) {
              minDistance = dist;
              closestIndex = i;
            }
          }

          // If user deviates too far from the calculated road route, trigger auto-rerouting
          if (minDistance > 65.0) {
            debugPrint('[Reroute] User went off-route (distance: $minDistance m). Recalculating route...');
            ref.invalidate(routeDataProvider);
          } else {
            int instructionIndex = ((closestIndex / totalCoords) * totalInstructions).floor().clamp(0, totalInstructions - 1);
            ref.read(navigationIndexProvider.notifier).state = instructionIndex;
          }
        }
      }
    });

    ref.listen<AsyncValue<RouteData?>>(routeDataProvider, (previous, next) {
      next.whenData((route) {
        if (route != null &&
            route.coordinates.isNotEmpty &&
            ref.read(navigationStatusProvider) == NavigationStatus.ready &&
            widget.startNavigationDirectly) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startNavigation();
            }
          });
        }
      });
    });

    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == true && next == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Internet connection lost. Running in offline/cached mode."),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final double topOffset = context.topPadding + (widget.isPushed ? 50 : 0) + context.h(10);
    final double extraBottomPadding = widget.isPushed ? 0 : 86;

    final mapContent = Stack(
      children: [
        // 1. Map Backdrop
        Positioned.fill(
          child: ArmoniaMap(
            center: center,
            places: placesAsync.valueOrNull ?? [],
            activeDestination: activeDestination,
            activeRoute: routeAsync.valueOrNull,
            simulatedLocation: simulatedLoc,
            onSelectPlace: (place) {
              ref.read(activeDestinationProvider.notifier).state = place;
              _stopNavigation();
            },
          ),
        ),

        // 2. Top Header Overlay
        Positioned(
          top: topOffset,
          left: context.w(16),
          right: context.w(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSearchBar(l10n),
              SizedBox(height: context.h(12)),

              _buildTravelModeRow(travelMode, l10n),
              SizedBox(height: context.h(8)),
              _buildAlertsBanner(alerts),
              if (searchQuery.trim().isNotEmpty && ref.watch(activeDestinationProvider) == null)
                ref.watch(autocompletePredictionsProvider(searchQuery)).when(
                  data: (predictions) => _buildSearchSuggestions(predictions),
                  loading: () => Container(
                    margin: EdgeInsets.only(top: context.h(8)),
                    padding: EdgeInsets.symmetric(vertical: context.h(20)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Searching...",
                        style: TextStyle(
                          color: _primaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),

        // 3. Bottom Panel Overlay
        if (!isKeyboardOpen && !isSearchFocused)
          Positioned(
            left: 0,
            right: 0,
          bottom: context.bottomPadding + context.h(10) + extraBottomPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeDestination != null && displayRouteData != null) ...[  
                // Collapse/Expand toggle pill — shown only during active navigation
                if (navStatus == NavigationStatus.navigating)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.h(8)),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isNavPanelCollapsed = !_isNavPanelCollapsed;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          padding: EdgeInsets.symmetric(horizontal: context.w(20), vertical: context.h(6)),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedRotation(
                                turns: _isNavPanelCollapsed ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF2B1564),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: context.w(6)),
                              Text(
                                _isNavPanelCollapsed ? 'Show Panel' : 'Hide Panel',
                                style: const TextStyle(
                                  color: Color(0xFF2B1564),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // The main RouteInfoCard — hidden when collapsed
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: _isNavPanelCollapsed
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.w(18)),
                          child: RouteInfoCard(
                            routeData: displayRouteData,
                            navStatus: navStatus,
                            activeInstructionIndex: activeInstructionIndex,
                            destinationName: activeDestination.name,
                            destinationCategory: activeDestination.category,
                            isVoiceEnabled: ref.watch(voiceEnabledProvider),
                            onVoiceToggle: () {
                              final val = ref.read(voiceEnabledProvider);
                              ref.read(voiceEnabledProvider.notifier).state = !val;
                              if (!val == false) {
                                _stopSpeaking();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(!val ? "Voice guidance enabled" : "Voice guidance muted"),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            onStartRoute: () {
                              if (navStatus == NavigationStatus.navigating) {
                                _stopNavigation();
                              } else {
                                _startNavigation();
                              }
                            },
                            onCancel: () {
                              _stopNavigation();
                              ref.read(activeDestinationProvider.notifier).state = null;
                              _clearNavigationCache();
                              setState(() => _isNavPanelCollapsed = false);
                            },
                            onOpenInCar: () {
                              _launchCarNavigation(activeDestination.location);
                            },
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),

        // 4. Floating Action Buttons Column (Apple style)
        if (!_isBottomSheetOpen && !isKeyboardOpen && !isSearchFocused && !isSearching && navStatus != NavigationStatus.navigating && !(activeDestination != null && displayRouteData != null))
          Positioned(
            right: context.w(16),
            bottom: (activeDestination != null && displayRouteData != null
                    ? context.h(280)
                    : context.h(30)) +
                context.bottomPadding +
                extraBottomPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIntelligenceFAB(),
                SizedBox(height: context.h(10)),
                _buildFilterFAB(l10n),
                SizedBox(height: context.h(10)),
                _buildMapEngineToggle(),
                SizedBox(height: context.h(10)),
                _buildDownloadMapButton(isOnline),
                if (!ref.watch(isTrackingUserProvider)) ...[
                  SizedBox(height: context.h(10)),
                  _buildRecenterButton(),
                ],
              ],
            ),
          ),
        if (!_isBottomSheetOpen && !isKeyboardOpen && !isSearchFocused && !isSearching && navStatus == NavigationStatus.navigating && _isNavPanelCollapsed)
          Positioned(
            right: context.w(16),
            bottom: (_isNavPanelCollapsed
                ? context.h(60) + context.bottomPadding
                : context.h(240) + context.bottomPadding) + extraBottomPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIntelligenceFAB(),
                SizedBox(height: context.h(10)),
                _buildFilterFAB(l10n),
                SizedBox(height: context.h(10)),
                _buildMapEngineToggle(),
                SizedBox(height: context.h(10)),
                _buildDownloadMapButton(isOnline),
                if (!ref.watch(isTrackingUserProvider)) ...[
                  SizedBox(height: context.h(10)),
                  _buildRecenterButton(),
                ],
              ],
            ),
          ),
      ],
    );

    final offlineMapPlaceholder = Container(
      color: const Color(0xFFECE6F0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                color: AppColors.primaryPurple.withOpacity(0.4),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.offlineMapUnavailable,
                style: const TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D1B20),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.offlineMapUnavailableMessage,
                style: const TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 13,
                  color: Color(0xFF49454F),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    final showOfflinePlaceholder = !isOnline && ref.watch(mapEngineProvider) == MapEngine.openStreetMap && !_isMapDownloaded;
    final bodyWidget = showOfflinePlaceholder ? offlineMapPlaceholder : mapContent;

    if (widget.isPushed) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _primaryDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: bodyWidget,
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: bodyWidget,
    );
  }

  Widget _buildIntelligenceFAB() {
    final activeDest = ref.watch(activeDestinationProvider);

    return GestureDetector(
      onTap: () {
        final dest = activeDest ?? NearbyPlace(
          id: 'current_area',
          name: 'Current Travel Area',
          description: 'Live Tourist Intelligence Brief',
          category: 'Attraction',
          latitude: ref.read(userLocationProvider).latitude,
          longitude: ref.read(userLocationProvider).longitude,
          rating: 4.8,
          distanceText: '',
          distanceM: 0,
        );
        _showLocationIntelligenceDialog(dest);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff2B1564), // Deep Brand Purple
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xff2B1564).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.info_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligenceChip({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 11,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 12,
              color: Color(0xff1C0D5A),
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBriefBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1C0D5A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12,
                    color: Color(0xff6B657D),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationIntelligenceDialog(NearbyPlace destination) {
    setState(() {
      _isBottomSheetOpen = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xffE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xff2B1564).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.info_outline_rounded, color: Color(0xff2B1564), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff1C0D5A),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Live Tourist Intelligence & Travel Brief',
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff6B657D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.black54, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 1. Live Status Grid Cards
              Row(
                children: [
                  Expanded(
                    child: _buildIntelligenceChip(
                      icon: Icons.traffic_rounded,
                      color: const Color(0xff2B1564),
                      title: 'Traffic',
                      value: 'Clear Flow',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildIntelligenceChip(
                      icon: Icons.groups_rounded,
                      color: const Color(0xff2B1564),
                      title: 'Crowd',
                      value: 'Low Density',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildIntelligenceChip(
                      icon: Icons.wb_sunny_rounded,
                      color: const Color(0xff2B1564),
                      title: 'Weather',
                      value: '24°C Pleasant',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              
              // 2. Real-time Advisory Section Title
              const Text(
                'LIVE LOCATION UPDATES & ADVISORY',
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff2B1564),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),

              _buildBriefBullet(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xff2B1564),
                title: 'Best Time to Visit & Photo Spot',
                desc: 'Soft natural lighting from 4:00 PM – 6:30 PM. Great vantage point for photography.',
              ),
              _buildBriefBullet(
                icon: Icons.local_parking_rounded,
                color: const Color(0xff2B1564),
                title: 'Parking & Facilities',
                desc: 'Ample vehicle parking available near gate. Restrooms and snack stalls open.',
              ),
              _buildBriefBullet(
                icon: Icons.cell_tower_rounded,
                color: const Color(0xff2B1564),
                title: 'Mobile Signal Alert',
                desc: 'Strong signal at destination, but weak network zone 2 km before arrival.',
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Got it, thanks!',
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2B1564),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    });
  }
}
