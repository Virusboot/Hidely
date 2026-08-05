import 'package:flutter/material.dart';

class ExplorerBadge extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;

  const ExplorerBadge({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
  });

  factory ExplorerBadge.fromPostCount(int postCount) {
    if (postCount >= 10) {
      return const ExplorerBadge(
        title: 'Master Explorer',
        icon: Icons.military_tech_rounded,
        primaryColor: Color(0xff7C3AED),
        backgroundColor: Color(0xffF3E8FF),
      );
    } else if (postCount >= 5) {
      return const ExplorerBadge(
        title: 'Spot Finder',
        icon: Icons.explore_rounded,
        primaryColor: Color(0xff2563EB),
        backgroundColor: Color(0xffDBEAFE),
      );
    } else if (postCount >= 1) {
      return const ExplorerBadge(
        title: 'Unexplored Pioneer',
        icon: Icons.terrain_rounded,
        primaryColor: Color(0xff059669),
        backgroundColor: Color(0xffD1FAE5),
      );
    }
    return const ExplorerBadge(
      title: 'Novice Wanderer',
      icon: Icons.map_rounded,
      primaryColor: Color(0xff6B7280),
      backgroundColor: Color(0xffF3F4F6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              color: primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'PublicSans',
            ),
          ),
        ],
      ),
    );
  }
}
