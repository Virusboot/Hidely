import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> coordinates;
  final double distanceKm;
  final int durationMin;
  final int elevationGainM;
  final List<String> instructions;

  const RouteData({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMin,
    required this.elevationGainM,
    required this.instructions,
  });

  factory RouteData.empty() {
    return const RouteData(
      coordinates: [],
      distanceKm: 0.0,
      durationMin: 0,
      elevationGainM: 0,
      instructions: [],
    );
  }
}
