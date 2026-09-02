import 'package:latlong2/latlong.dart';

enum ManeuverType {
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uturn,
  roundabout,
  exit,
  merge,
  fork,
  flyover,
  destination;

  static ManeuverType fromString(String? maneuver, [double? angleChange]) {
    if (maneuver != null && maneuver.isNotEmpty) {
      final m = maneuver.toLowerCase();
      if (m.contains('uturn') || m.contains('u-turn')) return ManeuverType.uturn;
      if (m.contains('roundabout') || m.contains('rotary')) return ManeuverType.roundabout;
      if (m.contains('ramp') || m.contains('exit')) return ManeuverType.exit;
      if (m.contains('fork')) return ManeuverType.fork;
      if (m.contains('merge')) return ManeuverType.merge;
      if (m.contains('flyover') || m.contains('overpass')) return ManeuverType.flyover;
      if (m.contains('sharp-left') || m.contains('sharp left')) return ManeuverType.sharpLeft;
      if (m.contains('sharp-right') || m.contains('sharp right')) return ManeuverType.sharpRight;
      if (m.contains('slight-left') || m.contains('slight left')) return ManeuverType.slightLeft;
      if (m.contains('slight-right') || m.contains('slight right')) return ManeuverType.slightRight;
      if (m.contains('left')) return ManeuverType.left;
      if (m.contains('right')) return ManeuverType.right;
      if (m.contains('straight')) return ManeuverType.straight;
    }

    if (angleChange != null) {
      final absAngle = angleChange.abs();
      if (absAngle < 20) return ManeuverType.straight;
      if (absAngle >= 20 && absAngle < 45) {
        return angleChange > 0 ? ManeuverType.slightRight : ManeuverType.slightLeft;
      }
      if (absAngle >= 45 && absAngle < 135) {
        return angleChange > 0 ? ManeuverType.right : ManeuverType.left;
      }
      if (absAngle >= 135 && absAngle < 165) {
        return angleChange > 0 ? ManeuverType.sharpRight : ManeuverType.sharpLeft;
      }
      if (absAngle >= 165) return ManeuverType.uturn;
    }

    return ManeuverType.straight;
  }
}

class NavigationStep {
  final LatLng startLocation;
  final LatLng endLocation;
  final double distanceMeters;
  final int durationSeconds;
  final ManeuverType maneuverType;
  final String instruction;
  final String roadName;
  final String? exitNumber;
  final int? roundaboutExitIndex;
  final double? initialBearing;
  final double? finalBearing;

  const NavigationStep({
    required this.startLocation,
    required this.endLocation,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.instruction,
    required this.roadName,
    this.exitNumber,
    this.roundaboutExitIndex,
    this.initialBearing,
    this.finalBearing,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000.0).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final mins = (durationSeconds / 60.0).round();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remainingMins = mins % 60;
    return '${hrs}h ${remainingMins}m';
  }
}
