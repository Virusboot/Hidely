import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/feed_screen.dart'; // Contains CommentSheetWidget & ShareSheetWidget
import 'package:hidely_new/widgets/post_options_bottom_sheet.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
class SinglePostViewScreen extends StatefulWidget {
  final List<dynamic> posts;
  final int initialIndex;

  const SinglePostViewScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  // ignore: library_private_types_in_public_api
  static _SinglePostViewScreenState? activeState;

  @override
  State<SinglePostViewScreen> createState() => _SinglePostViewScreenState();
}

class _SinglePostViewScreenState extends State<SinglePostViewScreen> {
  late List<dynamic> _posts;
  final List<GlobalKey> _postKeys = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _followingStatus = {};

  @override
  void initState() {
    super.initState();
    SinglePostViewScreen.activeState = this;
    _posts = List<dynamic>.from(widget.posts)
        .where((p) => !AuthService().isPostDeletedLocally(p['id']))
        .toList();

    for (int i = 0; i < _posts.length; i++) {
      _postKeys.add(GlobalKey());
    }

    // Scroll to clicked post
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex >= 0 && widget.initialIndex < _postKeys.length) {
        final context = _postKeys[widget.initialIndex].currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    // Fetch follow status for all unique authors in the list
    _loadFollowStatuses();
  }

  void _loadFollowStatuses() {
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    final Set<String> uniqueUsernames = _posts
        .map((p) => p["author_username"] ?? p["username"] ?? '')
        .where((u) => u.isNotEmpty && u != AuthService().userUsername)
        .cast<String>()
        .toSet();

    for (final username in uniqueUsernames) {
      ApiService().getCreatorProfile(username: username, token: token).then((res) {
        if (res.success && mounted) {
          final creator = res.data?['creator'];
          if (creator != null) {
            setState(() {
              _followingStatus[username] = creator['is_following'] ?? false;
            });
          }
        }
      });
    }
  }

  Future<void> _toggleFollow(String username, dynamic authorId) async {
    if (AuthService().isGuest) return;
    final token = AuthService().token ?? '';
    dynamic targetId = authorId;

    if (targetId == null) {
      final res = await ApiService().getCreatorProfile(username: username, token: token);
      if (res.success) {
        targetId = res.data?['creator']?['id'];
      }
    }

    if (targetId != null) {
      final result = await ApiService().toggleFollowCreator(token: token, creatorId: targetId.toString());
      if (result.success && mounted) {
        setState(() {
          _followingStatus[username] = result.data?['is_following'] ?? !(_followingStatus[username] ?? false);
        });
      }
    }
  }

  @override
  void dispose() {
    if (SinglePostViewScreen.activeState == this) {
      SinglePostViewScreen.activeState = null;
    }
    _scrollController.dispose();
    super.dispose();
  }

  void removePostLocally(int postId) {
    if (!mounted) return;
    setState(() {
      _posts.removeWhere((p) => p['id'] == postId || p['id']?.toString() == postId.toString());
    });
    // If no posts left, pop this screen
    if (_posts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Posts",
            style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: _posts.isEmpty
            ? const Center(child: Text("No posts available"))
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: 40.0 + MediaQuery.of(context).padding.bottom,
                ),
                controller: _scrollController,
                child: Column(
                  children: List.generate(_posts.length, (index) {
                    final post = _posts[index];
                    final id = post["id"];
                    final String caption = post["caption"] ?? "";
                    final String location = post["location"] ?? "Unknown";
                    
                    String displayLocation = location;
                    if (location.isNotEmpty) {
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
                    final bool isLiked = post["is_liked"] ?? post["isLiked"] ?? false;
                    final bool isBookmarked = post["is_bookmarked"] ?? post["isBookmarked"] ?? false;
                    
                    final String authorUsername = post["author_username"] ?? post["username"] ?? AuthService().userUsername;
                    final String? authorPic = post["author_profile_picture"] ?? AuthService().userProfilePicture;
                    
                    final String imageUrl = post["image_url"] ?? (post["image"] is String ? post["image"] : "");
                    final bool isAsset = post["isAsset"] ?? (imageUrl.startsWith("assets/") == true);
                    final bool isMe = authorUsername == AuthService().userUsername;

                    return Column(
                      key: _postKeys[index],
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (isMe) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CreatorProfileScreen(
                                          username: authorUsername,
                                          avatarPath: authorPic != null && authorPic.isNotEmpty
                                              ? (authorPic.startsWith('http') ? authorPic : '${ApiService().baseUrl}/$authorPic')
                                              : "assets/images/nomad_nate_avatar.png",
                                          rank: "Gold",
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
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (isMe) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                                              );
                                            } else {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CreatorProfileScreen(
                                                    username: authorUsername,
                                                    avatarPath: authorPic != null && authorPic.isNotEmpty
                                                        ? (authorPic.startsWith('http') ? authorPic : '${ApiService().baseUrl}/$authorPic')
                                                        : "assets/images/nomad_nate_avatar.png",
                                                    rank: "Gold",
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            authorUsername,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
                                          ),
                                        ),
                                        if (!isMe) ...[
                                          const SizedBox(width: 8),
                                          const Text("•", style: TextStyle(color: Colors.black54, fontSize: 14)),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _toggleFollow(authorUsername, post["author_id"] ?? post["user_id"]),
                                            child: Text(
                                              _followingStatus[authorUsername] == true ? "Following" : "Follow",
                                              style: TextStyle(
                                                color: _followingStatus[authorUsername] == true ? Colors.black54 : const Color(0xff5D3EBC),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                            child: Row(
                                               children: [
                                                 const Icon(Icons.location_on_rounded, color: Color(0xff5D3EBC), size: 12),
                                                 const SizedBox(width: 3),
                                                 Expanded(
                                                   child: Text(
                                                     displayLocation,
                                                     maxLines: 1,
                                                     overflow: TextOverflow.ellipsis,
                                                     style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.w600),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => PostOptionsBottomSheet(post: post),
                                  );
                                },
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

                        // Post Image Preview
                        GestureDetector(
                          onDoubleTap: () async {
                            if (AuthService().isGuest) return;
                            if (id is int) {
                              final token = AuthService().token ?? '';
                              final result = await ApiService().toggleLikePost(token: token, postId: id);
                              if (result.success) {
                                setState(() {
                                  _posts[index]["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                                  _posts[index]["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                                });
                              }
                            } else {
                              setState(() {
                                if (!isLiked) {
                                  _posts[index]["isLiked"] = true;
                                  _posts[index]["likes"] = (post["likes"] ?? 0) + 1;
                                }
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              InteractiveViewer(
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
                                                placeholder: (context, url) => Container(color: const Color(0xffF1F5F9)),
                                                errorWidget: (context, url, error) => Container(
                                                  color: const Color(0xffCBD5E1),
                                                  child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                                ),
                                              )),
                                  ),
                                ),
                              ),
                              if (location.isNotEmpty)
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  child: GestureDetector(
                                    onTap: () {
                                      MapDiscoveryScreen.initialSearchQuery = location;
                                      MapDiscoveryScreen.startNavigationDirectly = false;
                                      final state = context.findAncestorStateOfType<MainWrapperState>();
                                      if (state != null) {
                                        state.setIndex(1);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const MainWrapper(initialIndex: 1)),
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
                        ),

                        // Action Toolbar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  if (AuthService().isGuest) return;
                                  if (id is int) {
                                    final token = AuthService().token ?? '';
                                    final result = await ApiService().toggleLikePost(token: token, postId: id);
                                    if (result.success) {
                                      setState(() {
                                        _posts[index]["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                                        _posts[index]["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _posts[index]["isLiked"] = !isLiked;
                                      _posts[index]["likes"] = (post["likes"] ?? 0) + (isLiked ? -1 : 1);
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
                                            size: 24,
                                          )
                                        : Image.asset(
                                            'assets/icons/icon-park-outline_like.png',
                                            color: Colors.black87,
                                            width: 24,
                                            height: 24,
                                          ),
                                    const SizedBox(width: 6),
                                    Text("$likes", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => CommentSheetWidget(
                                      postId: id is int ? id : null,
                                      onCommentAdded: () {
                                        setState(() {
                                          _posts[index]["comments_count"] = (post["comments_count"] ?? 0) + 1;
                                        });
                                      },
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/icons/uit_comment-dots.png', color: Colors.black87, width: 22, height: 22),
                                    const SizedBox(width: 6),
                                    Text("${post["comments_count"] ?? post["comments"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const ShareSheetWidget(),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/icons/solar_share-linear.png', color: Colors.black87, width: 22, height: 22),
                                    const SizedBox(width: 6),
                                    Text("${post["shares"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  if (AuthService().isGuest) return;
                                  if (id is int) {
                                    final token = AuthService().token ?? '';
                                    final result = await ApiService().toggleBookmarkPost(token: token, postId: id);
                                    if (result.success) {
                                      setState(() {
                                        _posts[index]["is_bookmarked"] = result.data?["is_bookmarked"] ?? !isBookmarked;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _posts[index]["isBookmarked"] = !isBookmarked;
                                    });
                                  }
                                },
                                child: Icon(
                                  isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Caption
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "$authorUsername  ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                                TextSpan(text: caption, style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.25)),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                      ],
                    );
                  }),
                ),
              ),
      ),
    );
  }
}
