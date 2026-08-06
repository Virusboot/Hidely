import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/nearby_locations_screen.dart';
import 'package:hidely_new/screens/nearby_stays_screen.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/widgets/travel_squad_sheet.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';

class LocationDetailScreen extends StatefulWidget {
  final String title;
  final String location;
  final String image;
  final String category;

  const LocationDetailScreen({
    super.key,
    this.title = "Tiger Hills Water Fall",
    this.location = "Nenital, Uttrakhand",
    this.image = "assets/images/explore_2.png",
    this.category = "Waterfalls",
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  int _activeTab = 0; // 0: Grid, 1: Reels, 2: Bookmarks
  List<dynamic> _locationPosts = [];
  bool _isLoadingGrid = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationPosts();
  }

  Future<void> _fetchLocationPosts() async {
    final result = await ApiService().getExplorePosts(
      city: widget.location,
      token: AuthService().token,
    );
    if (mounted) {
      final List postsFromApi = (result.success && result.data != null && result.data!['posts'] is List)
          ? result.data!['posts']
          : [];
      setState(() {
        _isLoadingGrid = false;
        if (postsFromApi.isNotEmpty) {
          _locationPosts = postsFromApi;
        } else {
          // Provide default curated location images if backend has no user uploads yet
          _locationPosts = [
            {
              "id": 101,
              "title": widget.title,
              "location": widget.location,
              "image_url": widget.image,
              "category": widget.category,
              "author_username": "hidely_official",
              "is_verified": true,
              "likes_count": 0,
            },
            {
              "id": 102,
              "title": "${widget.title} Sunset Point",
              "location": widget.location,
              "image_url": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80",
              "category": widget.category,
              "author_username": "hidely_official",
              "is_verified": true,
              "likes_count": 0,
            },
            {
              "id": 103,
              "title": "${widget.title} Scenic Trail",
              "location": widget.location,
              "image_url": "https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=600&q=80",
              "category": widget.category,
              "author_username": "hidely_official",
              "is_verified": true,
              "likes_count": 0,
            },
          ];
        }
      });
    }
  }

  // Dynamic details mapper to customize details depending on the selected destination
  Map<String, String> _getDetails() {
    final titleLower = widget.title.toLowerCase();
    if (titleLower.contains("parthenon")) {
      return {
        "description": "A former temple on the Athenian Acropolis, Greece, dedicated to the goddess Athena, built in 447 BC. It is the most important surviving building of Classical Greece.",
        "tags": "Ancient Greek, historical temple, iconic views, UNESCO site, photo spot",
        "region": "Acropolis, Athens",
        "difficulty": "Easy to Moderate Walk",
        "season": "April–October",
      };
    } else if (titleLower.contains("colosseum") || titleLower.contains("caryatids") || titleLower.contains("erechtheion") || titleLower.contains("hephaestus")) {
      return {
        "description": "A landmark of ancient engineering and classical ruins. Explore the majestic architecture and learn about historical archaeological preservation.",
        "tags": "Archaeology, heritage, historical landmark, guided tours, sightseeing",
        "region": "Historical Center, Rome",
        "difficulty": "Easy Walk",
        "season": "Year-round",
      };
    } else if (titleLower.contains("lighthouse") || titleLower.contains("sea") || titleLower.contains("sunset")) {
      return {
        "description": "A scenic viewpoint offering panoramic sunset horizons, pristine coastal paths, and historical maritime significance.",
        "tags": "Ocean sunset, photography, coastal trail, relaxing, fresh breeze",
        "region": "Chania Harbor, Greece",
        "difficulty": "Easy Access",
        "season": "May–September",
      };
    }

    // Default Tiger Hills Water Fall mock data from screenshot
    return {
      "description": "A beautiful waterfall surrounded by dense forests and hills, known for its peaceful atmosphere and scenic trekking trail.",
      "tags": "Natural pool, lush greenery, photography spot, less crowded",
      "region": "Chakrata, Uttarakhand",
      "difficulty": "Easy to Moderate",
      "season": "July–November",
    };
  }
  @override
  Widget build(BuildContext context) {
    final details = _getDetails();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xffF6F9FC),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffE0F2FE),
              Color(0xffFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 1. HEADER SECTION ---
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1.1 TOP NAVIGATION ROW ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                widget.location,
                                style: const TextStyle(
                                  color: Color(0xff1C0D5A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final cleanTitle = widget.title.trim();
                              final cleanLoc = widget.location.trim();
                              final isCaption = cleanTitle.length > 35 || cleanTitle.contains('#') || cleanTitle.contains('\n');

                              String searchQuery;
                              if (!isCaption && cleanTitle.isNotEmpty && cleanTitle != cleanLoc) {
                                searchQuery = cleanLoc.isNotEmpty ? "$cleanTitle, $cleanLoc" : cleanTitle;
                              } else {
                                searchQuery = cleanLoc.isNotEmpty ? cleanLoc : cleanTitle;
                              }

                              MapDiscoveryScreen.initialSearchQuery = searchQuery;
                              MapDiscoveryScreen.startNavigationDirectly = true;
                              Navigator.popUntil(context, (route) => route.settings.name == '/main' || route.isFirst);
                              Future.delayed(const Duration(milliseconds: 300), () {
                                MainWrapperState.activeState?.setIndex(1);
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.near_me_rounded,
                                color: Color(0xff1C0D5A),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 1.3 PREMIUM COLLECTION TYPOGRAPHY ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.location,
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (widget.title.isNotEmpty && widget.title != widget.location) 
                                ? widget.title 
                                : details["description"]!,
                            style: const TextStyle(
                              color: Color(0xff4A457A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            details["tags"]!,
                            style: const TextStyle(
                              color: Color(0xff6366F1),
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 1.4 BADGES INFORMATION SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.75)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  details["region"]!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xff1C0D5A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1.5,
                                height: 18,
                                color: const Color(0xff1C0D5A).withOpacity(0.2),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.tour_outlined, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.75)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  details["difficulty"]!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xff1C0D5A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 18, color: const Color(0xff1C0D5A).withOpacity(0.75)),
                              const SizedBox(width: 8),
                              Text(
                                details["season"]!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xff1C0D5A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 1.5 ACTION BUTTONS ROW ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      isDismissible: false,
                                      enableDrag: false,
                                      builder: (ctx) => TravelSquadSheet(locationName: widget.title.isNotEmpty ? widget.title : widget.location),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_rounded, color: Color(0xff29A96A), size: 18),
                                  label: const Text('Travel Squad', style: TextStyle(color: Color(0xff29A96A), fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xff29A96A), width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: const Color(0xffF0FDF4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xffE2DCF7), width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const NearbyLocationsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Nearby Spots",
                                    style: TextStyle(
                                      color: Color(0xff1C0D5A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xffE2DCF7), width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const NearbyStaysScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Nearby Stays",
                                    style: TextStyle(
                                      color: Color(0xff1C0D5A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 1.6 INTERACTIVE TAB BAR WITH SELECTION ---
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xffE2E8F0), width: 1.2),
                          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildTabItem(0, Icons.grid_view_rounded),
                          _buildTabItem(1, Icons.play_circle_outline_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. GRID CONTENT DISPLAY ---
              SliverPadding(
                padding: const EdgeInsets.only(left: 4.0, right: 4.0, top: 4.0, bottom: 80.0),
                sliver: _buildSliverContent(_locationPosts),
              ),
            ],
          ),
        ),
      ),
    ),);
  }

  Widget _buildTabItem(int index, IconData icon) {
    final bool isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: Color(0xff2B1564), width: 3.0),
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xff2B1564) : Colors.black38,
            size: 22,
          ),
        ),
      ),
    );
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.mkv') || lower.endsWith('.avi');
  }

  Widget _buildSliverContent(List<dynamic> locationPosts) {
    if (_activeTab == 0) {
      if (_isLoadingGrid) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xff2B1564))),
          ),
        );
      }
      final postsOnly = locationPosts.where((p) => !_isVideo(p["image_url"] ?? "")).toList();
      if (postsOnly.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.landscape_outlined, size: 36, color: const Color(0xff1C0D5A).withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    "No wonder captures yet",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Grid View for Posts
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 4 / 5,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = postsOnly[index];
            final imagePath = post["image_url"]?.toString() ?? "";
            final bool isNetwork = imagePath.startsWith("http") || imagePath.startsWith("https") || imagePath.startsWith("uploads") || imagePath.startsWith("/uploads") || imagePath.contains("maps.googleapis.com");
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SinglePostViewScreen(
                      posts: postsOnly,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.black12,
                child: isNetwork
                    ? Image.network(
                        imagePath.startsWith('http') ? imagePath : '${ApiService().baseUrl}/$imagePath',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xffCBD5E1),
                          child: const Icon(Icons.landscape_outlined, color: Colors.white38),
                        ),
                      )
                    : Image.asset(
                        imagePath.isNotEmpty ? imagePath : "assets/images/onboarding_bg.jpg",
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xffCBD5E1),
                          child: const Icon(Icons.landscape_outlined, color: Colors.white38),
                        ),
                      ),
              ),
            );
          },
          childCount: postsOnly.length,
        ),
      );
    } else {
      if (_isLoadingGrid) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xff2B1564))),
          ),
        );
      }
      final reelsOnly = locationPosts.where((p) => _isVideo(p["image_url"] ?? "")).toList();
      if (reelsOnly.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 36, color: const Color(0xff1C0D5A).withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    "No Reels Uploaded",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Grid View for Reels
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 4 / 5,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SinglePostViewScreen(
                      posts: reelsOnly,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 36,
                  ),
                ),
              ),
            );
          },
          childCount: reelsOnly.length,
        ),
      );
    }
  }
}
