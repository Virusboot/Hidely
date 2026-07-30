import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';

class StayDetailScreen extends StatefulWidget {
  final Map<String, dynamic> stay;
  const StayDetailScreen({super.key, required this.stay});

  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.stay["isFavorite"] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;

    final String title = stay["title"] ?? "Stay Detail";
    final String category = stay["category"] ?? "Hotels";
    final String distance = stay["distance"] ?? "0.0 KM AWAY";
    final String rating = stay["rating"] ?? "5.0";
    final String reviews = stay["reviews"] ?? "(0 reviews)";
    final String description = stay["description"] ?? "";
    final String image = stay["image"] ?? "assets/images/onboarding_bg.jpg";
    final String tag = stay["tag"] ?? "HOTEL";

    // Set amenities list based on category
    final List<Map<String, dynamic>> amenities = (category == "Restaurants" || category == "Rasturents")
        ? [
            {"icon": Icons.restaurant_menu_rounded, "label": "Gastronomy"},
            {"icon": Icons.local_bar_rounded, "label": "Full Bar"},
            {"icon": Icons.wifi_rounded, "label": "Free Wi-Fi"},
            {"icon": Icons.ac_unit_rounded, "label": "Air Conditioned"},
            {"icon": Icons.credit_card_rounded, "label": "Cards Accepted"},
          ]
        : [
            {"icon": Icons.wifi_rounded, "label": "Free Wi-Fi"},
            {"icon": Icons.pool_rounded, "label": "Swimming Pool"},
            {"icon": Icons.spa_rounded, "label": "Luxury Spa"},
            {"icon": Icons.fitness_center_rounded, "label": "Gym"},
            {"icon": Icons.room_service_rounded, "label": "Room Service"},
            {"icon": Icons.ac_unit_rounded, "label": "Air Conditioned"},
          ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Premium Header Image AppBar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xff2B1564),
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Image.asset('assets/images/back_icon.png', color: Colors.white, width: 16.0, height: 16.0)),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (AuthService().isGuest) {
                        showLoginRequiredSheet(
                          context,
                          reason: "wishlist this stay",
                        );
                        return;
                      }
                      setState(() {
                        _isFavorite = !_isFavorite;
                        stay["isFavorite"] = _isFavorite;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isFavorite ? "Added to Wishlist!" : "Removed from Wishlist"),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                        color: _isFavorite ? Colors.redAccent : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xffCBD5E1),
                  child: const Icon(Icons.landscape_outlined, color: Colors.white24, size: 64),
                ),
              ),
            ),
          ),

          // 2. Body Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag & Distance Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xff2B1564),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        distance,
                        style: const TextStyle(
                          color: Color(0xff5D3EBC),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rating & Reviews Row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        reviews,
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section Title: Description
                  const Text(
                    "Overview",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description Text
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xff4A457A),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section Title: Amenities
                  const Text(
                    "Amenities & Features",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amenities Grid (Custom Row/Column layout to avoid nesting gridviews inside scrollviews)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffE2E8F0), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              amenity["icon"],
                              color: const Color(0xff5D3EBC),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              amenity["label"],
                              style: const TextStyle(
                                color: Color(0xff1C0D5A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 120), // Bottom padding for button row overlay
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      MapDiscoveryScreen.initialSearchQuery = title;
                      MapDiscoveryScreen.startNavigationDirectly = true;
                      Navigator.popUntil(context, (route) => route.isFirst);
                      MainWrapperState.activeState?.setIndex(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2B1564),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.near_me_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Get Directions",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    if (AuthService().isGuest) {
                      showLoginRequiredSheet(
                        context,
                        reason: (category == "Restaurants" || category == "Rasturents") ? "book a table" : "book a room",
                      );
                      return;
                    }
                    final String btnText = (category == "Restaurants" || category == "Rasturents") ? "Book a Table" : "Book Stay";
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Redirecting to $btnText..."),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xff2B1564), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    foregroundColor: const Color(0xff2B1564),
                  ),
                  child: Text(
                    (category == "Restaurants" || category == "Rasturents") ? "Book Table" : "Book Room",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
