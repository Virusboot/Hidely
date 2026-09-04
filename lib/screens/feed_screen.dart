import 'package:flutter/material.dart';
import 'package:hidely_new/config/responsive_breakpoints.dart';
import 'package:hidely_new/screens/notification_screen.dart';
import 'package:hidely_new/screens/create_media_screen.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/feed_video_player.dart';
import 'package:hidely_new/screens/category_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/widgets/post_options_bottom_sheet.dart';
import 'package:hidely_new/widgets/skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  static final List<Map<String, dynamic>> mockPosts = [];
  static List<dynamic>? _cachedFeedPosts;

  // ignore: library_private_types_in_public_api
  static _FeedScreenState? activeState;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isLoading = true;
  List<dynamic> _feedPosts = [];
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    FeedScreen.activeState = this;

    final initialCached = AuthService().cachedFeed ?? FeedScreen._cachedFeedPosts;
    if (initialCached != null && initialCached.isNotEmpty) {
      _feedPosts = List.from(initialCached);
      _isLoading = false;
    } else {
      _isLoading = true;
      AuthService().loadCachedFeed().then((diskFeed) {
        if (mounted && _feedPosts.isEmpty && diskFeed.isNotEmpty) {
          setState(() {
            _feedPosts = List.from(diskFeed);
            _isLoading = false;
          });
        }
      });
    }

    _loadFeed(showLoading: _feedPosts.isEmpty);
    _loadUnreadCount();
  }

  void _performOptimisticLike(Map<String, dynamic> post) {
    if (AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'like a post');
      return;
    }

    HapticFeedback.lightImpact();
    final bool currentLiked = post["is_liked"] == true || post["isLiked"] == true;
    final int currentCount = (post["likes_count"] ?? post["likes"] ?? 0) as int;
    final int nextCount = currentLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1;

    setState(() {
      post["is_liked"] = !currentLiked;
      post["isLiked"] = !currentLiked;
      post["likes_count"] = nextCount;
      post["likes"] = nextCount;
    });

    final id = post["id"];
    if (id is int) {
      final token = AuthService().token ?? '';
      ApiService().toggleLikePost(token: token, postId: id).then((result) {
        if (result.success && mounted) {
          setState(() {
            post["is_liked"] = result.data?["is_liked"] ?? !currentLiked;
            post["isLiked"] = result.data?["is_liked"] ?? !currentLiked;
            post["likes_count"] = result.data?["likes_count"] ?? nextCount;
            post["likes"] = result.data?["likes_count"] ?? nextCount;
          });
        } else if (!result.success && mounted) {
          setState(() {
            post["is_liked"] = currentLiked;
            post["isLiked"] = currentLiked;
            post["likes_count"] = currentCount;
            post["likes"] = currentCount;
          });
        }
      });
    }
  }

  void _performOptimisticSave(Map<String, dynamic> post) {
    if (AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'save a post');
      return;
    }

    HapticFeedback.lightImpact();
    final bool currentSaved = post["is_bookmarked"] == true || post["isBookmarked"] == true;

    setState(() {
      post["is_bookmarked"] = !currentSaved;
      post["isBookmarked"] = !currentSaved;
    });

    final id = post["id"];
    if (id is int) {
      final token = AuthService().token ?? '';
      ApiService().toggleBookmarkPost(token: token, postId: id).then((result) {
        if (result.success && mounted) {
          setState(() {
            post["is_bookmarked"] = result.data?["is_bookmarked"] ?? !currentSaved;
            post["isBookmarked"] = result.data?["is_bookmarked"] ?? !currentSaved;
          });
        } else if (!result.success && mounted) {
          setState(() {
            post["is_bookmarked"] = currentSaved;
            post["isBookmarked"] = currentSaved;
          });
        }
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    if (AuthService().isGuest) return;
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;
    final result = await ApiService().getUnreadNotificationCount(token: token);
    if (mounted && result.success) {
      setState(() {
        _unreadNotificationCount = result.data?['unread_count'] ?? 0;
      });
    }
  }

  void reload() {
    _loadFeed();
  }

  void removePostLocally(int postId) {
    setState(() {
      _feedPosts.removeWhere((p) => p['id'] == postId || p['id']?.toString() == postId.toString());
    });
  }

  void _showPostOptionsSheet(BuildContext context, dynamic post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PostOptionsBottomSheet(post: post),
    );
  }

  @override
  void dispose() {
    if (FeedScreen.activeState == this) {
      FeedScreen.activeState = null;
    }
    super.dispose();
  }

  Future<void> _loadFeed({bool showLoading = true}) async {
    if (showLoading && _feedPosts.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    final token = AuthService().token;
    final ApiResult result = await ApiService().getFeedPosts(token: token);

    if (!mounted) return;

    List<dynamic> serverFeed = [];
    if (result.success) {
      final feedList = result.data?['feed'] ?? result.data?['posts'];
      if (feedList != null && feedList is List) {
        serverFeed = feedList;
      }
    }

    final mixedFeed = _mixFeedAlgorithm(serverFeed, []);
    final cleanFeed = mixedFeed.where((p) => !AuthService().isPostDeletedLocally(p['id'])).toList();

    if (cleanFeed.isNotEmpty) {
      FeedScreen._cachedFeedPosts = cleanFeed;
      AuthService().saveCachedFeed(cleanFeed);
    }

    setState(() {
      _feedPosts = cleanFeed;
      _isLoading = false;
    });
  }

  List<dynamic> _mixFeedAlgorithm(List<dynamic> serverPosts, List<dynamic> officialPosts) {
    // 1. Combine all available server posts and official posts without duplicates
    final Set<String> seenIds = {};
    final List<dynamic> allPosts = [];

    for (final post in serverPosts) {
      final id = (post['id'] ?? '').toString();
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        allPosts.add(post);
      }
    }

    for (final post in officialPosts) {
      final id = (post['id'] ?? '').toString();
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        allPosts.add(post);
      }
    }

    // 2. Assign Priority Tier (1 = Highest Quality Priority, 5 = General/New)
    // Hierarchy:
    // Priority 1: Official Hidely Posts
    // Priority 2: Verified Creators
    // Priority 3: Nearby Places
    // Priority 4: Friends / Following
    // Priority 5: New Creators
    int getPriorityTier(dynamic post) {
      final username = (post['author_username'] ?? post['username'] ?? post['author'] ?? '').toString().toLowerCase();
      final isOfficial = post['is_official'] == true ||
          post['isOfficial'] == true ||
          username == 'hidely_official' ||
          username == 'hidely';
      if (isOfficial) return 1;

      final isVerified = post['is_verified'] == true ||
          post['isVerified'] == true ||
          post['author_is_verified'] == true ||
          (post['user'] is Map && post['user']['is_verified'] == true);
      if (isVerified) return 2;

      final isNearby = post['is_nearby'] == true ||
          post['isNearby'] == true ||
          (post['distance'] != null && (post['distance'] as num) < 50000);
      if (isNearby) return 3;

      final isFollowing = post['is_following'] == true || post['isFollowing'] == true;
      if (isFollowing) return 4;

      return 5; // New Creators / General posts
    }

    // 3. Bucket posts into their respective priority levels
    final Map<int, List<dynamic>> priorityBuckets = {1: [], 2: [], 3: [], 4: [], 5: []};
    for (final post in allPosts) {
      final tier = getPriorityTier(post);
      priorityBuckets[tier]!.add(post);
    }

    // 4. Sort posts within each priority tier by date (newest first)
    for (final tier in priorityBuckets.keys) {
      priorityBuckets[tier]!.sort((a, b) {
        final aDateStr = a['created_at'] ?? a['createdAt'];
        final bDateStr = b['created_at'] ?? b['createdAt'];
        if (aDateStr != null && bDateStr != null) {
          try {
            final DateTime aDate = DateTime.parse(aDateStr.toString());
            final DateTime bDate = DateTime.parse(bDateStr.toString());
            return bDate.compareTo(aDate);
          } catch (_) {}
        }
        final aId = int.tryParse(a['id']?.toString() ?? '') ?? 0;
        final bId = int.tryParse(b['id']?.toString() ?? '') ?? 0;
        return bId.compareTo(aId);
      });
    }

    // 5. Construct final feed following Priority Tiers with author-interleaving
    final List<dynamic> finalFeed = [];

    for (int tier = 1; tier <= 5; tier++) {
      final tierPosts = priorityBuckets[tier]!;
      if (tierPosts.isEmpty) continue;

      // Interleave author posts within each tier to prevent back-to-back same creator posts
      final Map<String, List<dynamic>> authorBuckets = {};
      for (final p in tierPosts) {
        final author = (p['author_username'] ?? p['username'] ?? '').toString();
        authorBuckets.putIfAbsent(author, () => []).add(p);
      }

      String lastAuthor = finalFeed.isNotEmpty
          ? (finalFeed.last['author_username'] ?? finalFeed.last['username'] ?? '').toString()
          : '';

      while (authorBuckets.isNotEmpty) {
        String? nextAuthor;
        for (final author in authorBuckets.keys) {
          if (author != lastAuthor) {
            nextAuthor = author;
            break;
          }
        }
        if (nextAuthor == null && authorBuckets.isNotEmpty) {
          nextAuthor = authorBuckets.keys.first;
        }

        if (nextAuthor != null) {
          final authorPosts = authorBuckets[nextAuthor]!;
          finalFeed.add(authorPosts.removeAt(0));
          if (authorPosts.isEmpty) {
            authorBuckets.remove(nextAuthor);
          }
          lastAuthor = nextAuthor;
        }
      }
    }

    return finalFeed;
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
        body: Builder(builder: (context) {
          final bool isDesktopOrTablet = ResponsiveBreakpoints.isDesktopOrTablet(context);
          return Container(
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
              child: ResponsiveContainer(
                maxWidth: 680.0,
                child: Stack(
                  children: [
                  _feedPosts.isEmpty && _isLoading
                      ? ListView.builder(
                          itemCount: 4,
                          itemBuilder: (context, index) => const SkeletonFeedCard(),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadFeed,
                          color: const Color(0xff2B1564),
                          child: ListView.builder(
                            cacheExtent: 1500.0,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: _feedPosts.length + 3,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // On desktop/web: top bar is in sidebar — hide here
                                if (isDesktopOrTablet) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          // Upload requires login
                                          if (AuthService().isGuest) {
                                            showLoginRequiredSheet(context, reason: 'upload a post');
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const CreateMediaScreen(),
                                            ),
                                          );
                                        },
                                        child: const Icon(Icons.add,
                                            color: Color(0xff1C0D5A), size: 26),
                                      ),
                                      Image.asset(
                                        'assets/images/logo_horizontal_color.png',
                                        height: 32,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Text(
                                          'hidely',
                                          style: TextStyle(
                                            color: Color(0xff1C0D5A),
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const NotificationScreen()),
                                          ).then((_) => _loadUnreadCount());
                                        },
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.7),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white.withOpacity(0.5)),
                                              ),
                                              child: const Icon(
                                                  Icons.notifications_none_outlined,
                                                  color: Color(0xff1C0D5A),
                                                  size: 22),
                                            ),
                                            if (_unreadNotificationCount > 0)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: Container(
                                                  constraints: const BoxConstraints(
                                                    minWidth: 17,
                                                    minHeight: 17,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFE91E63),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      _unreadNotificationCount > 99
                                                          ? '99+'
                                                          : '$_unreadNotificationCount',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (index == 1) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 105,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        children: [
                                          _buildStoryItem(context, "Waterfall",
                                              "assets/images/explore_2.png"),
                                          _buildStoryItem(context, "Mountains",
                                              "assets/images/onboarding_1.jpg"),
                                          _buildStoryItem(context, "Rivers",
                                              "assets/images/onboarding_3.jpg"),
                                          _buildStoryItem(
                                              context, "Temples", "assets/images/explore_5.png"),
                                          _buildStoryItem(
                                              context, "Forts", "assets/images/explore_7.png"),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              } else if (index == _feedPosts.length + 2) {
                                return SizedBox(height: 120 + MediaQuery.of(context).padding.bottom);
                              } else {
                                final postData = _feedPosts[index - 2];
                                return _buildMediaPostCard(context, postData);
                              }
                            },
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }


  Widget _buildStoryItem(BuildContext context, String title, String imgPath) {
    return Padding(
      padding: const EdgeInsets.only(right: 14.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryScreen(categoryName: title),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3.0),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xff4F46E5),
                    Color(0xff06B6D4),
                    Color(0xff9333EA)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.0),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      imgPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1C0D5A))),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPostCard(BuildContext context, Map<String, dynamic> post) {
    final id = post["id"];
    final String caption = post["caption"] ?? "";
    final String location = post["location"] ?? "Unknown";
    String displayLocation = location;
    if (location.contains(',')) {
      final parts = location.split(',');
      if (parts.isNotEmpty) {
        final lastPart = parts.last.trim();
        final upperLast = lastPart.toUpperCase();
        if ((upperLast == "USA" || upperLast == "US" || upperLast == "INDIA" || upperLast == "UK" || lastPart.length <= 2) && parts.length > 1) {
          displayLocation = parts[parts.length - 2].trim();
        } else {
          displayLocation = lastPart;
        }
      }
    }
    final int likes = post["likes_count"] ?? post["likes"] ?? 0;
    
    // Check if liked
    final bool isLiked = post["is_liked"] ?? post["isLiked"] ?? false;
    final bool isBookmarked = post["is_bookmarked"] ?? post["isBookmarked"] ?? false;
    
    // Author details
    final String authorUsername = post["author_username"] ?? post["username"] ?? (post["isAsset"] == true ? "hidely_official" : AuthService().userUsername);
    final String? authorPic = post["author_profile_picture"] ?? AuthService().userProfilePicture;
    final bool isVerified = authorUsername == 'hidely_official' || authorUsername == 'hidely' || post["is_verified"] == true;

    // Image configuration
    final String imageUrl = post["image_url"] ?? (post["image"] is String ? post["image"] : "");
    final bool isAsset = post["isAsset"] ?? (imageUrl.startsWith("assets/") == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (authorUsername == AuthService().userUsername) {
                    MainWrapperState.activeState?.setIndex(4);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatorProfileScreen(
                          username: authorUsername,
                          avatarPath: authorPic != null && authorPic.isNotEmpty
                              ? (authorPic.startsWith('http') ? authorPic : '${ApiService().baseUrl}/$authorPic')
                              : "assets/images/nomad_nate_avatar.png",
                          rank: "Official",
                        ),
                      ),
                    );
                  }
                },
                child: UserAvatar(
                  avatarUrl: authorPic,
                  displayName: authorUsername,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (authorUsername == AuthService().userUsername) {
                          MainWrapperState.activeState?.setIndex(4);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatorProfileScreen(
                                username: authorUsername,
                                avatarPath: authorPic != null && authorPic.isNotEmpty
                                    ? (authorPic.startsWith('http') ? authorPic : '${ApiService().baseUrl}/$authorPic')
                                    : "assets/images/nomad_nate_avatar.png",
                                rank: "Official",
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            authorUsername,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Colors.black87),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Color(0xff2563EB), size: 15),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationDetailScreen(
                                    title: post["title"] ?? location,
                                    location: location,
                                    image: isAsset 
                                        ? imageUrl 
                                        : (imageUrl.toLowerCase().startsWith("http") || imageUrl.toLowerCase().startsWith("https"))
                                            ? imageUrl
                                            : '${ApiService().baseUrl}/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}',
                                    category: post["category"] ?? "All",
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: Color(0xff2B1564)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    "Suggested For You • $displayLocation ",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showPostOptionsSheet(context, post),
                child: Image.asset(
                  'assets/icons/Menu.png',
                  width: 20,
                  height: 20,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            GestureDetector(
              onDoubleTap: () {
                _performOptimisticLike(post);
              },
              child: () {
                final path = imageUrl.toLowerCase();
                final bool isLocalVideo = post["image"] is File &&
                    (['.mp4', '.mov', '.mkv', '.avi'].any((ext) => (post["image"] as File).path.toLowerCase().endsWith(ext)));
                final bool isVideo = isLocalVideo || path.contains('.mp4') || path.contains('.mov') || path.contains('.mkv') || path.contains('.avi') || path.contains('.webm') || path.contains('/video/');

                if (isVideo) {
                  return FeedVideoPlayer(
                    videoUrl: isLocalVideo ? (post["image"] as File).path : imageUrl,
                  );
                }

                return InteractiveViewer(
                  clipBehavior: Clip.none,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff2B1564),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }(),
            ),
            if (location.isNotEmpty && location != "Unknown")
              Positioned(
                bottom: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    MapDiscoveryScreen.initialSearchQuery = location;
                    MapDiscoveryScreen.startNavigationDirectly = false;
                    if (MainWrapperState.activeState != null) {
                      MainWrapperState.activeState!.setIndex(1);
                    } else {
                      final state = context.findAncestorStateOfType<MainWrapperState>();
                      if (state != null) {
                        state.setIndex(1);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MainWrapper(initialIndex: 1)),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.near_me_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _performOptimisticLike(post);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isLiked
                        ? Icon(
                            Icons.favorite,
                            color: Colors.redAccent.shade700,
                            size: 26,
                          )
                        : Image.asset(
                            'assets/icons/icon-park-outline_like.png',
                            color: Colors.black87,
                            width: 26,
                            height: 26,
                          ),
                    const SizedBox(width: 6),
                    Text("$likes",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  // Comment requires login
                  if (AuthService().isGuest) {
                    showLoginRequiredSheet(context, reason: 'comment on a post');
                    return;
                  }
                  _openCommentSheet(context, postId: id is int ? id : null, post: post);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icons/uit_comment-dots.png', color: Colors.black87, width: 24, height: 24),
                    const SizedBox(width: 6),
                    Text("${post["comments_count"] ?? post["comments"] ?? 0}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => _openShareSheet(context, post: post),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icons/solar_share-linear.png', color: Colors.black87, width: 24, height: 24),
                    const SizedBox(width: 6),
                    Text("${post["shares"] ?? 0}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _performOptimisticSave(post);
                },
                child: Icon(
                    isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border_rounded,
                    color: Colors.black87,
                    size: 26),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: "$authorUsername  ",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14)),
                TextSpan(
                    text: caption,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13.5, height: 1.25)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openCommentSheet(BuildContext context, {int? postId, required Map<String, dynamic> post}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheetWidget(
        postId: postId,
        onCommentAdded: () {
          setState(() {
            post["comments_count"] = (post["comments_count"] ?? 0) + 1;
          });
        },
      ),
    );
  }

  void _openShareSheet(BuildContext context, {Map<String, dynamic>? post}) {
    final postIdStr = post != null ? post['id']?.toString() : null;
    final shareUrl = postIdStr != null ? 'https://hidely.kittuvirusstudio.in/post/$postIdStr' : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSheetWidget(
        postId: postIdStr,
        shareUrl: shareUrl,
      ),
    );
  }
}

class CommentSheetWidget extends StatefulWidget {
  final int? postId;
  final VoidCallback? onCommentAdded;
  const CommentSheetWidget({super.key, this.postId, this.onCommentAdded});

  @override
  State<CommentSheetWidget> createState() => _CommentSheetWidgetState();
}

class _CommentSheetWidgetState extends State<CommentSheetWidget> {
  final _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _replyingToUser;
  bool _isPosting = false;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _comments = [];

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (widget.postId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final result = await ApiService().getComments(postId: widget.postId!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          final list = result.data?['comments'] as List? ?? [];
          _comments.clear();
          _comments.addAll(list.map((c) => Map<String, dynamic>.from(c)));
        }
      });
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "Now";
      if (diff.inHours < 1) return "${diff.inMinutes}m";
      if (diff.inDays < 1) return "${diff.inHours}h";
      return "${diff.inDays}d";
    } catch (_) {
      return "Now";
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (widget.postId == null) return;

    setState(() => _isPosting = true);

    final token = AuthService().token ?? '';
    final result = await ApiService().addComment(
      token: token,
      postId: widget.postId!,
      text: text,
    );

    if (mounted) {
      setState(() {
        _isPosting = false;
        if (result.success) {
          final comment = result.data?['comment'];
          if (comment != null) {
            _comments.add(Map<String, dynamic>.from(comment));
          }
          widget.onCommentAdded?.call();
          _commentController.clear();
          _replyingToUser = null;
        }
      });
    }
  }

  Future<void> _confirmAndDeleteComment(Map<String, dynamic> comment, int index) async {
    final commentId = comment["id"];
    if (commentId == null) return;
    final int parsedId = commentId is int ? commentId : (int.tryParse(commentId.toString()) ?? 0);
    if (parsedId == 0) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Comment?", style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text("Are you sure you want to delete this comment? This action cannot be undone.", style: TextStyle(color: Colors.black54, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final token = AuthService().token ?? '';
      final result = await ApiService().deleteComment(token: token, commentId: parsedId);
      if (result.success && mounted) {
        setState(() {
          _comments.removeAt(index);
        });
        widget.onCommentAdded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Comment deleted."),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : "Failed to delete comment."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14.0),
              child: Text("Comments",
                  style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Text(
                        "Loading comments...",
                        style: TextStyle(color: Colors.black38, fontSize: 14),
                      ),
                    )
                  : _comments.isEmpty
                      ? const Center(
                          child: Text(
                            "Be the first to comment!",
                            style: TextStyle(color: Colors.black38, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final username = comment["username"] ?? comment["user"] ?? "User";
                            final commentText = comment["text"] ?? "";
                            final profilePic = comment["profile_picture"];
                            final timeStr = comment["time"] ?? (comment["created_at"] != null ? _formatTime(comment["created_at"].toString()) : "Now");

                            final currentUserId = AuthService().userId;
                            final currentUsername = AuthService().userUsername;
                            final commentUserId = comment["user_id"]?.toString() ?? "";
                            final commentUsername = comment["username"]?.toString() ?? comment["user"]?.toString() ?? "";

                            final bool isMyComment = (currentUserId.isNotEmpty && commentUserId == currentUserId) ||
                                (currentUsername.isNotEmpty && commentUsername.toLowerCase() == currentUsername.toLowerCase());

                            return GestureDetector(
                              onLongPress: isMyComment ? () => _confirmAndDeleteComment(comment, index) : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    UserAvatar(
                                      avatarUrl: profilePic,
                                      displayName: username,
                                      radius: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                    text: "$username ",
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                        fontSize: 14)),
                                                TextSpan(
                                                    text: commentText,
                                                    style: const TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 13.5)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(timeStr,
                                                  style: const TextStyle(
                                                      color: Colors.black38, fontSize: 11)),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _replyingToUser = username;
                                                    _commentController.text = "@$username ";
                                                  });
                                                  _focusNode.requestFocus();
                                                },
                                                child: const Text("Reply",
                                                    style: TextStyle(
                                                        color: Colors.black45,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                              if (isMyComment) ...[
                                                const SizedBox(width: 16),
                                                GestureDetector(
                                                  onTap: () => _confirmAndDeleteComment(comment, index),
                                                  child: const Text(
                                                    "Delete",
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () async {
                                      if (AuthService().isGuest) {
                                        showLoginRequiredSheet(context, reason: 'like a comment');
                                        return;
                                      }
                                      final commentId = comment["id"];
                                      final bool commentIsLiked = comment["is_liked"] ?? false;
                                      final int commentLikesCount = comment["likes_count"] ?? 0;

                                      if (commentId is int) {
                                        final token = AuthService().token ?? '';
                                        final result = await ApiService().toggleLikeComment(token: token, commentId: commentId);
                                        if (result.success) {
                                          setState(() {
                                            comment["is_liked"] = result.data?["is_liked"] ?? !commentIsLiked;
                                            comment["likes_count"] = result.data?["likes_count"] ?? (commentIsLiked ? commentLikesCount - 1 : commentLikesCount + 1);
                                          });
                                        }
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        (comment["is_liked"] ?? false)
                                          ? const Icon(
                                              Icons.favorite,
                                              color: Colors.redAccent,
                                              size: 16,
                                            )
                                          : Image.asset(
                                              'assets/icons/icon-park-outline_like.png',
                                              color: Colors.grey,
                                              width: 16,
                                              height: 16,
                                            ),
                                        if ((comment["likes_count"] ?? 0) > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            "${comment["likes_count"]}",
                                            style: const TextStyle(fontSize: 12, color: Colors.black38),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        ),
            ),
            if (_replyingToUser != null)
              Container(
                color: const Color(0xffF8FAFC),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "Replying to @$_replyingToUser",
                      style: const TextStyle(
                          color: Color(0xff5D3EBC),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToUser = null;
                          _commentController.clear();
                        });
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    UserAvatar(
                      avatarUrl: AuthService().userProfilePicture,
                      displayName: AuthService().userUsername,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            color: const Color(0xffF1F5F9),
                            borderRadius: BorderRadius.circular(24)),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xff1C0D5A)),
                          decoration: const InputDecoration(
                              hintText: "Add a comment...",
                              hintStyle: TextStyle(color: Colors.black38),
                              border: InputBorder.none),
                        ),
                      ),
                    ),
                    _isPosting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "Posting...",
                              style: TextStyle(
                                color: Color(0xff5D3EBC),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: _postComment,
                            child: const Text("Post",
                                style: TextStyle(
                                    color: Color(0xff5D3EBC),
                                    fontWeight: FontWeight.bold)),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareSheetWidget extends StatefulWidget {
  final dynamic postId;
  final String? shareUrl;
  const ShareSheetWidget({super.key, this.postId, this.shareUrl});

  @override
  State<ShareSheetWidget> createState() => _ShareSheetWidgetState();
}

class _ShareSheetWidgetState extends State<ShareSheetWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final token = AuthService().token ?? '';
    final List<Map<String, dynamic>> loadedUsers = [];

    if (token.isNotEmpty) {
      final res = await ApiService().getFollowing(token: token);
      if (res.success && res.data != null && res.data!['following'] != null) {
        final list = res.data!['following'] as List;
        for (var u in list) {
          if (u is Map) {
            loadedUsers.add({
              'id': u['id'],
              'name': u['name'] ?? u['username'] ?? 'User',
              'username': u['username'] ?? 'user',
              'avatar': u['profile_picture'] ?? 'assets/images/user1.jpg',
              'selected': false,
              'color': const Color(0xff5B3EC8),
            });
          }
        }
      }
    }

    if (loadedUsers.length < 8) {
      final lbRes = await ApiService().getLeaderboard();
      if (lbRes.success && lbRes.data != null && lbRes.data!['leaderboard'] != null) {
        final lbList = lbRes.data!['leaderboard'] as List;
        for (var u in lbList) {
          if (u is Map && !loadedUsers.any((existing) => existing['id'] == u['id'])) {
            loadedUsers.add({
              'id': u['id'],
              'name': u['name'] ?? u['username'] ?? 'Explorer',
              'username': u['username'] ?? 'user',
              'avatar': u['avatar_url'] ?? u['profile_picture'] ?? 'assets/images/user1.jpg',
              'selected': false,
              'color': const Color(0xff2563EB),
            });
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _users.clear();
        _users.addAll(loadedUsers);
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final val = _searchController.text.trim();
    setState(() {
      _searchQuery = val;
    });

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (val.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
        final res = await ApiService().searchUsers(query: val);
        if (res.success && res.data != null && res.data!['users'] != null && mounted) {
          final searchList = res.data!['users'] as List;
          setState(() {
            for (var u in searchList) {
              if (u is Map && !_users.any((existing) => existing['id'] == u['id'])) {
                _users.add({
                  'id': u['id'],
                  'name': u['name'] ?? u['username'] ?? 'User',
                  'username': u['username'] ?? 'user',
                  'avatar': u['profile_picture'] ?? 'assets/images/user1.jpg',
                  'selected': false,
                  'color': const Color(0xff9C27B0),
                });
              }
            }
          });
        }
      });
    }
  }

  bool get _hasSelection => _users.any((u) => u["selected"] == true);
  int get _selectedCount => _users.where((u) => u["selected"] == true).length;

  Future<void> _handleSend() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final selectedUsers = _users.where((u) => u["selected"] == true).toList();
    final token = AuthService().token ?? '';
    final String postShareUrl = widget.shareUrl ??
        (widget.postId != null
            ? '${ApiService().baseUrl}/post/${widget.postId}'
            : 'https://hidely.app/explore');

    if (token.isNotEmpty) {
      for (var u in selectedUsers) {
        final uId = u['id'];
        if (uId != null) {
          final directRes = await ApiService().getOrCreateDirectChat(token: token, targetUserId: uId);
          if (directRes.success && directRes.data != null && directRes.data!['conversationId'] != null) {
            final convId = int.tryParse(directRes.data!['conversationId'].toString());
            if (convId != null) {
              await ApiService().sendChatMessage(
                token: token,
                conversationId: convId,
                type: 'text',
                text: 'Check out this post: $postShareUrl',
                sharedEntityType: 'post',
                sharedEntityId: widget.postId?.toString(),
              );
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
      final names = selectedUsers.map((u) => u["name"]).join(", ");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sent successfully to $names!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff1C0D5A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _copyLink() {
    final String postShareUrl = widget.shareUrl ??
        (widget.postId != null
            ? '${ApiService().baseUrl}/post/${widget.postId}'
            : 'https://hidely.app/explore');
    Clipboard.setData(ClipboardData(text: postShareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.link, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("Link copied to clipboard!"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final name = user["name"].toString().toLowerCase();
      final username = user["username"].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          username.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Share to",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xffEFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search",
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.black45, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
                : filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 44, color: Colors.black26),
                            const SizedBox(height: 8),
                            Text(
                              "No matches found for '$_searchQuery'",
                              style: const TextStyle(color: Colors.black45, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isSelected = user["selected"] == true;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                user["selected"] = !isSelected;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 62,
                                      height: 62,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xff1C0D5A) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: UserAvatar(
                                        avatarUrl: user['avatar'],
                                        displayName: user['name'],
                                        radius: 30,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xff1C0D5A) : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.transparent : Colors.black26,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user["name"],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "@${user["username"]}",
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          
          const Divider(height: 1, color: Color(0xffEEEEEE)),
          SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _hasSelection
                  ? Container(
                      key: const ValueKey("send_button_panel"),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _handleSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1C0D5A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                "Send to $_selectedCount friend${_selectedCount > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    )
                  : Container(
                      key: const ValueKey("apps_panel"),
                      height: 100,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildAppIcon(Icons.link, "Copy Link", const Color(0xff64748B), _copyLink),
                          _buildAppIcon(Icons.chat_bubble_outline_rounded, "WhatsApp", const Color(0xff25D366), _copyLink),
                          _buildAppIcon(Icons.message_outlined, "Messenger", const Color(0xff1877F2), _copyLink),
                          _buildAppIcon(Icons.sms_outlined, "SMS", const Color(0xff475569), _copyLink),
                          _buildAppIcon(Icons.email_outlined, "Email", const Color(0xffEF4444), _copyLink),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, String label, Color bgColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: bgColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
