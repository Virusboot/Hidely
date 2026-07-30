import 'package:flutter/material.dart';
import 'package:hidely_new/presentation/views/map_screen.dart';

class MapDiscoveryScreen extends StatefulWidget {
  static String? initialSearchQuery;
  static bool startNavigationDirectly = false;
  static MapDiscoveryScreenState? activeState;

  const MapDiscoveryScreen({super.key});

  @override
  State<MapDiscoveryScreen> createState() => MapDiscoveryScreenState();
}

class MapDiscoveryScreenState extends State<MapDiscoveryScreen> {
  String? _currentQuery;
  bool _startNav = false;

  @override
  void initState() {
    super.initState();
    MapDiscoveryScreen.activeState = this;
    _currentQuery = MapDiscoveryScreen.initialSearchQuery;
    _startNav = MapDiscoveryScreen.startNavigationDirectly;

    // Clear static parameters
    MapDiscoveryScreen.initialSearchQuery = null;
    MapDiscoveryScreen.startNavigationDirectly = false;
  }

  @override
  void dispose() {
    if (MapDiscoveryScreen.activeState == this) {
      MapDiscoveryScreen.activeState = null;
    }
    super.dispose();
  }

  void checkSearchQuery() {
    if (MapDiscoveryScreen.initialSearchQuery != null) {
      setState(() {
        _currentQuery = MapDiscoveryScreen.initialSearchQuery;
        _startNav = MapDiscoveryScreen.startNavigationDirectly;

        // Clear static parameters
        MapDiscoveryScreen.initialSearchQuery = null;
        MapDiscoveryScreen.startNavigationDirectly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapScreen(
      initialSearchQuery: _currentQuery,
      startNavigationDirectly: _startNav,
    );
  }
}