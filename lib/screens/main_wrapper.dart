import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hidely_new/config/responsive_breakpoints.dart';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/group_chat_screen.dart';
import 'package:hidely_new/screens/explore_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/login_screen.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/call_manager.dart';
import 'package:hidely_new/widgets/desktop_sidebar.dart';
import 'package:hidely_new/widgets/right_discovery_panel.dart';
import 'package:hidely_new/config/routes.dart';
import 'package:hidely_new/utils/web_history.dart';

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
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier<int>(0);
  late int _currentIndex;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    activeState = this;
    _currentIndex = widget.initialIndex;
    currentTabNotifier.value = _currentIndex;
    if (!AuthService().isGuest) {
      CallManager().ensureInitialized();
      AuthService().syncBlockedUsersFromServer();
      AuthService().syncTagMentionSettingsFromServer();
    }
    if (kIsWeb) {
      final path = AppRoutes.pathForTab(_currentIndex);
      AppRoutes.syncWebUrl(path);
      listenToPopState((newPath) {
        if (!mounted) return;
        final newIndex = AppRoutes.tabForPath(newPath);
        if (newIndex != _currentIndex) {
          setIndex(newIndex, updateHistory: false);
        }
      });
    }
  }

  @override
  void dispose() {
    if (activeState == this) {
      activeState = null;
    }
    super.dispose();
  }

  void setIndex(int index, {bool updateHistory = true}) {
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
    currentTabNotifier.value = index;
    if (kIsWeb && updateHistory) {
      final path = AppRoutes.pathForTab(index);
      AppRoutes.syncWebUrl(path);
    }
    GroupChatScreen.activeState?.clearSearch();
    if (index == 0) {
      FeedScreen.activeState?.reload();
    } else if (index == 1) {
      MapDiscoveryScreen.activeState?.checkSearchQuery();
    } else if (index == 4) {
      UserProfileScreen.activeState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOrTablet = ResponsiveBreakpoints.isDesktopOrTablet(context);
    final bool isLargeDesktop = ResponsiveBreakpoints.isLargeDesktop(context);

    // Calculate dynamic bottom margin: never overlap buttons, never float too high
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double navBottom;
    if (kIsWeb) {
      navBottom = 12.0;
    } else if (bottomInset > 0) {
      // 3-button navigation (typically >= 36dp): place 8dp above the buttons
      // Gesture bar (typically 16-34dp): place 10dp above the gesture indicator
      navBottom = bottomInset >= 36 ? bottomInset + 8.0 : bottomInset + 10.0;
    } else {
      navBottom = 14.0;
    }

    final Widget bodyView = Stack(
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
    );

    return PopScope(
      // Instagram-style back navigation:
      // When on Home (tab 0) or web, allow default system pop (minimizes app on Android without popup)
      canPop: kIsWeb || _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || kIsWeb) return;

        // If on another tab (Map, Chat, Explore, Profile), navigate directly to Home (tab 0)
        if (_currentIndex != 0) {
          setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF6F9FC),
        body: isDesktopOrTablet
            ? Row(
                children: [
                  // Persistent Left Sidebar
                  DesktopSidebar(
                    currentIndex: _currentIndex,
                    onTabSelected: setIndex,
                  ),
                  // Active Screen View Area
                  Expanded(child: bodyView),
                  // Contextual Right Discovery Panel on Large Desktop
                  if (isLargeDesktop && _currentIndex == 0)
                    const RightDiscoveryPanel(),
                ],
              )
            : Stack(
                children: [
                  // Mobile Screen View Area
                  bodyView,

                  // --- GLOBAL FLOATING PILL NAVIGATION BAR FOR MOBILE ---
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
                      bottom: navBottom,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
                          height: 64,
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
