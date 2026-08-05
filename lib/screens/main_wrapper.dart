import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/group_chat_screen.dart';
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
    // Chat tab (index 2) requires login
    if (index == 2 && AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'access chat');
      return;
    }
    // Profile tab (index 4) requires login
    if (index == 4 && AuthService().isGuest) {
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
    } else if (index == 4) {
      UserProfileScreen.activeState?.reload();
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Exit App?",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          "Are you sure you want to close Hidely?",
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "No",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2B1564),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              "Yes, Exit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF6F9FC),
        body: Stack(
          children: [
            // Active screen body layout render area
            Stack(
              children: [
                Offstage(
                  offstage: _currentIndex != 0,
                  child: const FeedScreen(),
                ),
                if (_currentIndex == 1)
                  const MapDiscoveryScreen(),
                Offstage(
                  offstage: _currentIndex != 2,
                  child: const GroupChatScreen(),
                ),
                Offstage(
                  offstage: _currentIndex != 3,
                  child: const ExploreScreen(),
                ),
                Offstage(
                  offstage: _currentIndex != 4,
                  child: const UserProfileScreen(),
                ),
              ],
            ),

          // --- GLOBAL FLOATING PILL NAVIGATION BAR ---
          ValueListenableBuilder<bool>(
            valueListenable: GroupChatScreen.isChatRoomOpen,
            builder: (context, isChatOpen, child) {
              if (isChatOpen && _currentIndex == 2) {
                return const SizedBox.shrink();
              }
              return child!;
            },
            child: Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Container(
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 1st Icon: Home Feed
                        _buildNavIcon(assetPath: 'assets/icons/Home.png', index: 0),

                        // 2nd Icon: Map Discovery
                        _buildNavIcon(assetPath: 'assets/icons/Map.png', index: 1),

                        // 3rd Icon: Group Trip Chat (New Chat Module Screen)
                        if (!AuthService().isGuest)
                          _buildNavIcon(assetPath: 'assets/icons/send.png', index: 2),

                        // 4th Icon: Binoculars / Explore Grid
                        _buildNavIcon(assetPath: 'assets/icons/Explore.png', index: 3),

                        // 5th Icon: Personal Profile (auth-gated for guests)
                        _buildNavIcon(assetPath: 'assets/icons/Profile.png', index: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  /// Nav icon builder using local assets or IconData
  Widget _buildNavIcon({String? assetPath, IconData? iconData, required int index}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffE2DCF7) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: assetPath != null
            ? Image.asset(
                assetPath,
                width: 22,
                height: 22,
                color: isSelected ? const Color(0xff361976) : Colors.black38,
              )
            : Icon(
                iconData,
                size: 22,
                color: isSelected ? const Color(0xff361976) : Colors.black38,
              ),
      ),
    );
  }
}
