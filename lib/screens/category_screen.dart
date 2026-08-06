import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  const CategoryScreen({super.key, required this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";
  List<String> _selectedCities = ["All"];
  bool _isLoading = false;
  List<dynamic> _realPosts = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchCategoryPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategoryPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final token = AuthService().token;
      final result = await ApiService().getExplorePosts(
        category: widget.categoryName,
        city: null, // Fetch all cities to support multi-select filtering locally
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        token: token,
      );

      if (mounted) {
        setState(() {
          if (result.success) {
            List<dynamic> posts = result.data?['posts'] ?? [];
            if (!_selectedCities.contains("All") && _selectedCities.isNotEmpty) {
              posts = posts.where((p) {
                final loc = (p['location'] ?? '').toString();
                return _selectedCities.any((city) => loc.contains(city));
              }).toList();
            }
            _realPosts = posts;
          } else {
            _realPosts = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _realPosts = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showFilterSheet(BuildContext context) {
    List<String> localCities = List.from(_selectedCities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                child: Column(
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter by City",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  localCities = ["All"];
                                });
                              },
                              child: const Text(
                                "Reset All",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, color: Color(0xff1C0D5A), size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      "Select City (Multi-Select)",
                      style: TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        "All", "Agra", "Ahmedabad", "Ajmer", "Alappuzha", "Amritsar", 
                        "Andaman", "Aurangabad", "Ayodhya", "Badrinath", "Bangalore", 
                        "Bhopal", "Bhubaneswar", "Bikaner", "Chandigarh", "Chennai", 
                        "Cherrapunji", "Coimbatore", "Coorg", "Dalhousie", "Darjeeling", 
                        "Dehradun", "Delhi", "Dharamshala", "Dwarka", "Gangtok", 
                        "Goa", "Gokarna", "Gulmarg", "Gurgaon", "Guwahati", 
                        "Gwalior", "Hampi", "Haridwar", "Hyderabad", "Indore", 
                        "Jaipur", "Jaisalmer", "Jammu", "Jodhpur", "Kanpur", 
                        "Kanyakumari", "Kasauli", "Kashmir", "Kedarnath", "Kochi", 
                        "Kodaikanal", "Kolkata", "Kovalam", "Kullu", "Ladakh", 
                        "Lansdowne", "Leh", "Lonavala", "Lucknow", "Madurai", 
                        "Mahabaleshwar", "Manali", "Mangalore", "Mathura", "Mount Abu", 
                        "Mumbai", "Munnar", "Mussoorie", "Mysore", "Nainital", 
                        "Ooty", "Pahalgam", "Patna", "Pondicherry", "Pune", 
                        "Puri", "Pushkar", "Ranchi", "Ranthambore", "Rishikesh", 
                        "Shillong", "Shimla", "Siliguri", "Sonmarg", "Srinagar", 
                        "Surat", "Tirupati", "Trivandrum", "Udaipur", "Ujjain", 
                        "Vadodara", "Varanasi", "Visakhapatnam", "Vrindavan", "Wayanad"
                      ].map((city) {
                        final bool isSelected = localCities.contains(city);
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                               if (city == "All") {
                                 localCities = ["All"];
                               } else {
                                 localCities.remove("All");
                                 if (isSelected) {
                                   localCities.remove(city);
                                   if (localCities.isEmpty) localCities.add("All");
                                 } else {
                                   localCities.add(city);
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
                              city,
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
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2B1564),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCities = localCities;
                          });
                          _fetchCategoryPosts();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Apply Filter",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. TOP CIRCULAR BACK NAV BUTTON ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/back_icon.png',
                        color: const Color(0xff1C0D5A),
                        width: 18.0,
                        height: 18.0,
                      ),
                    ),
                  ),
                ),
              ),

              // --- 2. PREMIUM COLLECTION HEADER TYPOGRAPHY ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: const TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Explore breathtaking wonders uploaded by\nour community.",
                      style: TextStyle(
                        color: Color(0xff4A457A),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- 3. SEARCH BAR AND SLIDER FILTER CONFIG ROW ---
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(25),
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
                                onChanged: (val) {
                                  _searchQuery = val.trim().toLowerCase();
                                  if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
                                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                                    if (mounted) {
                                      _fetchCategoryPosts();
                                    }
                                  });
                                },
                                style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: "Search wonders...",
                                  hintStyle: TextStyle(color: Colors.black26),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => _showFilterSheet(context),
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
              const SizedBox(height: 24),

              // --- 4. HIGH DENSITY MASONRY GRID OVERVIEW ---
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xff2B1564)),
                        ),
                      )
                    : _realPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 36, color: Colors.black38),
                                const SizedBox(height: 12),
                                Text(
                                  "No wonders found in ${widget.categoryName}",
                                  style: const TextStyle(
                                    color: Color(0xff1C0D5A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 4 / 5,
                            ),
                            itemCount: _realPosts.length,
                            itemBuilder: (context, index) {
                              final post = _realPosts[index];
                              final imageUrl = post["image_url"]?.toString() ?? "";
                              final caption = post["caption"]?.toString() ?? "Hidden Wonder";
                              final locationStr = post["location"]?.toString() ?? "Unknown Location";
                              final categoryStr = post["category"]?.toString() ?? widget.categoryName;
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
                                  ).then((_) => _fetchCategoryPosts());
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
    );
  }
}