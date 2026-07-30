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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Select turn icon based on instruction text content
    IconData turnIcon = Icons.navigation_rounded;
    String instructionText = routeData.instructions.isNotEmpty 
        ? routeData.instructions[activeInstructionIndex]
        : l10n.followRoute;

    if (instructionText.toLowerCase().contains('right')) {
      turnIcon = Icons.turn_right_rounded;
    } else if (instructionText.toLowerCase().contains('left')) {
      turnIcon = Icons.turn_left_rounded;
    } else if (instructionText.toLowerCase().contains('straight')) {
      turnIcon = Icons.straight_rounded;
    } else if (instructionText.toLowerCase().contains('arrive')) {
      turnIcon = Icons.place_rounded;
    }

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
          // Row 1: Prominent ETA (Apple style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${routeData.durationMin} min',
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  color: const Color(0xff34C759), // iOS Green
                  fontSize: context.sp(22),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${routeData.distanceKm} km  •  $arrivalTimeString',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    color: const Color(0xFF6B657D),
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 2: Turn-by-Turn Instruction
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
                    turnIcon,
                    color: Colors.white,
                    size: context.w(18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructionText,
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        color: AppColors.primaryPurple,
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      navStatus == NavigationStatus.navigating
                          ? l10n.navigationActive
                          : l10n.nextTurnAhead,
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        color: const Color(0xFF8E8AA0),
                        fontSize: context.sp(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
