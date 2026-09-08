import 'package:flutter/material.dart';
import 'package:hidely_new/config/responsive_breakpoints.dart';
import 'package:hidely_new/screens/create_post_screen.dart';
import 'package:hidely_new/screens/leaderboard_screen.dart';
import 'package:hidely_new/screens/notification_screen.dart';
import 'package:hidely_new/screens/settings_and_privacy_screen.dart';
import 'package:hidely_new/screens/login_screen.dart';
import 'package:hidely_new/services/auth_service.dart';

class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompact = ResponsiveBreakpoints.isTablet(context);
    final double width = isCompact ? 80.0 : 250.0;
    final bool isGuest = AuthService().isGuest;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
            child: isCompact
                ? Image.asset('assets/images/app_icon.png', height: 38)
                : Row(
                    children: [
                      Image.asset('assets/images/logo_horizontal_color.png', height: 36,
                          errorBuilder: (_, __, ___) => const Text(
                                'HIDELY',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff1C0D5A),
                                ),
                              )),
                    ],
                  ),
          ),
          const SizedBox(height: 32),

          // Main Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.home_rounded,
                  label: 'Home Feed',
                  index: 0,
                  isCompact: isCompact,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.explore_rounded,
                  label: 'Map Discovery',
                  index: 1,
                  isCompact: isCompact,
                ),
                if (!isGuest)
                  _buildNavItem(
                    context,
                    icon: Icons.forum_rounded,
                    label: 'Trip Chat',
                    index: 2,
                    isCompact: isCompact,
                  ),
                _buildNavItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  label: 'Explore',
                  index: 3,
                  isCompact: isCompact,
                ),
                if (!isGuest)
                  _buildNavItem(
                    context,
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    index: 4,
                    isCompact: isCompact,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xffF1F5F9), height: 1),
                ),
                _buildActionItem(
                  context,
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Create Post',
                  isCompact: isCompact,
                  onTap: () {
                    if (isGuest) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
                          child: const CreatePostScreen(),
                        ),
                      ),
                    );
                  },
                ),
                if (!isGuest)
                  _buildActionItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                _buildActionItem(
                  context,
                  icon: Icons.emoji_events_rounded,
                  label: 'Leaderboard',
                  isCompact: isCompact,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                  },
                ),
                _buildActionItem(
                  context,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isCompact: isCompact,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsAndPrivacyScreen()));
                  },
                ),
              ],
            ),
          ),

          // User Profile Card / Login Action Footer
          Padding(
            padding: EdgeInsets.all(isCompact ? 8 : 16),
            child: isGuest
                ? ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2B1564),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isCompact
                        ? const Icon(Icons.login_rounded, size: 18)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Login'),
                            ],
                          ),
                  )
                : Container(
                    padding: EdgeInsets.all(isCompact ? 8 : 12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xff9333EA),
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'My Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xff0F172A),
                                  ),
                                ),
                                Text(
                                  'Logged in',
                                  style: TextStyle(fontSize: 11, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required bool isCompact,
  }) {
    final bool isSelected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xffF1F5F9),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isCompact ? 0 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xffF3E8FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? const Color(0xff9333EA) : const Color(0xff64748B),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xff2B1564) : const Color(0xff334155),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xffF1F5F9),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isCompact ? 0 : 16,
            ),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: const Color(0xff64748B),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff334155),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
