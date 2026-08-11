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
  bool _isSaved = false;

  void _toggleSave() {
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? "Saved to your bookmarks!" : "Removed from bookmarks"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareLocation() {
    final title = widget.title.isNotEmpty ? widget.title : widget.location;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sharing link for $title (https://hidely.app/place/2001)"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }



  void _navigateToLocationInApp() {
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
    Future.delayed(const Duration(milliseconds: 200), () {
      MainWrapperState.activeState?.setIndex(1);
    });
  }

  void _showLocationFeedbackSheet(BuildContext context) {
    int selectedRating = 5;
    String selectedCategory = 'General Tip';
    final feedbackController = TextEditingController();

    const categories = ['General Tip', 'Road Condition', 'Best Time', 'Safety Tip', 'Parking & Entry'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String ratingDesc = 'Excellent experience!';
            if (selectedRating == 4) {
              ratingDesc = 'Good destination';
            } else if (selectedRating == 3) {
              ratingDesc = 'Average place';
            } else if (selectedRating == 2) {
              ratingDesc = 'Needs improvement';
            } else if (selectedRating == 1) {
              ratingDesc = 'Poor condition';
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar Indicator
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.rate_review_rounded, color: Color(0xffD97706), size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Feedback & Tips',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff1C0D5A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xff047857)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Earn +50 Explorer XP!',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Color(0xff1C0D5A)),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xffF1F5F9),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xffF1F5F9), height: 1),
                    const SizedBox(height: 14),

                    // Scrollable Inputs Area
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Star Rating Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xffF1F5F9)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'How was your experience?',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(5, (index) {
                                          final star = index + 1;
                                          return GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                selectedRating = star;
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 10.0),
                                              child: Icon(
                                                star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                                color: const Color(0xffF59E0B),
                                                size: 34,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ratingDesc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xffD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Feedback Tags
                            const Text(
                              'Select Topic Category',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categories.map((cat) {
                                final isSel = cat == selectedCategory;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedCategory = cat;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xff2B1564) : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSel ? const Color(0xff2B1564) : const Color(0xffE2E8F0),
                                        width: 1.2,
                                      ),
                                      boxShadow: isSel ? [
                                        BoxShadow(
                                          color: const Color(0xff2B1564).withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ] : [],
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        color: isSel ? Colors.white : const Color(0xff4A457A),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // Tips Box input
                            const Text(
                              'Write Location Details & Tips',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: feedbackController,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Share road condition, parking space, ticket prices, safety tips, or best visit hours...',
                                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38, height: 1.4),
                                fillColor: const Color(0xffF8FAFC),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xff2B1564), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),

                    // Submit Button Row with keyboard-insets offset
                    Container(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 14,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xffF1F5F9), width: 1),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2B1564),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xff2B1564).withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (feedbackController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter your feedback or tips')),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 22),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Feedback submitted! +50 Explorer XP added to your profile 🌟',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xff2B1564),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Submit Feedback (+50 XP)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHighlightBubble({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xff1C0D5A).withOpacity(0.15), width: 1.5),
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff1C0D5A),
            ),
          ),
        ],
      ),
    );
  }

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
        _locationPosts = postsFromApi;
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

    return {
      "description": "Explore ${widget.title} in ${widget.location}. Discover scenic views and local attractions.",
      "tags": widget.category.isNotEmpty ? widget.category : "Explore, Hidden Spots, Sightseeing",
      "region": widget.location,
      "difficulty": "Easy to Moderate",
      "season": "Year-round",
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
                          // Only Navigation button in top right
                          GestureDetector(
                            onTap: _navigateToLocationInApp,
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
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xffFDBA74).withOpacity(0.5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 16, color: Color(0xffF59E0B)),
                                    SizedBox(width: 4),
                                    Text('4.8', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xff9A3412))),
                                    SizedBox(width: 4),
                                    Text('(128 Reviews)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xffC2410C))),
                                  ],
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

                    // --- INSTAGRAM HIGHLIGHT STYLE ACTION BUBBLES ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildHighlightBubble(
                              icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                              label: _isSaved ? 'Saved' : 'Save',
                              iconColor: const Color(0xff1C0D5A),
                              onTap: _toggleSave,
                            ),
                            _buildHighlightBubble(
                              icon: Icons.share_rounded,
                              label: 'Share',
                              iconColor: const Color(0xff1C0D5A),
                              onTap: _shareLocation,
                            ),
                            _buildHighlightBubble(
                              icon: Icons.rate_review_outlined,
                              label: 'Feedback',
                              iconColor: const Color(0xff1C0D5A),
                              onTap: () => _showLocationFeedbackSheet(context),
                            ),
                          ],
                        ),
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
