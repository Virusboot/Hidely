import 'package:flutter/material.dart';
import 'package:hidely_new/main.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// Generate a shareable Deep Link URL for a place
  static String generatePlaceDeepLink(String placeId) {
    return 'https://hidely.app/place/$placeId';
  }

  /// Handle incoming deep links (e.g. hidely.app/place/123, hidely://place/123, https://hidely.app/place/2001)
  bool handleDeepLink(String rawUrl) {
    if (rawUrl.trim().isEmpty) return false;
    final Uri? uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;

    debugPrint('[DeepLinkService] Handling deep link: $rawUrl (Path: ${uri.path})');

    // Match place path patterns: /place/123 or place/123
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2 && pathSegments[0].toLowerCase() == 'place') {
      final String placeId = pathSegments[1];
      _navigateToPlaceDetail(placeId);
      return true;
    }

    return false;
  }

  void _navigateToPlaceDetail(String placeId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailScreen(
          title: 'Place #$placeId',
          location: 'Location',
          image: '',
          category: 'Attractions',
        ),
      ),
    );
  }
}

