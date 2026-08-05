import 'package:flutter/material.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/screens/feed_video_player.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  // ignore: library_private_types_in_public_api
  static _ReelsScreenState? activeState;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  List<dynamic> _videoReels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ReelsScreen.activeState = this;
    _fetchReels();
  }

  Future<void> _fetchReels() async {
    setState(() {
      _isLoading = true;
    });

    final result = await ApiService().getExplorePosts(
      category: "All",
      token: AuthService().token,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          final allPosts = result.data?['posts'] ?? [];
          _videoReels = allPosts.where((post) {
            if (AuthService().isPostDeletedLocally(post['id'])) return false;
            final imageUrl = post["image_url"]?.toString().toLowerCase() ?? "";
            return imageUrl.endsWith('.mp4') ||
                imageUrl.endsWith('.mov') ||
                imageUrl.endsWith('.mkv') ||
                imageUrl.endsWith('.avi');
          }).toList();
        } else {
          _videoReels = [];
        }
      });
    }
  }

  @override
  void dispose() {
    if (ReelsScreen.activeState == this) {
      ReelsScreen.activeState = null;
    }
    _pageController.dispose();
    super.dispose();
  }

  void removePostLocally(int postId) {
    if (!mounted) return;
    setState(() {
      _videoReels.removeWhere((p) => p['id'] == postId || p['id']?.toString() == postId.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffE0F2FE),
              Color(0xff000000),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _videoReels.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, size: 40, color: Colors.white24),
                              SizedBox(height: 12),
                              Text(
                                "No Reels Published Yet",
                                style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _videoReels.length,
                          itemBuilder: (context, index) {
                            return _buildReelPageItem(_videoReels[index]);
                          },
                        ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Lenses",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                      ),
                    ),
                    IconButton(
                      onPressed: () => debugPrint("Launching Camera Capture Lens Node..."),
                      icon: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReelPageItem(dynamic reel) {
    final id = reel["id"];
    final String authorUsername = reel["author_username"] ?? reel["username"] ?? AuthService().userUsername;
    final String? authorPic = reel["author_profile_picture"] ?? AuthService().userProfilePicture;
    final String caption = reel["caption"] ?? "";
    final String imageUrl = reel["image_url"] ?? "";
    
    final int likes = reel["likes_count"] ?? 0;
    final int comments = reel["comments_count"] ?? 0;
    final bool isLiked = reel["is_liked"] ?? false;
    final bool isBookmarked = reel["is_bookmarked"] ?? false;

    return Stack(
      children: [
        Positioned.fill(
          child: FeedVideoPlayer(videoUrl: imageUrl),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 16,
          right: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (authorUsername == AuthService().userUsername) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
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
                      radius: 16,
                      backgroundColor: const Color(0xffCBD5E1),
                      backgroundImage: authorPic != null && authorPic.isNotEmpty
                          ? NetworkImage('${ApiService().baseUrl}/$authorPic') as ImageProvider
                          : const AssetImage('assets/images/nomad_nate_avatar.png'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (authorUsername == AuthService().userUsername) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Original Audio",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 30,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  if (AuthService().isGuest) return;
                  if (id is int) {
                    final token = AuthService().token ?? '';
                    final result = await ApiService().toggleLikePost(token: token, postId: id);
                    if (result.success) {
                      setState(() {
                        reel["is_liked"] = result.data?["is_liked"] ?? !isLiked;
                        reel["likes_count"] = result.data?["likes_count"] ?? (isLiked ? likes - 1 : likes + 1);
                      });
                    }
                  }
                },
                child: Column(
                  children: [
                    isLiked
                        ? Icon(
                            Icons.favorite,
                            color: Colors.redAccent.shade700,
                            size: 28,
                          )
                        : Image.asset(
                            'assets/icons/icon-park-outline_like.png',
                            color: Colors.white,
                            width: 28,
                            height: 28,
                          ),
                    const SizedBox(height: 6),
                    Text(
                      "$likes",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => debugPrint("Launching Feed Sheet Comments System Framework Context..."),
                child: Column(
                  children: [
                    Image.asset('assets/icons/uit_comment-dots.png', color: Colors.white, width: 26, height: 26),
                    const SizedBox(height: 6),
                    Text(
                      "$comments",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => debugPrint("Launching Feed Sheet Grid Sharing Framework Context..."),
                child: Column(
                  children: [
                    Image.asset('assets/icons/solar_share-linear.png', color: Colors.white, width: 26, height: 26),
                    const SizedBox(height: 6),
                    const Text(
                      "Share",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () async {
                  if (AuthService().isGuest) return;
                  if (id is int) {
                    final token = AuthService().token ?? '';
                    final result = await ApiService().toggleBookmarkPost(token: token, postId: id);
                    if (result.success) {
                      setState(() {
                        reel["is_bookmarked"] = result.data?["is_bookmarked"] ?? !isBookmarked;
                      });
                    }
                  }
                },
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  color: Colors.black45,
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  child: Icon(Icons.album_outlined, color: Colors.cyanAccent, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}