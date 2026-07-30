import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';

part 'nearby_place.g.dart';

@collection
class NearbyPlace {
  Id isarId;

  @Index(unique: true, replace: true)
  String serverId;

  String name;
  String description;
  String category; // 'attraction', 'restaurant', 'hotel', etc.

  @Index()
  double latitude;

  @Index()
  double longitude;

  double rating;
  String distanceText;
  String imageUrl;
  String slug;
  int distanceM;
  double score;

  NearbyPlace({
    this.isarId = Isar.autoIncrement,
    String id = '',
    this.name = '',
    this.description = '',
    this.category = '',
    LatLng? location,
    double latitude = 0.0,
    double longitude = 0.0,
    this.rating = 0.0,
    String distance = '',
    String imageAsset = '',
    String serverId = '',
    String distanceText = '',
    String imageUrl = '',
    String slug = '',
    this.distanceM = 0,
    this.score = 0.0,
  })  : serverId = serverId.isNotEmpty ? serverId : id,
        latitude = location != null ? location.latitude : latitude,
        longitude = location != null ? location.longitude : longitude,
        distanceText = distanceText.isNotEmpty ? distanceText : distance,
        imageUrl = imageUrl.isNotEmpty ? imageUrl : imageAsset,
        slug = slug.isNotEmpty ? slug : description;

  // Factory constructor with robust null safety and parsing
  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'attraction';
    final idVal = json['id'];
    final serverId = "${type}_$idVal";

    return NearbyPlace(
      serverId: serverId,
      name: json['name'] as String? ?? '',
      description: json['slug'] as String? ?? '',
      category: type,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distanceText: json['distance_text'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Getters for namespace/backward compatibility
  String get id => serverId;
  String get type => category;
  // ignore: non_constant_identifier_names
  String get distance_text => distanceText;
  // ignore: non_constant_identifier_names
  String get image_url => imageUrl;

  // Backward compatibility with previous widget models
  String get distance => distanceText;
  String get imageAsset => imageUrl;
  @ignore
  LatLng get location => LatLng(latitude, longitude);
}
