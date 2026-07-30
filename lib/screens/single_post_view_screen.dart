import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/screens/map_discovery_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/post_options_bottom_sheet.dart';

class SinglePostViewScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const SinglePostViewScreen({super.key, required this.post});

  @override
  State<SinglePostViewScreen> createState() => _SinglePostViewScreenState();
}

class _SinglePostViewScreenState extends State<SinglePostViewScreen> {
  late Map<String, dynamic> _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
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
  Widget build(BuildContext context) {
    final id = _post["id"];
    final String caption = _post["caption"] ?? "";
    final String location = _post["location"] ?? "Unknown";
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
    final int likes = _post["likes_count"] ?? _post["likes"] ?? 0;
    
    final bool isLiked = _post["is_liked"] ?? _post["isLiked"] ?? false;
    final bool isBookmarked = _post["is_bookmarked"] ?? _post["isBookmarked"] ?? false;
    
    final String authorUsername = _post["author_username"] ?? "realharshbhardwaj";
    final String? authorPic = _post["author_profile_picture"];
    
    final String imageUrl = _post["image_url"] ?? (_post["image"] is String ? _post["image"] : "");
    final bool isAsset = _post["isAsset"] ?? (imageUrl.startsWith("assets/") == true);

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
            "Post",
            style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (authorUsername == AuthService().userUsername) {
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
                                    ? '${ApiService().baseUrl}/$authorPic'
                                    : "assets/images/nomad_nate_avatar.png",
                                rank: "Gold",
                              ),
                            ),
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xffCBD5E1),
                        backgroundImage: authorPic != null && authorPic.isNotEmpty
                            ? NetworkImage('${ApiService().baseUrl}/$authorPic') as ImageProvider
                            : const AssetImage('assets/images/nomad_nate_avatar.png'),
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
                                          ? '${ApiService().baseUrl}/$authorPic'
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
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LocationDetailScreen(
                                          title: _post["title"] ?? location,
                                          location: location,
                                          image: isAsset ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                                          category: _post["category"] ?? "All",
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Suggested For You • $displayLocation ",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  MapDiscoveryScreen.initialSearchQuery = location;
                                  MapDiscoveryScreen.startNavigationDirectly = true;
                                  if (MainWrapperState.activeState != null) {
                                    MainWrapperState.activeState!.setIndex(1);
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MainWrapper(initialIndex: 1),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Icon(Icons.location_on_outlined, size: 13, color: Color(0xff5D3EBC)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showPostOptionsSheet(context, _post),
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
                        _post["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                        _post["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                      });
                    }
                  } else {
                    setState(() {
                      if (!isLiked) {
                        _post["isLiked"] = true;
                        _post["likes"] = (_post["likes"] ?? 0) + 1;
                      }
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 380,
                  color: Colors.black12,
                  child: _post["image"] is File
                      ? Image.file(_post["image"] as File, fit: BoxFit.cover)
                      : (isAsset
                          ? Image.asset(imageUrl, fit: BoxFit.cover)
                          : Image.network(
                              imageUrl.startsWith("http") ? imageUrl : '${ApiService().baseUrl}/$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xffCBD5E1),
                                child: const Icon(Icons.image, color: Colors.white24, size: 40),
                              ),
                            )),
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
                              _post["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                              _post["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                            });
                          }
                        } else {
                          setState(() {
                            _post["isLiked"] = !isLiked;
                            _post["likes"] = (_post["likes"] ?? 0) + (isLiked ? -1 : 1);
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.redAccent.shade700 : Colors.black87,
                            size: 24,
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
                                _post["comments_count"] = (_post["comments_count"] ?? 0) + 1;
                              });
                            },
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black87, size: 22),
                          const SizedBox(width: 6),
                          Text("${_post["comments_count"] ?? _post["comments"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                          const Icon(Icons.share_outlined, color: Colors.black87, size: 22),
                          const SizedBox(width: 6),
                          Text("${_post["shares"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                              _post["is_bookmarked"] = result.data?["is_bookmarked"] ?? !isBookmarked;
                            });
                          }
                        } else {
                          setState(() {
                            _post["isBookmarked"] = !isBookmarked;
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
            ],
          ),
        ),
      ),
    );
  }
}
