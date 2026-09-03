import 'package:latlong2/latlong.dart';
import 'navigation_step.dart';

class RouteOption {
  final String id;
  final String summary;
  final List<LatLng> coordinates;
  final double distanceKm;
  final int durationMin;
  final int? durationInTrafficMin;
  final List<NavigationStep> steps;
  final List<String> instructions;

  const RouteOption({
    required this.id,
    required this.summary,
    required this.coordinates,
    required this.distanceKm,
    required this.durationMin,
    this.durationInTrafficMin,
    required this.steps,
    required this.instructions,
  });

  bool get hasTrafficData => durationInTrafficMin != null && durationInTrafficMin! > 0;
  int get activeDurationMin => durationInTrafficMin ?? durationMin;
}

class RouteData {
  final List<LatLng> coordinates;
  final double distanceKm;
  final int durationMin;
  final int? durationInTrafficMin;
  final int elevationGainM;
  final List<String> instructions;
  final List<NavigationStep> steps;
  final List<RouteOption> options;
  final int selectedOptionIndex;

  const RouteData({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMin,
    this.durationInTrafficMin,
    required this.elevationGainM,
    required this.instructions,
    this.steps = const [],
    this.options = const [],
    this.selectedOptionIndex = 0,
  });

  bool get hasTrafficData => durationInTrafficMin != null && durationInTrafficMin! > 0;
  int get activeDurationMin => durationInTrafficMin ?? durationMin;

  String get formattedDuration {
    final mins = activeDurationMin;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remainingMins = mins % 60;
    if (remainingMins == 0) return '${hrs}h';
    return '${hrs}h ${remainingMins}m';
  }

  RouteOption? get activeOption {
    if (options.isNotEmpty && selectedOptionIndex < options.length) {
      return options[selectedOptionIndex];
    }
    return null;
  }

  RouteData copyWithSelectedOption(int index) {
    if (options.isEmpty || index >= options.length) return this;
    final opt = options[index];
    return RouteData(
      coordinates: opt.coordinates,
      distanceKm: opt.distanceKm,
      durationMin: opt.durationMin,
      durationInTrafficMin: opt.durationInTrafficMin,
      elevationGainM: elevationGainM,
      instructions: opt.instructions,
      steps: opt.steps,
      options: options,
      selectedOptionIndex: index,
    );
  }

  factory RouteData.empty() {
    return const RouteData(
      coordinates: [],
      distanceKm: 0.0,
      durationMin: 0,
      elevationGainM: 0,
      instructions: [],
      steps: [],
      options: [],
      selectedOptionIndex: 0,
    );
  }
}
