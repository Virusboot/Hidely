import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/create_media_screen.dart';
import 'edit_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'follow_list_screen.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'settings_and_privacy_screen.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidely_new/widgets/empty_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserProfileScreen extends StatefulWidget {
  final bool isFromLeaderboard;
  const UserProfileScreen({super.key, this.isFromLeaderboard = false});

  // ignore: library_private_types_in_public_api
  static _UserProfileScreenState? activeState;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  String _username = '';
  String _name = '';
  String _bio = '';
  String _pronouns = '';
  String _profilePic = '';

  String get _cleanBio {
    String clean = _bio;
    final RegExp linkLineReg = RegExp(r'^[a-zA-Z0-9_\s]+:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
    final lines = clean.split('\n').where((line) => !linkLineReg.hasMatch(line.trim()));
    return lines.join('\n').trim();
  }

  List<Map<String, String>> get _allProfileLinks {
    List<Map<String, String>> list = [];
    final lines = _bio.split('\n');
    for (var line in lines) {
      final match = RegExp(r'^([^:\n]+):\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false).firstMatch(line.trim());
      if (match != null) {
        String key = match.group(1)?.trim() ?? '';
        String val = match.group(2)?.trim() ?? '';
        if (key.toLowerCase() == 'instagram') {
          if (!val.startsWith('http')) {
            if (val.startsWith('@')) val = val.substring(1);
            val = 'https://instagram.com/$val';
          }
          list.add({'title': 'Instagram', 'url': val, 'type': 'instagram'});
        } else if (key.toLowerCase() == 'youtube') {
          if (!val.startsWith('http')) {
            if (val.startsWith('@')) val = val.substring(1);
            val = 'https://youtube.com/@$val';
          }
          list.add({'title': 'YouTube', 'url': val, 'type': 'youtube'});
        } else {
          if (!val.startsWith('http')) val = 'https://$val';
          list.add({'title': key, 'url': val, 'type': 'website'});
        }
      }
    }
    return list;
  }


  int _postsCount = 0;
  int _followersCount = 0;
  int _followingsCount = 0;
  List<dynamic> _userPosts = [];
  List<dynamic> _savedPosts = [];
  String _rankBadge = "NOVICE";

  @override
  void initState() {
    super.initState();
    UserProfileScreen.activeState = this;
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    if (UserProfileScreen.activeState == this) {
      UserProfileScreen.activeState = null;
    }
    _tabController.dispose();
    super.dispose();
  }

  void reload() {
    _loadProfileData();
  }

  void removePostLocally(int postId) {
    setState(() {
      _userPosts.removeWhere((p) => p['id'] == postId || p['id']?.toString() == postId.toString());
      _postsCount = _userPosts.length;
    });
  }

  Future<void> _loadProfileData() async {
    final token = AuthService().token ?? '';
    final activeUsername = AuthService().userUsername;

    setState(() {
      _isLoading = true;
      if (activeUsername.isNotEmpty) {
        _username = activeUsername;
        _name = AuthService().userName.isNotEmpty ? AuthService().userName : activeUsername;
      }
    });

    // Check if logged in as Official Admin Account
    if (_username == 'hidely_official' || _username == 'hidely' || activeUsername == 'hidely_official' || activeUsername == 'hidely') {
      if (mounted) {
        setState(() {
          _username = 'hidely_official';
          _name = 'Hidely Official';
          _bio = 'Official Hidely App Account. Exploring the world\'s most breathtaking places! 🌍✨';
          _followersCount = 12800;
          _followingsCount = 42;
        });
      }
      try {
        final postsResult = await ApiService().getUserPosts(userId: '1', token: token);
        if (postsResult.success && mounted) {
          setState(() {
            _userPosts = (postsResult.data?['posts'] as List?) ?? [];
            _postsCount = _userPosts.length;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('[UserProfileScreen] Error loading admin posts: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    try {
      // Load profile
      final profileResult = await ApiService().getUserProfile(token: token);
      if (profileResult.success) {
        final userData = profileResult.data?['user'];
        if (userData != null) {
          await AuthService().login(token, userData); // Update global session with latest data
          _username = userData['username'] ?? '';
          _name = userData['name'] ?? '';
          _bio = userData['bio'] ?? '';
          _pronouns = userData['pronouns'] ?? '';
          _profilePic = userData['profile_picture'] ?? '';
          _postsCount = userData['posts_count'] ?? 0;
          _followersCount = userData['followers_count'] ?? 0;
          _followingsCount = userData['followings_count'] ?? 0;
        }
      }

      // Try fetching posts robustly to avoid any ID mismatch issues
      bool postsLoaded = false;
      
      // 1. Check if posts were returned inline with the profile request
      if (profileResult.success && profileResult.data?['posts'] != null) {
        _userPosts = (profileResult.data?['posts'] as List?) ?? [];
        if (_userPosts.isNotEmpty) postsLoaded = true;
      }

      // 2. Fallback: Fetch via the public profile endpoint using username
      if (!postsLoaded && _username.isNotEmpty) {
        final publicResult = await ApiService().getCreatorProfile(username: _username, token: token);
        if (publicResult.success) {
          final creator = publicResult.data?['creator'];
          if (!profileResult.success && creator != null) {
            _name = creator['name'] ?? _name;
            _bio = creator['bio'] ?? '';
            _pronouns = creator['pronouns'] ?? '';
            _profilePic = creator['profile_picture'] ?? '';
            _followersCount = creator['followers_count'] ?? 0;
            _followingsCount = creator['followings_count'] ?? 0;
          }
          final publicPosts = publicResult.data?['posts'] as List?;
          if (publicPosts != null && publicPosts.isNotEmpty) {
            _userPosts = publicPosts;
            postsLoaded = true;
          } else {
            // 3. Fallback: Use the exact ID returned by the public profile
            final exactId = creator?['id']?.toString() ?? creator?['_id']?.toString();
            if (exactId != null && exactId.isNotEmpty) {
              final postsResult = await ApiService().getUserPosts(userId: exactId, token: token);
              if (postsResult.success && postsResult.data?['posts'] != null) {
                _userPosts = (postsResult.data?['posts'] as List?) ?? [];
                if (_userPosts.isNotEmpty) postsLoaded = true;
              }
            }
          }
        }
      }

      // 4. Last resort: Fetch using AuthService().userId
      if (!postsLoaded) {
        final postsResult = await ApiService().getUserPosts(
          userId: AuthService().userId,
          token: token,
        );
        if (postsResult.success && postsResult.data?['posts'] != null) {
          _userPosts = (postsResult.data?['posts'] as List?) ?? [];
        }
      }

      // Handle hidely_official Admin Profile Data & Location-wise Posts
      if (_username == 'hidely_official' || _username == 'hidely') {
        if (_userPosts.isEmpty) {
          final exploreResult = await ApiService().getExplorePosts(token: token);
          if (exploreResult.success && exploreResult.data?['posts'] != null) {
            _userPosts = (exploreResult.data?['posts'] as List?) ?? [];
          }
        }
      }

      if (_userPosts.length > _postsCount) {
        _postsCount = _userPosts.length;
      }

      // Load saved posts
      final savedResult = await ApiService().getSavedPosts(token: token);
      if (savedResult.success) {
        // Check multiple keys to be extremely resilient to backend schema changes
        final savedList = savedResult.data?['saved'] ?? 
                          savedResult.data?['bookmarks'] ?? 
                          savedResult.data?['posts'] ?? 
                          (savedResult.data is List ? savedResult.data : null);
        if (savedList != null) {
          _savedPosts = savedList as List;
        }
      }

      // Fetch leaderboard to get rank
      final lbResult = await ApiService().getLeaderboard();
      if (lbResult.success) {
        final lb = lbResult.data?['leaderboard'] as List? ?? [];
        int rankIndex = lb.indexWhere((u) {
          if (u is Map) {
            return u['id']?.toString() == AuthService().userId;
          }
          return false;
        });
        // Assign numeric Rank tag based on leaderboard position
        if (_postsCount > 0 && rankIndex >= 0) {
          _rankBadge = "RANK ${rankIndex + 1}";
        } else if (_postsCount > 0) {
          _rankBadge = "RANK ${lb.length + 1}";
        } else {
          _rankBadge = "NOVICE";
        }
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Error loading profile data: $e');
    }

    _userPosts = _userPosts.where((p) => !AuthService().isPostDeletedLocally(p['id'])).toList();
    _savedPosts = _savedPosts.where((p) => !AuthService().isPostDeletedLocally(p['id'])).toList();
    _postsCount = _userPosts.length;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
              Color(0xffFDF7FF),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. TOP BRAND HEADER BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: widget.isFromLeaderboard
                            ? GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/back_icon.png',
                                    color: const Color(0xff1C0D5A),
                                    width: 22.0,
                                    height: 22.0,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CreateMediaScreen(),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.add,
                                  color: Color(0xff1C0D5A),
                                  size: 26,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _username.isNotEmpty 
                            ? _username 
                            : (AuthService().userUsername.isNotEmpty 
                                ? AuthService().userUsername 
                                : 'User'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsAndPrivacyScreen(),
                          ),
                        ).then((_) => _loadProfileData());
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                          child: Image.asset(
                            'assets/icons/Menu.png',
                            color: const Color(0xff1C0D5A),
                            width: 22,
                            height: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. PROFILE PICTURE & STATS (GOLD RANK) ---
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.0),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                Color(0xff4F46E5),
                                Color(0xff9333EA)
                              ])),
                          child: UserAvatar(
                            avatarUrl: _profilePic,
                            displayName: _name.isNotEmpty ? _name : _username,
                            radius: 42,
                            fontSize: 32,
                          ),
                        ),
                        Positioned(
                          bottom: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xff2B1564),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              _rankBadge,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMetaStatColumn("$_postsCount", "hidelys"),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowListScreen(
                                    username: _username.isNotEmpty ? _username : AuthService().userUsername,
                                    initialTab: 0,
                                    isMe: true,
                                  ),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                            child: _buildMetaStatColumn("$_followersCount", "followers"),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowListScreen(
                                    username: _username.isNotEmpty ? _username : AuthService().userUsername,
                                    initialTab: 1,
                                    isMe: true,
                                  ),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                            child: _buildMetaStatColumn("$_followingsCount", "following"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- 3. BIO PANEL ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _name.isNotEmpty ? _name : AuthService().userName,
                          style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        if (_username == 'hidely_official' || _username == 'hidely') ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Color(0xff2563EB), size: 18),
                        ],
                        if (_pronouns.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '($_pronouns)',
                            style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ]
                      ],
                    ),
                    if (_cleanBio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _cleanBio,
                        style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.75),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (_allProfileLinks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final link in _allProfileLinks)
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(link['url']!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (link['type'] == 'instagram')
                                      Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png',
                                        width: 14,
                                        height: 14,
                                      )
                                    else if (link['type'] == 'youtube')
                                      Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png',
                                        width: 16,
                                        height: 11,
                                      )
                                    else
                                      const Icon(Icons.link_rounded, size: 14, color: Color(0xff2563EB)),
                                    const SizedBox(width: 6),
                                    Text(
                                      link['title']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),



              const SizedBox(height: 20),

              // --- 4. ACTION BUTTONS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    // Edit Profile Button
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12)),
                        child: TextButton(
                          onPressed: () async {
                            // Edit screen se return hone ka wait karo
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const EditProfileScreen()),
                            );

                            // Agar edit hua, toh profile data refresh karo (profile pic + bio sab)
                            if (result == true) {
                              _loadProfileData();
                            }
                          },
                          child: const Text("Edit Profile",
                              style: TextStyle(
                                  color: Color(0xff1C0D5A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // View Leaderboard Button
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xff2B1564), // Primary app filled button color
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LeaderboardScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "View Leaderboard",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- 5. TABS ROW ---
              Container(
                color: Colors.white.withOpacity(0.4),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0.0,
                  indicatorColor: const Color(0xff2B1564),
                  labelColor: const Color(0xff2B1564),
                  unselectedLabelColor: Colors.black38,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_view_rounded, size: 22)),
                    Tab(icon: Icon(Icons.movie_creation_outlined, size: 22)),
                    Tab(icon: Icon(Icons.bookmark_border_rounded, size: 22)),
                  ],
                ),
              ),

              // --- 6. MASONRY DISPLAY CANVAS ---
              Expanded(
                child: _isLoading && _userPosts.isEmpty
                    ? const SizedBox.shrink()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPersonalGridStream(),
                          const EmptyStateWidget(
                            icon: Icons.movie_creation_outlined,
                            title: "No Reels Yet",
                            description: "Capture and share your cinematic moments!",
                          ),
                          _buildSavedGridStream(),
                        ],
                      ),
              ),
              SizedBox(
                  height: 110 +
                      MediaQuery.of(context)
                          .padding
                          .bottom), // Clearance for the floating bottom nav bar
            ],
          ),
        ),
      ),
    ),);
  }


  String _formatCompactCount(dynamic number) {
    if (number == null) return '0';
    if (number is String) {
      final parsed = num.tryParse(number);
      if (parsed == null) return number;
      number = parsed;
    }
    final num val = number as num;
    if (val >= 1000000000) {
      double res = val / 1000000000;
      String str = res.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}B';
    } else if (val >= 1000000) {
      double res = val / 1000000;
      String str = res.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}M';
    } else if (val >= 1000) {
      double res = val / 1000;
      String str = res.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}k';
    } else {
      return val.toInt().toString();
    }
  }

  Widget _buildMetaStatColumn(String count, String label) {
    final formattedCount = _formatCompactCount(count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formattedCount,
            style: const TextStyle(
                color: Color(0xff1C0D5A),
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.black38,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPersonalGridStream() {
    if (_userPosts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.photo_library_outlined,
        title: "No Posts Yet",
        description: "Upload your first travel memory!",
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      cacheExtent: 1000,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 4 / 5,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final String imagePath = post["image_url"]?.toString() ?? post["image"]?.toString() ?? "";
        final String lowerPath = imagePath.toLowerCase();
        final bool isVideo = lowerPath.endsWith('.mp4') || lowerPath.endsWith('.mov') || lowerPath.endsWith('.mkv') || lowerPath.endsWith('.avi');
        final bool isNetwork = lowerPath.startsWith("http") || lowerPath.startsWith("https") || lowerPath.startsWith("uploads") || lowerPath.startsWith("/uploads") || lowerPath.startsWith("/");
        final bool hasImage = imagePath.isNotEmpty;

        return GestureDetector(
          onTap: () {
            final mappedPosts = _userPosts.map((p) {
              final Map<String, dynamic> pm = Map<String, dynamic>.from(p);
              if (pm["author_username"] == null) {
                pm["author_username"] = AuthService().userUsername;
              }
              if (pm["author_profile_picture"] == null) {
                pm["author_profile_picture"] = AuthService().userProfilePicture;
              }
              return pm;
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SinglePostViewScreen(
                  posts: mappedPosts,
                  initialIndex: index,
                ),
              ),
            ).then((_) {
              _loadProfileData();
            });
          },
          child: Container(
            color: const Color(0xffCBD5E1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                !hasImage
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 20),
                            SizedBox(height: 4),
                            Text(
                              "No Image",
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : isVideo
                        ? const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40),
                          )
                        : isNetwork
                            ? SizedBox.expand(
                                child: CachedNetworkImage(
                                  imageUrl: (lowerPath.startsWith("http") || lowerPath.startsWith("https"))
                                      ? imagePath
                                      : '${ApiService().baseUrl}/${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  memCacheWidth: 600,
                                  placeholder: (context, url) => Container(color: const Color(0xffF1F5F9)),
                                  errorWidget: (context, url, error) => const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                  ),
                                ),
                              )
                            : SizedBox.expand(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                  ),
                                ),
                              ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedGridStream() {
    if (_savedPosts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.bookmark_border_rounded,
        title: "No Saved Posts Yet",
        description: "Posts you bookmark will appear here.",
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      cacheExtent: 1000,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 4 / 5,
      ),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final rawPost = _savedPosts[index];
        // Resolve nested 'post' relation if present (typical in bookmark schema)
        final Map<String, dynamic> post = rawPost is Map && rawPost["post"] != null && rawPost["post"] is Map
            ? Map<String, dynamic>.from(rawPost["post"] as Map)
            : Map<String, dynamic>.from(rawPost as Map);

        final String imagePath = post["image_url"]?.toString() ?? post["image"]?.toString() ?? "";
        final String lowerPath = imagePath.toLowerCase();
        final bool isNetwork = lowerPath.startsWith("http") || lowerPath.startsWith("https") || lowerPath.startsWith("uploads") || lowerPath.startsWith("/uploads") || lowerPath.startsWith("/");
        final bool hasImage = imagePath.isNotEmpty;

        return GestureDetector(
          onTap: () {
            final mappedPosts = _savedPosts.map((raw) {
              return raw is Map && raw["post"] != null && raw["post"] is Map
                  ? Map<String, dynamic>.from(raw["post"] as Map)
                  : Map<String, dynamic>.from(raw as Map);
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SinglePostViewScreen(
                  posts: mappedPosts,
                  initialIndex: index,
                ),
              ),
            ).then((_) {
              _loadProfileData();
            });
          },
          child: Hero(
            tag: 'saved_post_${post["id"]}',
            child: Container(
              color: const Color(0xffCBD5E1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  !hasImage
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 20),
                              SizedBox(height: 4),
                              Text(
                                "No Image",
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : isNetwork
                          ? SizedBox.expand(
                              child: CachedNetworkImage(
                                imageUrl: (lowerPath.startsWith("http") || lowerPath.startsWith("https"))
                                    ? imagePath
                                    : '${ApiService().baseUrl}/${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                memCacheWidth: 600,
                                placeholder: (context, url) => Container(color: const Color(0xffF1F5F9)),
                                errorWidget: (context, url, error) => const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                ),
                              ),
                            )
                          : SizedBox.expand(
                              child: Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                ),
                              ),
                            ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
