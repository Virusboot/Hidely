import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/screens/stay_detail_screen.dart';

class NearbyStaysScreen extends StatefulWidget {
  const NearbyStaysScreen({super.key});

  @override
  State<NearbyStaysScreen> createState() => _NearbyStaysScreenState();
}

class _NearbyStaysScreenState extends State<NearbyStaysScreen> {
  final List<String> _categories = ["All", "Resorts", "Hotels", "Restaurants"];
  List<String> _selectedCategories = ["All"];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<Map<String, dynamic>> _allStays = [];
  List<Map<String, dynamic>> _filteredStays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filteredStays = List.from(_allStays);
    _fetchLiveStays();
  }

  Future<void> _fetchLiveStays() async {
    try {
      setState(() => _isLoading = true);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      const apiKey = 'AIzaSyB5ftUcwqjuC1BZtI26KrZsblQIF1Bl7t0';
      final lat = pos.latitude;
      final lng = pos.longitude;

      final restaurantUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng&radius=3000&type=restaurant&key=$apiKey'
      );
      final hotelUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng&radius=3000&type=lodging&key=$apiKey'
      );

      final responses = await Future.wait([
        http.get(restaurantUrl).timeout(const Duration(seconds: 4)),
        http.get(hotelUrl).timeout(const Duration(seconds: 4)),
      ]);

      final List<Map<String, dynamic>> liveStays = [];

      for (int i = 0; i < 2; i++) {
        final res = responses[i];
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'OK' && data['results'] != null) {
            for (final result in data['results']) {
              final String name = result['name'] ?? '';
              final double rating = (result['rating'] as num?)?.toDouble() ?? 4.0;
              final geometry = result['geometry'] ?? {};
              final location = geometry['location'] ?? {};
              final double latitude = (location['lat'] as num?)?.toDouble() ?? 0.0;
              final double longitude = (location['lng'] as num?)?.toDouble() ?? 0.0;
              final types = result['types'] as List? ?? [];
              final vicinity = result['vicinity'] ?? '';

              String category = 'Hotels';
              String tag = 'HOTEL';
              String image = '';
              final photos = result['photos'] as List?;
              if (photos != null && photos.isNotEmpty) {
                final photoRef = photos[0]['photo_reference'];
                image = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$apiKey';
              }

              if (i == 0) {
                category = 'Restaurants';
                tag = 'RESTAURANT';
                if (image.isEmpty) image = 'assets/images/onboarding_2.jpg';
              } else {
                if (types.contains('resort') || name.toLowerCase().contains('resort')) {
                  category = 'Resorts';
                  tag = 'RESORT';
                  if (image.isEmpty) image = 'assets/images/background.jpg';
                } else {
                  if (image.isEmpty) image = 'assets/images/onboarding_bg.jpg';
                }
              }

              final double dLat = (latitude - lat) * 111.12;
              final double dLng = (longitude - lng) * 111.12 * cos(lat * 3.14159 / 180.0);
              final double dist = sqrt(dLat * dLat + dLng * dLng);

              final userRatingCount = result['user_ratings_total'] ?? 150;

              liveStays.add({
                "title": name,
                "category": category,
                "distance": "${dist.toStringAsFixed(1)} KM AWAY",
                "rating": rating.toStringAsFixed(1),
                "reviews": "($userRatingCount reviews)",
                "description": vicinity.isEmpty ? "A highly rated location nearby." : vicinity,
                "image": image,
                "tag": tag,
                "isFavorite": false,
                "latitude": latitude,
                "longitude": longitude,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allStays.clear();
          _allStays.addAll(liveStays);
          _filterStays();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NearbyStays] Failed to load live stays: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  double _maxDistance = 10.0;

  void _filterStays() {
    setState(() {
      List<dynamic> results = List.from(_allStays);

      // Category filter
      if (!_selectedCategories.contains("All") && _selectedCategories.isNotEmpty) {
        results = results.where((stay) => _selectedCategories.contains(stay["category"]?.toString())).toList();
      }

      // Distance threshold filter
      if (_maxDistance < 10.0) {
        results = results.where((stay) {
          final distanceStr = stay["distance"]?.toString() ?? "";
          final distanceVal = double.tryParse(distanceStr.split(' ')[0]) ?? 0.0;
          return distanceVal <= _maxDistance;
        }).toList();
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        results = results.where((stay) {
          final title = stay["title"]?.toString().toLowerCase() ?? "";
          final description = stay["description"]?.toString().toLowerCase() ?? "";
          return title.contains(_searchQuery.toLowerCase()) ||
              description.contains(_searchQuery.toLowerCase());
        }).toList();
      }


      _filteredStays = results.cast<Map<String, dynamic>>();
    });
  }

  void _showFilterBottomSheet(BuildContext context) {
    List<String> localCategories = List.from(_selectedCategories);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Filter Stays",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Distance Slider Section
                  const Text(
                    "Max Distance",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFilterChip(
                        label: "All",
                        isSelected: _maxDistance >= 10.0,
                        onTap: () {
                          setSheetState(() {
                            _maxDistance = 10.0;
                          });
                          _filterStays();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: "< 1.0 KM",
                        isSelected: _maxDistance == 1.0,
                        onTap: () {
                          setSheetState(() {
                            _maxDistance = 1.0;
                          });
                          _filterStays();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: "< 2.0 KM",
                        isSelected: _maxDistance == 2.0,
                        onTap: () {
                          setSheetState(() {
                            _maxDistance = 2.0;
                          });
                          _filterStays();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: "< 5.0 KM",
                        isSelected: _maxDistance == 5.0,
                        onTap: () {
                          setSheetState(() {
                            _maxDistance = 5.0;
                          });
                          _filterStays();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category Section (Multi-Select)
                  const Text(
                    "Category (Multi-Select)",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = localCategories.contains(cat);
                      return _buildFilterChip(
                        label: cat,
                        isSelected: isSelected,
                        onTap: () {
                          setSheetState(() {
                            if (cat == "All") {
                              localCategories = ["All"];
                            } else {
                              localCategories.remove("All");
                              if (isSelected) {
                                localCategories.remove(cat);
                                if (localCategories.isEmpty) localCategories.add("All");
                              } else {
                                localCategories.add(cat);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 36),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories = localCategories;
                        });
                        _filterStays();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        "Apply Filters",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff2B1564) : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xffE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xff1C0D5A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. TOP NAV BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
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
                    const SizedBox(width: 16),
                    const Text(
                      "Near By Stay",
                      style: TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. SEARCH BAR AND FILTER BUTTON ---
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black38, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  _searchQuery = value;
                                  _filterStays();
                                },
                                style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: "Search ancient wonders...",
                                  hintStyle: TextStyle(color: Colors.black26),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showFilterBottomSheet(context),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xff1C0D5A),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 3. HORIZONTAL CATEGORIES BAR ---
              SizedBox(
                height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final bool isSelected = _selectedCategories.contains(cat);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (cat == "All") {
                              _selectedCategories = ["All"];
                            } else {
                              _selectedCategories.remove("All");
                              if (isSelected) {
                                _selectedCategories.remove(cat);
                                if (_selectedCategories.isEmpty) _selectedCategories.add("All");
                              } else {
                                _selectedCategories.add(cat);
                              }
                            }
                            _filterStays();
                          });
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 300),
                            alignment: 0.5,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xff2B1564) : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.6),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xff1C0D5A).withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // --- 4. SCROLLING VERTICAL LIST OF RESULTS ---
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredStays.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, size: 54, color: Colors.black26),
                            SizedBox(height: 12),
                            Text(
                              "No stays found",
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
                        itemCount: _filteredStays.length,
                        itemBuilder: (context, index) {
                          final stay = _filteredStays[index];
                          return _buildStayCard(stay, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }

  Widget _buildStayCard(Map<String, dynamic> stay, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StayDetailScreen(stay: stay),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and floating widgets stack
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: stay["image"].startsWith("http")
                        ? Image.network(
                            stay["image"],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, color: Colors.black26),
                            ),
                          )
                        : Image.asset(
                            stay["image"],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  ),
                ),
              ),

              // Floating tag (Restaurant / Hidden Gem / Resort etc.)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    stay["tag"],
                    style: const TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Floating Heart Favorite Icon Button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      stay["isFavorite"] = !stay["isFavorite"];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      stay["isFavorite"] ? Icons.favorite : Icons.favorite_border_rounded,
                      color: stay["isFavorite"] ? Colors.redAccent : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        stay["title"],
                        style: const TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      stay["distance"],
                      style: const TextStyle(
                        color: Color(0xff5D3EBC),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      stay["rating"],
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stay["reviews"],
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  stay["description"],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff4A457A),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // Button row: Navigate and Share
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            MapDiscoveryScreen.initialSearchQuery = stay["title"];
                            MapDiscoveryScreen.startNavigationDirectly = true;
                            Navigator.popUntil(context, (route) => route.isFirst);
                            MainWrapperState.activeState?.setIndex(1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2B1564),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.near_me_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                "Navigate",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Link copied for ${stay["title"]}!"),
                            backgroundColor: const Color(0xff2B1564),
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xffE2DCF7),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.share_outlined,
                          color: Color(0xff2B1564),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
