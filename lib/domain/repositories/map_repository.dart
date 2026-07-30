import 'package:latlong2/latlong.dart';
import '../../data/models/nearby_place.dart';
import '../../data/models/route_data.dart';

abstract class MapRepository {
  Future<List<NearbyPlace>> getNearbyPlaces({
    String? category,
    String? query,
    double? radius,
    LatLng? userLocation,
  });
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng end,
    required String mode, // 'walking', 'driving', 'transit'
    String? language,
  });
  Future<LatLng?> geocodeAddress(String address);
  Future<List<Map<String, String>>> getAutocompletePredictions(String input);
  Future<LatLng?> getLatLngFromPlaceId(String placeId);
  Future<void> clearCache();
}
