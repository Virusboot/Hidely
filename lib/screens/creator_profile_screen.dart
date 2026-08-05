import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/screens/follow_list_screen.dart';
import 'package:hidely_new/widgets/empty_state.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/screens/group_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidely_new/widgets/report_bottom_sheet.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String username;
  final String avatarPath;
  final String rank;
  final String bio;

  const CreatorProfileScreen({
    super.key,
    required this.username,
    required this.avatarPath,
    required this.rank,
    this.bio = "",
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isBlocked = false;
  Map<String, dynamic>? _creatorData;
  List<dynamic> _creatorPosts = [];
  String _followers = "0";
  String _followings = "0";
  String _postsCount = "0";

  // Bio parsing helper getters
  String get _bioText => _creatorData?["bio"] ?? widget.bio;

  String get _cleanBio {
    String clean = _bioText;
    final RegExp instaReg = RegExp(r'Instagram:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
    final RegExp ytReg = RegExp(r'YouTube:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);

    clean = clean.replaceAll(instaReg, '').replaceAll(ytReg, '').trim();
    return clean;
  }

  String get _instagramUrl {
    final RegExp instaReg = RegExp(r'Instagram:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
    final match = instaReg.firstMatch(_bioText);
    if (match != null) {
      String val = match.group(1) ?? '';
      if (!val.startsWith('http')) {
        if (val.startsWith('@')) {
          val = val.substring(1);
        }
        val = 'https://instagram.com/$val';
      }
      return val;
    }
    return '';
  }

  String get _youtubeUrl {
    final RegExp ytReg = RegExp(r'YouTube:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
    final match = ytReg.firstMatch(_bioText);
    if (match != null) {
      String val = match.group(1) ?? '';
      if (!val.startsWith('http')) {
        if (val.startsWith('@')) {
          val = val.substring(1);
        }
        val = 'https://youtube.com/@$val';
      }
      return val;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCreatorProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatorProfile() async {
    final token = AuthService().token;
    final blocked = await AuthService().isUserBlocked(widget.username);
    final result = await ApiService().getCreatorProfile(
      username: widget.username,
      token: token,
    );
    if (mounted) {
      if (result.success) {
        final creator = result.data?['creator'];
        List posts = result.data?['posts'] as List? ?? [];
        
        if (posts.isEmpty && creator != null && creator['id'] != null) {
          final postsResult = await ApiService().getUserPosts(
            userId: creator['id'].toString(),
            token: token,
          );
          if (postsResult.success) {
            posts = (postsResult.data?['posts'] as List?) ?? [];
          }
        }

        int pCount = creator?['posts_count'] ?? 0;
        if (posts.length > pCount) {
          pCount = posts.length;
        }

        setState(() {
          _creatorData = creator;
          _creatorPosts = posts;
          _followers = "${creator?['followers_count'] ?? 0}";
          _followings = "${creator?['followings_count'] ?? 0}";
          _postsCount = "$pCount";
          _isFollowing = creator?['is_following'] ?? false;
          _isBlocked = blocked;
          _isLoading = false;
        });
      } else {
        if (widget.username == 'hidely_official' || widget.username == 'hidely') {
          final adminPostsResult = await ApiService().getExplorePosts(token: token);
          List adminPosts = [];
          if (adminPostsResult.success) {
            adminPosts = adminPostsResult.data?['posts'] as List? ?? [];
          }
          setState(() {
            _creatorData = {
              'id': 'admin_official',
              'username': 'hidely_official',
              'full_name': 'Hidely Official',
              'bio': 'Official Hidely App Account. Exploring the world\'s most breathtaking places! 🌍✨',
              'is_verified': true,
              'followers_count': 12800,
              'followings_count': 42,
              'posts_count': adminPosts.isNotEmpty ? adminPosts.length : 154,
              'is_following': false,
            };
            _creatorPosts = adminPosts;
            _followers = "12.8K";
            _followings = "42";
            _postsCount = adminPosts.isNotEmpty ? "${adminPosts.length}" : "154";
            _isFollowing = false;
            _isBlocked = false;
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _isBlocked = blocked;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'follow a creator');
      return;
    }
    final creatorId = _creatorData?['id']?.toString();
    if (creatorId == null) return;
    
    final token = AuthService().token ?? '';
    final result = await ApiService().toggleFollowCreator(
      token: token,
      creatorId: creatorId,
    );
    if (result.success && mounted) {
      setState(() {
        _isFollowing = result.data?['is_following'] ?? !_isFollowing;
        final currentFollowers = int.tryParse(_followers) ?? 0;
        _followers = "${_isFollowing ? currentFollowers + 1 : (currentFollowers - 1).clamp(0, 999999)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? rawAvatar = _creatorData?["profile_picture"]?.toString();
    if (rawAvatar == null || rawAvatar.isEmpty) {
      rawAvatar = widget.avatarPath;
    }
    final String? avatarUrl = rawAvatar.isNotEmpty
        ? (rawAvatar.startsWith("http") ? rawAvatar : "${ApiService().baseUrl}/$rawAvatar")
        : null;

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
          child: _isLoading
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. TOP APP BAR WITH BACK ARROW & OPTIONS BUTTON ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0)),
                            ),
                          ),
                          Text(
                            "@${_creatorData?["username"] ?? widget.username}",
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showOptionsSheet(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.more_vert, color: Color(0xff1C0D5A), size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 2. PROFILE HEADER (AVATAR + STATS) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xff4F46E5), Color(0xff9333EA)],
                                  ),
                                ),
                                child: UserAvatar(
                                  avatarUrl: avatarUrl,
                                  displayName: _creatorData?["name"]?.toString() ?? widget.username,
                                  radius: 42,
                                ),
                              ),
                              Positioned(
                                bottom: -8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff431D9A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: Text(
                                    widget.rank.toLowerCase().contains('rank')
                                        ? widget.rank.toUpperCase()
                                        : (widget.rank.toLowerCase() == 'novice' ? 'NOVICE' : 'RANK ${widget.rank.toUpperCase()}'),
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMetaStatColumn(_postsCount, "hidelys"),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListScreen(
                                          username: _creatorData?["username"] ?? widget.username,
                                          initialTab: 0,
                                          isMe: (_creatorData?["username"] ?? widget.username) == AuthService().userUsername,
                                        ),
                                      ),
                                    ).then((_) => _loadCreatorProfile());
                                  },
                                  child: _buildMetaStatColumn(_followers, "followers"),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FollowListScreen(
                                          username: _creatorData?["username"] ?? widget.username,
                                          initialTab: 1,
                                          isMe: (_creatorData?["username"] ?? widget.username) == AuthService().userUsername,
                                        ),
                                      ),
                                    ).then((_) => _loadCreatorProfile());
                                  },
                                  child: _buildMetaStatColumn(_followings, "following"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- 3. CREATOR BIO & HASHTAGS ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _creatorData?["name"] ?? _creatorData?["username"] ?? widget.username,
                            style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_cleanBio.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _cleanBio,
                              style: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.75), fontSize: 14, height: 1.35, fontWeight: FontWeight.w500),
                            ),
                          ],
                          if (_instagramUrl.isNotEmpty || _youtubeUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (_instagramUrl.isNotEmpty) ...[
                                  GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse(_instagramUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png',
                                            width: 13,
                                            height: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'Instagram',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (_instagramUrl.isNotEmpty && _youtubeUrl.isNotEmpty) const SizedBox(width: 8),
                                if (_youtubeUrl.isNotEmpty) ...[
                                  GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse(_youtubeUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/512px-YouTube_full-color_icon_%282017%29.svg.png',
                                            width: 15,
                                            height: 10,
                                          ),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'YouTube',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 4. ACTION ROW (FOLLOW / MESSAGE / USER ADD) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing ? const Color(0xffE2DCF7) : const Color(0xff2B1564),
                                  foregroundColor: _isFollowing ? const Color(0xff2B1564) : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(_isFollowing ? "Following" : "Follow", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: TextButton(
                                onPressed: _isBlocked
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Unblock this user to send a message."),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    : () {
                                        if (AuthService().isGuest) {
                                          showLoginRequiredSheet(context, reason: 'send a message');
                                          return;
                                        }
                                         final ChatItem directChat = ChatItem(
                                           id: 'dm_${widget.username}',
                                           name: widget.username,
                                           avatar: widget.avatarPath.isNotEmpty ? widget.avatarPath : 'assets/icons/Profile.png',
                                           lastMessage: 'Tap to send a secure private message...',
                                           time: 'Just Now',
                                           unreadCount: 0,
                                           isGroup: false,
                                         );
                                         
                                         Navigator.pop(context);
                                         MainWrapperState.activeState?.setIndex(2);
                                         WidgetsBinding.instance.addPostFrameCallback((_) {
                                           GroupChatScreen.activeState?.openDirectChat(directChat);
                                         });
                                      },
                                child: Text(
                                  "Message",
                                  style: TextStyle(
                                    color: _isBlocked ? Colors.black38 : const Color(0xff1C0D5A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 5. TAB BAR ---
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black12, width: 0.5),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xff2B1564),
                        indicatorWeight: 2,
                        labelColor: const Color(0xff2B1564),
                        unselectedLabelColor: Colors.black38,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_view_rounded, size: 22)),
                          Tab(icon: Icon(Icons.movie_creation_outlined, size: 22)),
                        ],
                      ),
                    ),

                    // --- 6. GRID AND TABVIEW DISPLAY ---
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildImageGridStream(),
                          const EmptyStateWidget(
                            icon: Icons.movie_creation_outlined,
                            title: "No Reels Yet",
                            description: "No cinematic moments shared yet.",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),);
  }

  Future<void> _toggleBlock() async {
    if (AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'block a creator');
      return;
    }
    final username = widget.username;
    if (_isBlocked) {
      await AuthService().unblockUser(username);
      if (mounted) {
        setState(() => _isBlocked = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@$username unblocked successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await AuthService().blockUser(username);
      if (mounted) {
        setState(() => _isBlocked = true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@$username blocked successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xff1C0D5A)),
                title: const Text("Report", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ReportBottomSheet(
                      targetType: 'Profile',
                      targetName: widget.username,
                      onSubmitSuccess: () {},
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(_isBlocked ? Icons.check_circle_outline : Icons.block, color: Colors.redAccent),
                title: Text(_isBlocked ? "Unblock" : "Block", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleBlock();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildImageGridStream() {
    if (_creatorPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 40, color: Colors.black38),
            SizedBox(height: 8),
            Text("No posts yet", style: TextStyle(color: Colors.black38, fontSize: 14)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: _creatorPosts.length,
      itemBuilder: (context, index) {
        final post = _creatorPosts[index];
        final String imagePath = post["image_url"]?.toString() ?? post["image"]?.toString() ?? "";
        final String lowerPath = imagePath.toLowerCase();
        final bool isVideo = lowerPath.endsWith('.mp4') || lowerPath.endsWith('.mov') || lowerPath.endsWith('.mkv') || lowerPath.endsWith('.avi');
        final bool isNetwork = imagePath.startsWith("http") || imagePath.startsWith("uploads");
        final bool hasImage = imagePath.isNotEmpty;

        return GestureDetector(
          onTap: () {
            final mappedPosts = _creatorPosts.map((p) {
              final Map<String, dynamic> pm = Map<String, dynamic>.from(p);
              if (pm["author_username"] == null && _creatorData != null) {
                pm["author_username"] = _creatorData!["username"];
              }
              if (pm["author_profile_picture"] == null && _creatorData != null) {
                pm["author_profile_picture"] = _creatorData!["profile_picture"];
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
            ).then((_) => _loadCreatorProfile());
          },
          child: Container(
            color: const Color(0xffCBD5E1),
            child: !hasImage
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 20),
                        SizedBox(height: 4),
                        Text(
                          "No Image",
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : isVideo
                    ? const Center(
                        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40),
                      )
                    : isNetwork
                    ? Image.network(
                        imagePath.startsWith("http") ? imagePath : '${ApiService().baseUrl}/$imagePath',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                        ),
                      )
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                        ),
                      ),
          ),
        );
      },
    );
  }
}