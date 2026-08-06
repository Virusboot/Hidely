import 'package:flutter/material.dart';
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
import 'package:hidely_new/data/official_posts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  static final List<Map<String, dynamic>> mockPosts = [
    {
      "id": 0,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isLiked": false,
      "isBookmarked": false,
      "location": "Nainital, Uttarakhand",
      "title": "Nainital Lake Boating",
      "image": "assets/images/explore_1.png",
      "isAsset": true,
      "caption":
          "Exploring the serene Naini Lake surrounded by misty pine hills under the golden hour sun.",
    },
    {
      "id": 1,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isLiked": false,
      "isBookmarked": false,
      "location": "Manali, Himachal Pradesh",
      "title": "Solang Valley Snow",
      "image": "assets/images/explore_2.png",
      "isAsset": true,
      "caption":
          "Snowy peaks and pine trees in Solang Valley. Crisp mountain breeze and adventure trails.",
    },
    {
      "id": 2,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isLiked": false,
      "isBookmarked": false,
      "location": "North Goa, India",
      "title": "Vagator Sunset Cliff",
      "image": "assets/images/explore_3.png",
      "isAsset": true,
      "caption":
          "Stunning coastal cliffs and coconut palms overlooking the Arabian Sea during sunset.",
    },
    {
      "id": 3,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isLiked": false,
      "isBookmarked": false,
      "location": "Agra, Uttar Pradesh",
      "title": "Taj Mahal Marvel",
      "image": "assets/images/explore_4.png",
      "isAsset": true,
      "caption":
          "Witnessing the pure white marble wonder along Yamuna River. A cinematic morning view.",
    },
    {
      "id": 4,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isLiked": false,
      "isBookmarked": false,
      "location": "Varanasi, Uttar Pradesh",
      "title": "Holy Ganga Ghats",
      "image": "assets/images/explore_5.png",
      "isAsset": true,
      "caption":
          "Immersing in the spiritual evening rituals and oil lamps along the banks of sacred River Ganga.",
    },
  ];

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
    _loadFeed();
    _loadUnreadCount();
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

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    final token = AuthService().token ?? '';
    final result = await ApiService().getFeedPosts(token: token.isNotEmpty ? token : null);

    if (!mounted) return;

    List<dynamic> serverFeed = [];
    if (result.success) {
      final feedList = result.data?['feed'];
      if (feedList != null && feedList is List) {
        serverFeed = feedList;
      }
    }

    final mixedFeed = _mixFeedAlgorithm(serverFeed, officialHidelyPosts);
    final cleanFeed = mixedFeed.where((p) => !AuthService().isPostDeletedLocally(p['id'])).toList();

    setState(() {
      _feedPosts = cleanFeed;
      _isLoading = false;
    });
  }

  List<dynamic> _mixFeedAlgorithm(List<dynamic> serverPosts, List<dynamic> officialPosts) {
    // 1. Sort all server posts by date (latest first)
    final List<dynamic> sortedServerPosts = List.from(serverPosts);
    sortedServerPosts.sort((a, b) {
      final aDateStr = a['created_at'] ?? a['createdAt'];
      final bDateStr = b['created_at'] ?? b['createdAt'];
      if (aDateStr != null && bDateStr != null) {
        try {
          final DateTime aDate = DateTime.parse(aDateStr.toString());
          final DateTime bDate = DateTime.parse(bDateStr.toString());
          return bDate.compareTo(aDate); // descending
        } catch (_) {}
      }
      // Fallback to ID sorting
      final aId = int.tryParse(a['id']?.toString() ?? '') ?? 0;
      final bId = int.tryParse(b['id']?.toString() ?? '') ?? 0;
      return bId.compareTo(aId); // descending
    });

    // 2. Interleave server posts to prevent consecutive posts from same author
    final List<dynamic> interleavedServer = [];
    final Map<String, List<dynamic>> userBuckets = {};
    
    for (final post in sortedServerPosts) {
      final author = (post['author_username'] ?? post['username'] ?? '').toString();
      userBuckets.putIfAbsent(author, () => []).add(post);
    }

    // Pick posts sequentially, trying to avoid matching the author of the last post
    String lastAuthor = '';
    while (userBuckets.isNotEmpty) {
      String? bestUser;
      
      // Find a user who has posts and is NOT the last author
      for (final user in userBuckets.keys) {
        if (user != lastAuthor) {
          bestUser = user;
          break;
        }
      }
      
      // If all remaining posts are from the last author, just pick the first available
      if (bestUser == null && userBuckets.isNotEmpty) {
        bestUser = userBuckets.keys.first;
      }
      
      if (bestUser != null) {
        final userPostsList = userBuckets[bestUser]!;
        interleavedServer.add(userPostsList.removeAt(0));
        if (userPostsList.isEmpty) {
          userBuckets.remove(bestUser);
        }
        lastAuthor = bestUser;
      }
    }

    // 3. Intersperse official/fallback posts (e.g. 1 official post after every 3 server posts)
    final List<dynamic> finalFeed = [];
    final List<dynamic> localOfficial = List.from(officialPosts);
    
    int serverIndex = 0;
    while (serverIndex < interleavedServer.length || localOfficial.isNotEmpty) {
      // Add up to 3 server posts
      for (int i = 0; i < 3 && serverIndex < interleavedServer.length; i++) {
        finalFeed.add(interleavedServer[serverIndex++]);
      }
      // Add 1 official post if available
      if (localOfficial.isNotEmpty) {
        finalFeed.add(localOfficial.removeAt(0));
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
            child: Stack(
              children: [
                _feedPosts.isEmpty && _isLoading
                    ? const SizedBox.shrink()
                    : RefreshIndicator(
                        onRefresh: _loadFeed,
                        color: const Color(0xff2B1564),
                        child: ListView.builder(
                          cacheExtent: 1500,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: _feedPosts.length + 3,
                          itemBuilder: (context, index) {
                            if (index == 0) {
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
                                    image: isAsset ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                                    category: post["category"] ?? "All",
                                  ),
                                ),
                              );
                            },
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
              onDoubleTap: () async {
                // Like requires login
                if (AuthService().isGuest) {
                  showLoginRequiredSheet(context, reason: 'like a post');
                  return;
                }
                
                if (id is int) {
                  final token = AuthService().token ?? '';
                  final result = await ApiService().toggleLikePost(token: token, postId: id);
                  if (result.success) {
                    setState(() {
                      post["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                      post["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                    });
                  }
                } else {
                  setState(() {
                    if (!isLiked) {
                      post["isLiked"] = true;
                      post["likes"] = (post["likes"] ?? 0) + 1;
                    }
                  });
                }
              },
              child: () {
                final path = imageUrl.toLowerCase();
                final bool isLocalVideo = post["image"] is File &&
                    (['.mp4', '.mov', '.mkv', '.avi'].any((ext) => (post["image"] as File).path.toLowerCase().endsWith(ext)));
                final bool isVideo = isLocalVideo || path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.mkv') || path.endsWith('.avi');

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
                    child: Container(
                      width: double.infinity,
                      color: Colors.black12,
                    child: post["image"] is File
                        ? Image.file(post["image"] as File, fit: BoxFit.cover)
                        : (isAsset
                            ? Image.asset(imageUrl, fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: imageUrl.startsWith("http") ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                                fit: BoxFit.cover,
                                memCacheWidth: 1080,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xffF1F5F9),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xffCBD5E1),
                                  child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                ),
                              )),
                    ),
                  ),
                );
              }(),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  MapDiscoveryScreen.initialSearchQuery = location;
                  MapDiscoveryScreen.startNavigationDirectly = false;
                  final state =
                      context.findAncestorStateOfType<MainWrapperState>();
                  if (state != null) {
                    state.setIndex(1);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const MainWrapper(initialIndex: 1)),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
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
                onTap: () async {
                  // Like requires login
                  if (AuthService().isGuest) {
                    showLoginRequiredSheet(context, reason: 'like a post');
                    return;
                  }
                  
                  if (id is int) {
                    final token = AuthService().token ?? '';
                    final result = await ApiService().toggleLikePost(token: token, postId: id);
                    if (result.success) {
                      setState(() {
                        post["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                        post["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                      });
                    }
                  } else {
                    setState(() {
                      post["isLiked"] = !isLiked;
                      post["likes"] = (post["likes"] ?? 0) + (isLiked ? -1 : 1);
                    });
                  }
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
                onTap: () => _openShareSheet(context),
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
                onTap: () async {
                  // Bookmark/save requires login
                  if (AuthService().isGuest) {
                    showLoginRequiredSheet(context, reason: 'save a post');
                    return;
                  }
                  
                  if (id is int) {
                    final token = AuthService().token ?? '';
                    final result = await ApiService().toggleBookmarkPost(token: token, postId: id);
                    if (result.success) {
                      setState(() {
                        post["is_bookmarked"] = result.data?["is_bookmarked"] ?? !isBookmarked;
                      });
                    }
                  } else {
                    setState(() {
                      post["isBookmarked"] = !isBookmarked;
                    });
                  }
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

  void _openShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ShareSheetWidget(),
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

                            return Padding(
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
  const ShareSheetWidget({super.key});

  @override
  State<ShareSheetWidget> createState() => _ShareSheetWidgetState();
}

class _ShareSheetWidgetState extends State<ShareSheetWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Mock users with actual image assets and fallback colors
  final List<Map<String, dynamic>> _users = [
    {
      "name": "Eleni K.",
      "username": "eleni_k",
      "avatar": "assets/images/elena_avatar.png",
      "color": Colors.pinkAccent,
      "selected": false,
    },
    {
      "name": "Julian Travels",
      "username": "julian_travels",
      "avatar": "assets/images/marcus_avatar.png",
      "color": Colors.blueAccent,
      "selected": false,
    },
    {
      "name": "Nomad Sophia",
      "username": "nomad_sophia",
      "avatar": "assets/images/aura_queen_avatar.png",
      "color": Colors.orangeAccent,
      "selected": false,
    },
    {
      "name": "Marcus Aurelius",
      "username": "marcus_a",
      "avatar": "assets/images/marcus_avatar.png",
      "color": Colors.teal,
      "selected": false,
    },
    {
      "name": "Aura Queen",
      "username": "aura_queen",
      "avatar": "assets/images/aura_queen_avatar.png",
      "color": Colors.purpleAccent,
      "selected": false,
    },
    {
      "name": "Leo Vinci",
      "username": "leo_vinci",
      "avatar": "assets/images/leo_vinci_avatar.png",
      "color": Colors.amber,
      "selected": false,
    },
    {
      "name": "Elena Smith",
      "username": "elena_smith",
      "avatar": "assets/images/elena_avatar.png",
      "color": Colors.redAccent,
      "selected": false,
    },
    {
      "name": "Nathan Drake",
      "username": "nathan_drake",
      "avatar": "assets/images/nomad_nate_avatar.png",
      "color": Colors.indigoAccent,
      "selected": false,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Check if any user is selected
  bool get _hasSelection => _users.any((u) => u["selected"] == true);

  // Get count of selected users
  int get _selectedCount => _users.where((u) => u["selected"] == true).length;

  void _handleSend() {
    final selectedNames = _users
        .where((u) => u["selected"] == true)
        .map((u) => u["name"])
        .join(", ");
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sent successfully to $selectedNames!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  void _copyLink() {
    Clipboard.setData(const ClipboardData(text: "https://hidely.app/post/share_id_8924"));
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
    // Filter users based on query
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
          // Drag Handle
          Container(
            width: 36,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          // Title
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
          // Search Bar
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
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
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
          
          // Users Grid / List
          Expanded(
            child: filteredUsers.isEmpty
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
                                // Avatar circle
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: user["color"].withOpacity(0.15),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xff1C0D5A) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(31),
                                    child: Image.asset(
                                      user["avatar"],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Center(
                                        child: Text(
                                          user["name"].substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: user["color"],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Selection indicator (Insta-style bottom right badge)
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
          
          // Action Bottom Panel
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
                        onPressed: _handleSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1C0D5A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
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
                          _buildAppIcon(Icons.chat_bubble_outline_rounded, "WhatsApp", const Color(0xff25D366), () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Redirecting to WhatsApp..."), duration: Duration(seconds: 1)),
                            );
                          }),
                          _buildAppIcon(Icons.message_outlined, "Messenger", const Color(0xff1877F2), () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Redirecting to Messenger..."), duration: Duration(seconds: 1)),
                            );
                          }),
                          _buildAppIcon(Icons.sms_outlined, "SMS", const Color(0xff475569), () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Opening Messaging..."), duration: Duration(seconds: 1)),
                            );
                          }),
                          _buildAppIcon(Icons.email_outlined, "Email", const Color(0xffEF4444), () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Opening Email client..."), duration: Duration(seconds: 1)),
                            );
                          }),
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
