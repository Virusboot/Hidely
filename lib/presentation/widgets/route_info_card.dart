import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/route_data.dart';
import '../state/map_providers.dart';
import 'map_sizes.dart';

class AppColors {
  static const Color primaryPurple = Color(0xff2B1564);
  static const Color textGray = Color(0xFF6B657D);
}

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => AppLocalizations();

  String get followRoute => 'Follow Route';
  String get navigationActive => 'Navigation Active';
  String get nextTurnAhead => 'Next Turn Ahead';
  String minutesUnit(String mins) => '$mins min';
  String distanceUnit(String dist) => '$dist km';
  String get arriving => 'Arriving';
  String elevation(String elev) => 'Elevation: $elev m';
  String get stopRoute => 'Stop';
  String get startRoute => 'Start';
}

class RouteInfoCard extends StatelessWidget {
  final RouteData routeData;
  final NavigationStatus navStatus;
  final int activeInstructionIndex;
  final VoidCallback onStartRoute;
  final VoidCallback onCancel;
  final bool isVoiceEnabled;
  final VoidCallback onVoiceToggle;
  final VoidCallback? onOpenInCar;
  final String? destinationName;
  final String? destinationCategory;
  final String travelMode;

  const RouteInfoCard({
    super.key,
    required this.routeData,
    required this.navStatus,
    required this.activeInstructionIndex,
    required this.onStartRoute,
    required this.onCancel,
    required this.isVoiceEnabled,
    required this.onVoiceToggle,
    this.onOpenInCar,
    this.destinationName,
    this.destinationCategory,
    this.travelMode = 'driving',
  });

  String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes min';
    final int days = totalMinutes ~/ 1440;
    final int hours = (totalMinutes % 1440) ~/ 60;
    final int minutes = totalMinutes % 60;

    if (days > 0) {
      if (hours > 0 && minutes > 0) {
        return '${days}d ${hours}h ${minutes}m';
      } else if (hours > 0) {
        return '${days}d ${hours}h';
      } else if (minutes > 0) {
        return '${days}d ${minutes}m';
      }
      return '${days}d';
    } else {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
  }

  IconData _getInstructionIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('auto') || lower.contains('rickshaw') || lower.contains('cab') || lower.contains('taxi')) {
      return Icons.local_taxi_rounded;
    } else if (lower.contains('metro') || lower.contains('subway') || lower.contains('train') || lower.contains('rail') || lower.contains('express')) {
      return Icons.directions_subway_rounded;
    } else if (lower.contains('bus') || lower.contains('isbt') || lower.contains('shuttle')) {
      return Icons.directions_bus_rounded;
    } else if (lower.contains('switch') || lower.contains('transfer') || lower.contains('interchange')) {
      return Icons.alt_route_rounded;
    } else if (lower.contains('board')) {
      return Icons.departure_board_rounded;
    } else if (lower.contains('walk') || lower.contains('foot')) {
      return Icons.directions_walk_rounded;
    } else if (lower.contains('right')) {
      return Icons.turn_right_rounded;
    } else if (lower.contains('left')) {
      return Icons.turn_left_rounded;
    } else if (lower.contains('straight') || lower.contains('continue')) {
      return Icons.straight_rounded;
    } else if (lower.contains('arrive') || lower.contains('destination') || lower.contains('de-board') || lower.contains('target')) {
      return Icons.place_rounded;
    }
    return Icons.directions_transit_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Format estimated arrival time
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: routeData.durationMin));
    final arrivalTimeString = DateFormat('hh:mm a').format(arrivalTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(context.w(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (destinationName != null && destinationName!.isNotEmpty) ...[
            Text(
              destinationName!,
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: context.w(18),
                fontWeight: FontWeight.w800,
                color: const Color(0xff1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (destinationCategory != null && destinationCategory!.isNotEmpty) ...[
              SizedBox(height: context.h(2)),
              Text(
                destinationCategory!.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: context.w(10),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff8E8AA0),
                  letterSpacing: 0.5,
                ),
              ),
            ],
            SizedBox(height: context.h(10)),
            const Divider(color: Color(0xffE2E8F0), height: 1),
            SizedBox(height: context.h(10)),
          ],
          // Row 1: Prominent ETA (Google Maps style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatDuration(routeData.durationMin),
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  color: const Color(0xff188038), // Google Maps Green
                  fontSize: context.sp(22),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '(${NumberFormat('#,##0.#').format(routeData.distanceKm)} km)',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    color: const Color(0xFF5F6368), // Google grey
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Fastest route • Arrive around $arrivalTimeString',
            style: TextStyle(
              fontFamily: 'PublicSans',
              color: const Color(0xFF5F6368),
              fontSize: context.sp(13),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          
          // Row 2: Turn-by-Turn / Transit Route Details (Scrollable List)
          if (routeData.instructions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  travelMode == 'transit' ? 'TRANSIT ROUTE DETAILS' : 'ROUTE INSTRUCTIONS',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff5D3EBC),
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${routeData.instructions.length - activeInstructionIndex} Remaining Step${(routeData.instructions.length - activeInstructionIndex) > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8AA0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: context.h(140),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: () {
                      final int activeIdx = activeInstructionIndex;
                      final List<int> visibleIndices = [];
                      double cumulativeDistance = 0.0;

                      for (int i = activeIdx; i < routeData.instructions.length; i++) {
                        final stepText = routeData.instructions[i];
                        final dist = _parseDistanceText(stepText);
                        cumulativeDistance += dist;
                        
                        // Always include at least the next 3 steps (or all remaining if less than 3)
                        if (visibleIndices.length < 3 || cumulativeDistance <= 50.0) {
                          visibleIndices.add(i);
                        } else {
                          break;
                        }
                      }

                      return visibleIndices.map((index) {
                        final stepText = routeData.instructions[index];
                        final isCurrentStep = index == activeInstructionIndex;
                        final stepIcon = _getInstructionIcon(stepText);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrentStep
                                ? const Color(0xff5D3EBC).withOpacity(0.08)
                                : const Color(0xffF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentStep
                                  ? const Color(0xff5D3EBC).withOpacity(0.4)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: context.w(28),
                                height: context.h(28),
                                decoration: BoxDecoration(
                                  color: isCurrentStep ? AppColors.primaryPurple : const Color(0xffE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    stepIcon,
                                    color: isCurrentStep ? Colors.white : const Color(0xff475569),
                                    size: context.w(15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stepText,
                                      style: TextStyle(
                                        fontFamily: 'PublicSans',
                                        color: isCurrentStep ? AppColors.primaryPurple : const Color(0xff1E293B),
                                        fontSize: context.sp(12.5),
                                        fontWeight: isCurrentStep ? FontWeight.w700 : FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (isCurrentStep && navStatus == NavigationStatus.navigating) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.navigationActive,
                                        style: TextStyle(
                                          fontFamily: 'PublicSans',
                                          color: const Color(0xff16A34A),
                                          fontSize: context.sp(10.5),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    }(),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: context.w(36),
                  height: context.h(36),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: context.w(18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.followRoute,
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      color: AppColors.primaryPurple,
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFECE6F0), height: 1, thickness: 1),
          const SizedBox(height: 14),

          // Row 3: Action Buttons
          Row(
            children: [
              // Start/Stop Route Button (Pill shape)
              Expanded(
                child: GestureDetector(
                  onTap: onStartRoute,
                  child: Container(
                    height: context.h(44),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navStatus == NavigationStatus.navigating
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: context.w(18),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          navStatus == NavigationStatus.navigating
                              ? l10n.stopRoute
                              : l10n.startRoute,
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            color: Colors.white,
                            fontSize: context.sp(13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Voice Toggle Button (Circular shape)
              GestureDetector(
                onTap: onVoiceToggle,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isVoiceEnabled ? const Color(0xFFEBE6F8) : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: isVoiceEnabled ? AppColors.primaryPurple : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ),
              ),
              
              // Open in Car Navigation (Circular shape)
              if (onOpenInCar != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onOpenInCar,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBE6F8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              
              // Close/Cancel Button (Circular shape)
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _parseDistanceText(String text) {
  final lower = text.toLowerCase();
  if (!lower.startsWith('in ')) return 0.0;
  final match = RegExp(r'in\s+([\d\.]+)\s*(m|km)').firstMatch(lower);
  if (match != null) {
    final value = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = match.group(2) ?? '';
    if (unit == 'm') {
      return value / 1000.0;
    }
    return value;
  }
  return 0.0;
}
