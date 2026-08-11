import '../data/models/nearby_place.dart';

final List<Map<String, dynamic>> officialHidelyPosts = [];

/// Helper to get official posts as NearbyPlace objects for Google Maps integration
List<NearbyPlace> getOfficialNearbyPlaces() {
  return officialHidelyPosts.map((post) {
    return NearbyPlace(
      id: 'official_${post["id"]}',
      name: post["title"],
      description: '${post["caption"]} • Uploaded by @hidely_official',
      category: post["category"],
      latitude: (post["latitude"] as num).toDouble(),
      longitude: (post["longitude"] as num).toDouble(),
      rating: 4.9,
      distanceText: 'Featured India',
      distanceM: 500,
      imageUrl: post["image_url"],
    );
  }).toList();
}

