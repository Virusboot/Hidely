import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';

class NearbyLocationsScreen extends StatefulWidget {
  const NearbyLocationsScreen({super.key});

  @override
  State<NearbyLocationsScreen> createState() => _NearbyLocationsScreenState();
}

class _NearbyLocationsScreenState extends State<NearbyLocationsScreen> {
  final List<String> _categories = ["All", "Waterfalls", "Rivers", "Mountains"];
  List<String> _selectedCategories = ["All"];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _filteredPosts = [];

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLiveLocations();
  }

  Future<void> _fetchLiveLocations() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      }

      final result = await ApiService().getExplorePosts(token: AuthService().token);
      if (result.success) {
        final List<dynamic> postsData = result.data?['posts'] ?? [];
        List<Map<String, dynamic>> parsedPosts = postsData.map((e) => Map<String, dynamic>.from(e)).toList();
        
        if (_currentPosition != null) {
          for (var post in parsedPosts) {
            final lat = double.tryParse(post['latitude']?.toString() ?? '');
            final lng = double.tryParse(post['longitude']?.toString() ?? '');
            if (lat != null && lng != null) {
              final distInMeters = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, lat, lng);
              post['distance'] = distInMeters;
            } else {
              post['distance'] = double.maxFinite;
            }
          }
          parsedPosts.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        }

        if (mounted) {
          setState(() {
            _allPosts = parsedPosts;
            _filterPosts();
          });
        }
      }
    } catch (e) {
      debugPrint('[NearbyLocations] Failed to load live locations: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPosts() {
    setState(() {
      List<dynamic> results = List.from(_allPosts);

      // Category filter
      if (!_selectedCategories.contains("All") && _selectedCategories.isNotEmpty) {
        results = results.where((post) => _selectedCategories.contains(post["category"]?.toString())).toList();
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        results = results.where((post) {
          final title = post["caption"]?.toString().toLowerCase() ?? "";
          final location = post["location"]?.toString().toLowerCase() ?? "";
          return title.contains(_searchQuery.toLowerCase()) ||
              location.contains(_searchQuery.toLowerCase());
        }).toList();
      }

      _filteredPosts = results.cast<Map<String, dynamic>>();
    });
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
              // --- 1. TOP SEARCH BAR AND FILTER WITH BACK BUTTON ---
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 10.0),
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
                    const SizedBox(width: 12),
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
                                  _filterPosts();
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
                      onTap: () {
                        List<String> localCategories = List.from(_selectedCategories);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => StatefulBuilder(
                            builder: (context, setModalState) => Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                              ),
                              child: SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                                        TextButton(
                                          onPressed: () => setModalState(() => localCategories = ["All"]),
                                          child: const Text("Reset", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("Category (Multi-Select)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _categories.map((cat) {
                                        final isSelected = localCategories.contains(cat);
                                        return GestureDetector(
                                          onTap: () {
                                            setModalState(() {
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
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xff2B1564) : const Color(0xffF1F5F9),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              cat,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : const Color(0xff1C0D5A).withOpacity(0.7),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xff2B1564),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectedCategories = localCategories;
                                          });
                                          _filterPosts();
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

              // --- 2. HORIZONTAL CATEGORY CHIPS ---
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
                            _filterPosts();
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

              // --- 3. DYNAMIC EXPLORATION STREAM GRID (Asymmetric Layout) ---
              Expanded(
                child: _filteredPosts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 140.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 64, color: Colors.black26),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No wonders found",
                                    style: TextStyle(
                                      color: const Color(0xff1C0D5A).withOpacity(0.5),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                    : GridView.builder(
                        padding: EdgeInsets.only(
                          left: 0.0,
                          right: 0.0,
                          top: 4.0,
                          bottom: 120 + MediaQuery.of(context).padding.bottom,
                        ),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 4 / 5,
                        ),
                        itemCount: _filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
                          final imageUrl = post["image_url"]?.toString() ?? "";
                          final caption = post["caption"]?.toString() ?? "Hidden Gem";
                          final locationStr = post["location"]?.toString() ?? "Unknown";
                          final categoryStr = post["category"]?.toString() ?? "Nature";

                          final bool isNetwork = imageUrl.startsWith("http") || imageUrl.startsWith("uploads");
                          final bool isVideo = imageUrl.toLowerCase().endsWith('.mp4') || imageUrl.toLowerCase().endsWith('.mov') || imageUrl.toLowerCase().endsWith('.mkv') || imageUrl.toLowerCase().endsWith('.avi');

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationDetailScreen(
                                    title: caption,
                                    location: locationStr,
                                    image: imageUrl,
                                    category: categoryStr,
                                  ),
                                ),
                              ).then((_) => _fetchLiveLocations());
                            },
                            child: Container(
                              color: Colors.black12,
                              child: isVideo
                                  ? const Center(
                                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40),
                                    )
                                  : isNetwork
                                  ? Image.network(
                                      imageUrl.startsWith("http") ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xffCBD5E1),
                                        child: const Icon(Icons.landscape_outlined, color: Colors.white38),
                                      ),
                                    )
                                  : Image.asset(
                                      imageUrl.isNotEmpty ? imageUrl : "assets/images/onboarding_bg.jpg",
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xffCBD5E1),
                                        child: const Icon(Icons.landscape_outlined, color: Colors.white38),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
