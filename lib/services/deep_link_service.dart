import 'package:flutter/material.dart';
import 'package:hidely_new/main.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/data/official_posts.dart';

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

    // Search official places first for instant offline preview matching
    Map<String, dynamic>? matchedOfficial;
    for (final post in officialHidelyPosts) {
      if (post['id']?.toString() == placeId || 'official_${post["id"]}' == placeId) {
        matchedOfficial = post;
        break;
      }
    }

    String title = matchedOfficial?['title'] ?? 'Hidden Place #$placeId';
    String location = matchedOfficial?['location'] ?? 'Destination Location';
    String image = matchedOfficial?['image_url'] ?? 'assets/images/explore_1.png';
    String category = matchedOfficial?['category_name'] ?? 'Attractions';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailScreen(
          title: title,
          location: location,
          image: image,
          category: category,
        ),
      ),
    );
  }
}
