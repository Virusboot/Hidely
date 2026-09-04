import 'package:flutter/material.dart';
import 'package:hidely_new/config/responsive_breakpoints.dart';
import 'dart:async';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/itinerary_planner_sheet.dart';
import 'package:hidely_new/widgets/empty_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hidely_new/widgets/video_thumbnail_preview.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final List<String> _categories = ["All", "Waterfalls", "Rivers", "Mountains"];
  List<String> _selectedCategories = ["All"]; 

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<String> _selectedCities = ["All"];

  List<dynamic> _filteredPosts = [];
  List<dynamic> _searchResultsUsers = [];
  Timer? _debounceTimer;

  // Personalization recommendation state
  List<String> _userPreferredCategories = [];
  bool _isPersonalizationLoaded = false;

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchExplorePosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }


  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_searches') ?? [];
    searches.remove(query.trim());
    searches.insert(0, query.trim());
    if (searches.length > 10) searches = searches.sublist(0, 10);
    await prefs.setStringList('recent_searches', searches);
  }

  Future<void> _fetchUserPreferences() async {
    if (AuthService().isGuest) {
      _isPersonalizationLoaded = true;
      return;
    }
    try {
      final token = AuthService().token ?? '';
      final savedResult = await ApiService().getSavedPosts(token: token);
      final profileResult = await ApiService().getCreatorProfile(
        username: AuthService().userUsername,
        token: token,
      );

      final Map<String, int> categoryScores = {};

      if (savedResult.success) {
        final List<dynamic> saved = savedResult.data?['bookmarks'] ?? [];
        for (var b in saved) {
          final post = b['post'] ?? b;
          final cat = post['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            categoryScores[cat] = (categoryScores[cat] ?? 0) + 2;
          }
        }
      }

      if (profileResult.success) {
        final List<dynamic> posts = profileResult.data?['posts'] ?? [];
        for (var post in posts) {
          final cat = post['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            categoryScores[cat] = (categoryScores[cat] ?? 0) + 1;
          }
        }
      }

      final sorted = categoryScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _userPreferredCategories = sorted.map((e) => e.key).toList();
          _isPersonalizationLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error fetching personalization preferences: $e");
      if (mounted) {
        setState(() {
          _isPersonalizationLoaded = true;
        });
      }
    }
  }

  Future<void> _fetchExplorePosts() async {
    if (!_isPersonalizationLoaded) {
      await _fetchUserPreferences();
    }
    final token = AuthService().token;

    final result = await ApiService().getExplorePosts(
      category: null, // Fetch all to allow local multi-filtering
      city: null, // Fetch all to allow local multi-filtering
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      sortBy: null,
      token: token,
    );

    List<dynamic> users = [];
    if (_searchQuery.trim().isNotEmpty) {
      final userRes = await ApiService().searchUsers(query: _searchQuery.trim());
      if (userRes.success) {
        users = userRes.data?['users'] as List? ?? [];
      }
    }

    if (mounted) {
      setState(() {
        _searchResultsUsers = users;
        List<dynamic> posts = result.success ? (result.data?['posts'] as List? ?? []) : [];

          
          // Apply local multi-filters BEFORE sorting
          if (!_selectedCategories.contains("All") && _selectedCategories.isNotEmpty) {
            posts = posts.where((p) {
              final cat = (p['category'] ?? '').toString();
              return _selectedCategories.contains(cat);
            }).toList();
          }
          if (!_selectedCities.contains("All") && _selectedCities.isNotEmpty) {
            posts = posts.where((p) {
              final loc = (p['location'] ?? '').toString();
              return _selectedCities.any((city) => loc.contains(city));
            }).toList();
          }

          if (_userPreferredCategories.isNotEmpty) {
            posts.sort((a, b) {
              final catA = a['category']?.toString() ?? '';
              final catB = b['category']?.toString() ?? '';
              
              final indexA = _userPreferredCategories.indexOf(catA);
              final indexB = _userPreferredCategories.indexOf(catB);
              
              if (indexA != -1 && indexB != -1) {
                return indexA.compareTo(indexB);
              } else if (indexA != -1) {
                return -1;
              } else if (indexB != -1) {
                return 1;
              }
              
              final likesA = int.tryParse(a['likes_count']?.toString() ?? '0') ?? 0;
              final likesB = int.tryParse(b['likes_count']?.toString() ?? '0') ?? 0;
              if (likesA != likesB) {
                return likesB.compareTo(likesA);
              }
              
              final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
              final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
              return idB.compareTo(idA);
            });
          } else {
            posts.sort((a, b) {
              final likesA = int.tryParse(a['likes_count']?.toString() ?? '0') ?? 0;
              final likesB = int.tryParse(b['likes_count']?.toString() ?? '0') ?? 0;
              if (likesA != likesB) {
                return likesB.compareTo(likesA);
              }
              
              final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
              final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
              return idB.compareTo(idA);
            });
          }
          _filteredPosts = posts;
        });
      }
  }

  void _filterPosts() {
    _fetchExplorePosts();
  }

  void _showFilterSheet(BuildContext context) {
    List<String> localCategories = List.from(_selectedCategories);
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
                          "Filters & Sorting",
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
                                  localCategories = ["All"];
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
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    
                    
                    // --- Categories ---
                    const Text(
                      "Category (Multi-Select)",
                      style: TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final bool isSelected = localCategories.contains(cat);
                          final bool isLast = index == _categories.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(right: isLast ? 24.0 : 8.0),
                            child: Builder(
                              builder: (chipContext) {
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
                                    Scrollable.ensureVisible(
                                      chipContext,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      alignment: 0.5,
                                    );
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
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Cities ---
                    const Text(
                      "City (Multi-Select)",
                      style: TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Apply Button ---
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
                            _selectedCategories = List.from(localCategories);
                            _selectedCities = localCities;
                          });
                          _filterPosts();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Apply Filters",
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
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // --- 1. SEARCH BAR & AI TOOLS IN A ROW ---
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 6.0, bottom: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                              _fetchExplorePosts();
                            });
                          },
                          onSubmitted: (val) {
                            _saveSearchQuery(val);
                            _fetchExplorePosts();
                          },
                          decoration: InputDecoration(
                            hintText: "Ask AI e.g. Delhi ke paas hidden waterfall...",
                            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: Color(0xff1C0D5A), size: 20),
                             suffixIcon: IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 20),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const ItineraryPlannerSheet(locationName: "Trip Destinations"),
                                );
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showFilterSheet(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.tune_rounded, color: Color(0xff1C0D5A), size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Instagram-Style Professional Accounts Search Results List ---
              if (_searchQuery.trim().isNotEmpty && _searchResultsUsers.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Accounts",
                              style: TextStyle(
                                color: Color(0xff1C0D5A),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              "${_searchResultsUsers.length} found",
                              style: TextStyle(
                                color: const Color(0xff1C0D5A).withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xffF1F5F9)),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResultsUsers.length > 5 ? 5 : _searchResultsUsers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 68, color: Color(0xffF8FAFC)),
                        itemBuilder: (context, idx) {
                          final u = _searchResultsUsers[idx];
                          final uname = u['username']?.toString() ?? 'user';
                          final name = u['name']?.toString() ?? uname;
                          final bio = u['bio']?.toString() ?? '';
                          final avatar = u['profile_picture']?.toString() ?? '';
                          final bool isVerified = u['is_verified'] == true || u['is_verified'] == 1 || u['is_verified'] == 'true';

                          return InkWell(
                            borderRadius: idx == 0
                                ? const BorderRadius.vertical(top: Radius.circular(0))
                                : (idx == (_searchResultsUsers.length > 5 ? 4 : _searchResultsUsers.length - 1)
                                    ? const BorderRadius.vertical(bottom: Radius.circular(20))
                                    : BorderRadius.zero),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreatorProfileScreen(username: uname),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Instagram Style Gradient Ring Avatar
                                  Container(
                                    padding: const EdgeInsets.all(2.0),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xff833AB4), Color(0xffFD1D1D), Color(0xffF56040)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: UserAvatar(
                                        avatarUrl: avatar,
                                        displayName: uname,
                                        radius: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                uname,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xff1C0D5A),
                                                ),
                                              ),
                                            ),
                                            if (isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified_rounded,
                                                color: Color(0xff3897F0),
                                                size: 15,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          name.isNotEmpty && name.toLowerCase() != uname.toLowerCase() ? name : (bio.isNotEmpty ? bio : "Creator"),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black.withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff2B1564),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      "View",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // --- 3. STAGGERED PINTEREST-STYLE GRID DISPLAY ---
              Expanded(
                child: (_filteredPosts.isEmpty && _searchResultsUsers.isEmpty)
                    ? EmptyStateWidget(
                        icon: Icons.landscape_outlined,
                        title: "No Hidden Places Found",
                        description: "No matching destinations found. Try resetting your search or filters.",
                        actionLabel: "Reset Search & Retry",
                        onAction: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                            _selectedCategories = ["All"];
                            _selectedCities = ["All"];
                          });
                          _fetchExplorePosts();
                        },
                      )
                    : GridView.builder(
                        cacheExtent: 1000.0,
                        padding: EdgeInsets.only(
                          left: 0.0,
                          right: 0.0,
                          top: 4.0,
                          bottom: 120 + MediaQuery.of(context).padding.bottom,
                        ),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ResponsiveBreakpoints.isLargeDesktop(context)
                              ? 6
                              : ResponsiveBreakpoints.isDesktop(context)
                                  ? 5
                                  : ResponsiveBreakpoints.isTablet(context)
                                      ? 4
                                      : 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
                          final imageUrl = post["image_url"]?.toString() ?? "";
                          final caption = post["caption"]?.toString() ?? "Tiger Hills Water Fall";
                          final locationStr = post["location"]?.toString() ?? "Nenital, Uttrakhand";
                          final categoryStr = post["category"]?.toString() ?? "Waterfalls";

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
                              ).then((_) => _fetchExplorePosts());
                            },
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                color: Color(0xffF1F5F9),
                              ),
                              child: isVideo
                                  ? VideoThumbnailPreview(
                                      videoUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : isNetwork
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl.startsWith("http") ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      memCacheWidth: 600,
                                      alignment: Alignment.center,
                                      placeholder: (context, url) => Container(color: const Color(0xffF1F5F9)),
                                      errorWidget: (context, url, error) => Container(
                                        color: const Color(0xffCBD5E1),
                                        child: const Icon(Icons.landscape_outlined, color: Colors.white38),
                                      ),
                                    )
                                  : Image.asset(
                                      imageUrl.isNotEmpty ? imageUrl : "assets/images/onboarding_bg.jpg",
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      alignment: Alignment.center,
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