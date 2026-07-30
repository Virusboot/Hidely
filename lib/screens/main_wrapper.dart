import 'package:flutter/material.dart';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/explore_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/login_screen.dart';
import 'package:hidely_new/services/auth_service.dart';

/// Global helper — call this from any screen to show the premium
/// "Login required" bottom-sheet whenever a guest tries an auth-gated action.
void showLoginRequiredSheet(BuildContext context, {String reason = 'this action'}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}


class MainWrapper extends StatefulWidget {
  final int initialIndex;
  const MainWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainWrapper> createState() => MainWrapperState();
}

class MainWrapperState extends State<MainWrapper> {
  static MainWrapperState? activeState;
  late int _currentIndex;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    activeState = this;
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    if (activeState == this) {
      activeState = null;
    }
    super.dispose();
  }

  void setIndex(int index) {
    // Profile tab (index 3) requires login
    if (index == 3 && AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'view your profile');
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      FeedScreen.activeState?.reload();
    } else if (index == 1) {
      MapDiscoveryScreen.activeState?.checkSearchQuery();
    } else if (index == 3) {
      UserProfileScreen.activeState?.reload();
    }
  }

  // Saari screens ki list jo navigation se switch hongi
  final List<Widget> _screens = const [
    FeedScreen(),
    MapDiscoveryScreen(),
    ExploreScreen(),
    UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F9FC),
      body: Stack(
        children: [
          // Active screen body layout render area
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // --- GLOBAL FLOATING PILL NAVIGATION BAR ---
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1st Icon: Home Feed
                  _buildNavIcon('assets/icons/Home.png', 0),

                  // 2nd Icon: Map Discovery
                  _buildNavIcon('assets/icons/Map.png', 1),

                  // 3rd Icon: Binoculars / Explore Grid
                  _buildNavIcon('assets/icons/Explore.png', 2),

                  // 4th Icon: Personal Profile (auth-gated for guests)
                  _buildNavIcon('assets/icons/Profile.png', 3),
                ],
              ),
            ),
            ),
            ),
          ),
        ],
      ),
    );
  }


  /// Nav icon builder using local assets
  Widget _buildNavIcon(String assetPath, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffE2DCF7) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          assetPath,
          width: 24,
          height: 24,
          color: isSelected ? const Color(0xff361976) : Colors.black38,
        ),
      ),
    );
  }
}
