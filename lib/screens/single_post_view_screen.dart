import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/feed_video_player.dart';
import 'package:hidely_new/screens/location_detail_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/feed_screen.dart'; // Contains CommentSheetWidget & ShareSheetWidget
import 'package:hidely_new/widgets/post_options_bottom_sheet.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/widgets/mention_text.dart';
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
  late List<Map<String, dynamic>> _posts;
  final List<GlobalKey> _postKeys = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _followingStatus = {};
  final Set<int> _loadingIndices = <int>{};
  final Map<int, String> _postLoadErrors = <int, String>{};
  final Set<int> _pendingLikeIndices = <int>{};
  final Set<int> _pendingBookmarkIndices = <int>{};

  static int? _parsePostId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString().trim());
  }

  static int _parseInt(dynamic raw, [int fallback = 0]) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim()) ?? fallback;
  }

  static bool _parseBool(dynamic raw) {
    return raw == true || raw == 1 || raw == 'true' || raw == '1';
  }

  static String _resolveMediaUrl(String? raw) {
    final clean = (raw ?? '').trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('assets/')) {
      return clean;
    }
    return '${ApiService().baseUrl}/${clean.startsWith('/') ? clean.substring(1) : clean}';
  }

  static bool _isVideoMedia(Map<String, dynamic> post, String imageUrl) {
    if (post['image'] is File) {
      final path = (post['image'] as File).path.toLowerCase();
      if (['.mp4', '.mov', '.mkv', '.avi', '.webm'].any((ext) => path.endsWith(ext))) {
        return true;
      }
    }
    final lower = imageUrl.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.mkv') ||
        lower.contains('.avi') ||
        lower.contains('.webm') ||
        lower.contains('/video/');
  }

  static bool _needsHydration(Map<String, dynamic> post) {
    if (post['isAsset'] == true) return false;
    if (_parsePostId(post['id']) == null) return false;

    final author = (post['author_username'] ?? post['username'] ?? '').toString().trim();
    final hasAuthor = author.isNotEmpty;
    final hasLikes = post.containsKey('likes_count') || post.containsKey('likes');
    final hasLikedState = post.containsKey('is_liked') || post.containsKey('isLiked');
    final hasComments = post.containsKey('comments_count') || post.containsKey('comments');
    final hasCaption = post.containsKey('caption');

    return !hasAuthor || !hasLikes || !hasLikedState || !hasComments || !hasCaption;
  }

  @override
  void initState() {
    super.initState();
    SinglePostViewScreen.activeState = this;
    AuthService().blockedUsersNotifier.addListener(_onBlockedUsersChanged);

    _posts = widget.posts
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) =>
            !AuthService().isPostDeletedLocally(p['id']) &&
            !AuthService().isPostFromBlockedUser(p))
        .toList();

    for (int i = 0; i < _posts.length; i++) {
      _postKeys.add(GlobalKey());
    }

    // Scroll to clicked post
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex >= 0 && widget.initialIndex < _postKeys.length) {
        final targetContext = _postKeys[widget.initialIndex].currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    _hydrateInitialPosts();
    _loadFollowStatuses();
  }

  void _hydrateInitialPosts() {
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      final postId = _parsePostId(post['id']);
      if (postId == null || post['isAsset'] == true) continue;

      if (_needsHydration(post)) {
        _loadingIndices.add(i);
        _fetchPostAt(i, showErrorOnFailure: true);
      } else if (_posts.length == 1 || i == widget.initialIndex) {
        // Silently refresh live counts/like/bookmark status from backend
        _fetchPostAt(i, showErrorOnFailure: false);
      }
    }
  }

  Future<void> _fetchPostAt(int index, {required bool showErrorOnFailure}) async {
    if (!mounted || index < 0 || index >= _posts.length) return;
    final currentMap = _posts[index];
    final int? postId = _parsePostId(currentMap['id']);
    if (postId == null) {
      if (mounted) {
        setState(() => _loadingIndices.remove(index));
      }
      return;
    }

    final token = AuthService().token ?? '';
    final result = await ApiService().getPostById(
      postId: postId,
      token: token.isNotEmpty ? token : null,
    );

    if (!mounted) return;
    final int currentIndex = _posts.indexWhere(
      (p) => _parsePostId(p['id']) == postId,
    );
    if (currentIndex == -1) return;

    if (result.success && result.data != null) {
      final raw = result.data!['post'] ?? result.data!;
      if (raw is Map && raw.isNotEmpty) {
        final fetched = Map<String, dynamic>.from(raw);
        final merged = Map<String, dynamic>.from(_posts[currentIndex])..addAll(fetched);
        final int likesCount = _parseInt(merged['likes_count'] ?? merged['likes']);
        final bool liked = _parseBool(merged['is_liked'] ?? merged['isLiked']);
        final bool bookmarked = _parseBool(merged['is_bookmarked'] ?? merged['isBookmarked']);
        final int commentsCount = _parseInt(merged['comments_count'] ?? merged['comments']);

        merged['likes_count'] = likesCount;
        merged['likes'] = likesCount;
        merged['is_liked'] = liked;
        merged['isLiked'] = liked;
        merged['is_bookmarked'] = bookmarked;
        merged['isBookmarked'] = bookmarked;
        merged['is_saved'] = bookmarked;
        merged['isSaved'] = bookmarked;
        merged['comments_count'] = commentsCount;

        if (AuthService().isPostFromBlockedUser(merged)) {
          setState(() {
            _loadingIndices.remove(currentIndex);
            _postLoadErrors[currentIndex] = 'This post is unavailable.';
          });
          return;
        }

        setState(() {
          _posts[currentIndex] = merged;
          _loadingIndices.remove(currentIndex);
          _postLoadErrors.remove(currentIndex);
        });
        _loadFollowStatuses();
        FeedScreen.activeState?.syncPostLocally(merged);
        return;
      }
    }

    setState(() {
      _loadingIndices.remove(currentIndex);
      if (result.statusCode == 403) {
        _postLoadErrors[currentIndex] = 'This post is unavailable.';
      } else if (showErrorOnFailure) {
        if (result.statusCode == 404) {
          _postLoadErrors[currentIndex] = 'This post has been deleted or is no longer available.';
        } else {
          _postLoadErrors[currentIndex] = result.message.isNotEmpty
              ? result.message
              : 'Could not load post details.';
        }
      }
    });
  }

  Future<void> _refreshAllPosts() async {
    final futures = <Future<void>>[];
    for (int i = 0; i < _posts.length; i++) {
      final postId = _parsePostId(_posts[i]['id']);
      if (postId != null && _posts[i]['isAsset'] != true) {
        futures.add(_fetchPostAt(i, showErrorOnFailure: _needsHydration(_posts[i])));
      }
    }
    await Future.wait(futures);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xff1C0D5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loadFollowStatuses() {
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    final Set<String> uniqueUsernames = _posts
        .map((p) => (p["author_username"] ?? p["username"] ?? '').toString().trim())
        .where((u) => u.isNotEmpty && u != AuthService().userUsername)
        .toSet();

    for (final username in uniqueUsernames) {
      ApiService().getCreatorProfile(username: username, token: token).then((res) {
        if (res.success && mounted) {
          final creator = res.data?['creator'];
          if (creator is Map) {
            setState(() {
              _followingStatus[username] = creator['is_following'] == true;
            });
          }
        }
      });
    }
  }

  Future<void> _toggleFollow(String username, dynamic authorId) async {
    if (AuthService().isGuest || (AuthService().token ?? '').isEmpty) {
      showLoginRequiredSheet(context, reason: 'follow this creator');
      return;
    }
    if (username.isEmpty || username == 'Traveler') return;

    final token = AuthService().token ?? '';
    dynamic targetId = authorId;

    if (targetId == null) {
      final res = await ApiService().getCreatorProfile(username: username, token: token);
      if (res.success) {
        targetId = res.data?['creator']?['id'];
      }
    }

    if (targetId != null) {
      final result = await ApiService().toggleFollowCreator(
        token: token,
        creatorId: targetId.toString(),
      );
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _followingStatus[username] =
              result.data?['is_following'] ?? !(_followingStatus[username] ?? false);
        });
      } else {
        _showSnack(
          result.isUnauthorized
              ? 'Session expired. Please log in again.'
              : (result.message.isNotEmpty ? result.message : 'Failed to update follow status.'),
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (_loadingIndices.contains(index) || _pendingLikeIndices.contains(index)) return;

    if (AuthService().isGuest || (AuthService().token ?? '').isEmpty) {
      showLoginRequiredSheet(context, reason: 'like a post');
      return;
    }

    HapticFeedback.lightImpact();
    final post = _posts[index];
    final int? parsedPostId = _parsePostId(post['id']);
    final bool wasLiked = _parseBool(post["is_liked"] ?? post["isLiked"]);
    final int oldLikes = _parseInt(post["likes_count"] ?? post["likes"]);
    final int newLikes = wasLiked ? (oldLikes > 0 ? oldLikes - 1 : 0) : oldLikes + 1;

    setState(() {
      post["is_liked"] = !wasLiked;
      post["isLiked"] = !wasLiked;
      post["likes_count"] = newLikes;
      post["likes"] = newLikes;
    });

    if (parsedPostId == null) {
      FeedScreen.activeState?.syncPostLocally(post);
      return;
    }

    _pendingLikeIndices.add(index);
    final token = AuthService().token ?? '';
    try {
      final result = await ApiService().toggleLikePost(
        token: token,
        postId: parsedPostId,
      );
      if (!mounted) return;

      if (result.success) {
        final bool serverLiked = result.data?["is_liked"] != null
            ? _parseBool(result.data!["is_liked"])
            : !wasLiked;
        final int serverLikes = result.data?["likes_count"] != null
            ? _parseInt(result.data!["likes_count"], newLikes)
            : newLikes;
        setState(() {
          post["is_liked"] = serverLiked;
          post["isLiked"] = serverLiked;
          post["likes_count"] = serverLikes;
          post["likes"] = serverLikes;
        });
        FeedScreen.activeState?.syncPostLocally(post);
      } else {
        setState(() {
          post["is_liked"] = wasLiked;
          post["isLiked"] = wasLiked;
          post["likes_count"] = oldLikes;
          post["likes"] = oldLikes;
        });
        _showSnack(
          result.isUnauthorized
              ? 'Session expired. Please log in again.'
              : (result.message.isNotEmpty ? result.message : 'Could not update like.'),
          isError: true,
        );
      }
    } finally {
      _pendingLikeIndices.remove(index);
    }
  }

  Future<void> _openComments(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (_loadingIndices.contains(index)) return;

    if (AuthService().isGuest || (AuthService().token ?? '').isEmpty) {
      showLoginRequiredSheet(context, reason: 'comment on a post');
      return;
    }

    final post = _posts[index];
    final int? parsedPostId = _parsePostId(post['id']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheetWidget(
        postId: parsedPostId,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            final current = _parseInt(post["comments_count"] ?? post["comments"]);
            post["comments_count"] = current + 1;
          });
          FeedScreen.activeState?.syncPostLocally(post);
        },
        onCommentDeleted: () {
          if (!mounted) return;
          setState(() {
            final current = _parseInt(post["comments_count"] ?? post["comments"]);
            post["comments_count"] = current > 0 ? current - 1 : 0;
          });
          FeedScreen.activeState?.syncPostLocally(post);
        },
      ),
    );

    // Sync exact comment count with backend after sheet closes (covers both add and delete)
    if (mounted && parsedPostId != null && post['isAsset'] != true) {
      await _fetchPostAt(index, showErrorOnFailure: false);
    }
  }

  Future<void> _toggleBookmark(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (_loadingIndices.contains(index) || _pendingBookmarkIndices.contains(index)) return;

    if (AuthService().isGuest || (AuthService().token ?? '').isEmpty) {
      showLoginRequiredSheet(context, reason: 'save a post');
      return;
    }

    HapticFeedback.lightImpact();
    final post = _posts[index];
    final int? parsedPostId = _parsePostId(post['id']);
    final bool wasSaved = _parseBool(
      post["is_bookmarked"] ?? post["isBookmarked"] ?? post["is_saved"] ?? post["isSaved"],
    );

    setState(() {
      post["is_bookmarked"] = !wasSaved;
      post["isBookmarked"] = !wasSaved;
      post["is_saved"] = !wasSaved;
      post["isSaved"] = !wasSaved;
    });

    if (parsedPostId == null) {
      FeedScreen.activeState?.syncPostLocally(post);
      return;
    }

    _pendingBookmarkIndices.add(index);
    final token = AuthService().token ?? '';
    try {
      final result = await ApiService().toggleBookmarkPost(
        token: token,
        postId: parsedPostId,
      );
      if (!mounted) return;

      if (result.success) {
        final bool serverSaved = result.data?["is_bookmarked"] != null
            ? _parseBool(result.data!["is_bookmarked"])
            : !wasSaved;
        setState(() {
          post["is_bookmarked"] = serverSaved;
          post["isBookmarked"] = serverSaved;
          post["is_saved"] = serverSaved;
          post["isSaved"] = serverSaved;
        });
        FeedScreen.activeState?.syncPostLocally(post);
      } else {
        setState(() {
          post["is_bookmarked"] = wasSaved;
          post["isBookmarked"] = wasSaved;
          post["is_saved"] = wasSaved;
          post["isSaved"] = wasSaved;
        });
        _showSnack(
          result.isUnauthorized
              ? 'Session expired. Please log in again.'
              : (result.message.isNotEmpty ? result.message : 'Could not update bookmark.'),
          isError: true,
        );
      }
    } finally {
      _pendingBookmarkIndices.remove(index);
    }
  }

  @override
  void dispose() {
    AuthService().blockedUsersNotifier.removeListener(_onBlockedUsersChanged);
    if (SinglePostViewScreen.activeState == this) {
      SinglePostViewScreen.activeState = null;
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onBlockedUsersChanged() {
    if (!mounted) return;
    setState(() {
      _posts.removeWhere((p) => AuthService().isPostFromBlockedUser(p));
    });
    if (_posts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
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

  Widget _buildPostErrorCard(int index, String errorMessage, Map<String, dynamic> post) {
    final bool isPermanent =
        errorMessage.toLowerCase().contains('deleted') ||
        errorMessage.toLowerCase().contains('unavailable');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff2B1564).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPermanent ? Icons.hide_image_outlined : Icons.cloud_off_rounded,
                size: 46,
                color: const Color(0xff2B1564),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPermanent ? 'Post Unavailable' : 'Could Not Load Post',
              style: const TextStyle(
                color: Color(0xff1C0D5A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (!isPermanent && _parsePostId(post['id']) != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _postLoadErrors.remove(index);
                        _loadingIndices.add(index);
                      });
                      _fetchPostAt(index, showErrorOnFailure: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2B1564),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff2B1564),
                    side: const BorderSide(color: Color(0xff2B1564)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            : RefreshIndicator(
                color: const Color(0xff2B1564),
                onRefresh: _refreshAllPosts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    bottom: 40.0 + MediaQuery.of(context).padding.bottom,
                  ),
                  controller: _scrollController,
                  child: Column(
                    children: List.generate(_posts.length, (index) {
                      final post = _posts[index];
                      final int? parsedPostId = _parsePostId(post["id"]);
                      final bool isHydrating = _loadingIndices.contains(index);
                      final String? loadError = _postLoadErrors[index];

                      if (loadError != null && !isHydrating) {
                        return Container(
                          key: index < _postKeys.length ? _postKeys[index] : null,
                          child: _buildPostErrorCard(index, loadError, post),
                        );
                      }

                      final String caption = (post["caption"] ?? "").toString();
                      final String rawLocation = (post["location"] ?? "").toString().trim();
                      final String location = rawLocation.isNotEmpty ? rawLocation : "Unknown";

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

                      final int likes = _parseInt(post["likes_count"] ?? post["likes"]);
                      final int commentsCount = _parseInt(post["comments_count"] ?? post["comments"]);
                      final int sharesCount = _parseInt(post["shares_count"] ?? post["shares"]);
                      final bool isLiked = _parseBool(post["is_liked"] ?? post["isLiked"]);
                      final bool isBookmarked = _parseBool(
                        post["is_bookmarked"] ??
                            post["isBookmarked"] ??
                            post["is_saved"] ??
                            post["isSaved"],
                      );

                      final String rawAuthor = (post["author_username"] ?? post["username"] ?? "").toString().trim();
                      final String authorUsername = isHydrating && rawAuthor.isEmpty
                          ? "Loading..."
                          : (rawAuthor.isNotEmpty
                              ? rawAuthor
                              : (post["author_id"]?.toString() == AuthService().userId && AuthService().userUsername.isNotEmpty
                                  ? AuthService().userUsername
                                  : "Traveler"));
                      final String? authorPic = post["author_profile_picture"]?.toString();
                      final String resolvedAuthorPic = _resolveMediaUrl(authorPic);
                      final bool isVerified = _parseBool(post["author_is_verified"]) ||
                          _parseBool(post["is_verified"]) ||
                          authorUsername.toLowerCase() == 'hidely_official' ||
                          authorUsername.toLowerCase() == 'hidely';

                      final String imageUrl = (post["image_url"] ?? (post["image"] is String ? post["image"] : "") ?? "").toString();
                      final String resolvedMediaUrl = _resolveMediaUrl(imageUrl);
                      final bool isAsset = _parseBool(post["isAsset"]) || imageUrl.startsWith("assets/");
                      final bool isVideo = _isVideoMedia(post, imageUrl);
                      final bool isMe = rawAuthor.isNotEmpty
                          ? rawAuthor == AuthService().userUsername
                          : (post["author_id"] != null &&
                              AuthService().userId.isNotEmpty &&
                              post["author_id"].toString() == AuthService().userId);

                      return Column(
                        key: index < _postKeys.length ? _postKeys[index] : null,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isHydrating)
                            const LinearProgressIndicator(
                              minHeight: 2,
                              color: Color(0xff5D3EBC),
                              backgroundColor: Color(0xffE2E8F0),
                            ),
                          // Post Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: isHydrating
                                      ? null
                                      : () {
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
                                                  avatarPath: resolvedAuthorPic.isNotEmpty
                                                      ? resolvedAuthorPic
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
                                          Flexible(
                                            child: GestureDetector(
                                              onTap: isHydrating
                                                  ? null
                                                  : () {
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
                                                              avatarPath: resolvedAuthorPic.isNotEmpty
                                                                  ? resolvedAuthorPic
                                                                  : "assets/images/nomad_nate_avatar.png",
                                                              rank: "Gold",
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      authorUsername,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14.5,
                                                        color: isHydrating ? Colors.black45 : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isVerified) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.verified_rounded, color: Color(0xff2563EB), size: 15),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isMe && !isHydrating && rawAuthor.isNotEmpty) ...[
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
                                      if (!isHydrating)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: rawLocation.isEmpty
                                                    ? null
                                                    : () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => LocationDetailScreen(
                                                              title: (post["title"] ?? location).toString(),
                                                              location: location,
                                                              image: isAsset ? imageUrl : resolvedMediaUrl,
                                                              category: (post["category"] ?? "All").toString(),
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
                                  onTap: isHydrating
                                      ? null
                                      : () async {
                                          await showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            builder: (context) => PostOptionsBottomSheet(post: post),
                                          );
                                          if (mounted) {
                                            setState(() {});
                                            FeedScreen.activeState?.syncPostLocally(post);
                                          }
                                        },
                                  child: Image.asset(
                                    'assets/icons/Menu.png',
                                    width: 20,
                                    height: 20,
                                    color: isHydrating ? Colors.black26 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Post Image / Video Preview
                          GestureDetector(
                            onDoubleTap: () => _toggleLike(index),
                            child: Stack(
                              children: [
                                if (isVideo)
                                  FeedVideoPlayer(
                                    videoUrl: post["image"] is File
                                        ? (post["image"] as File).path
                                        : resolvedMediaUrl,
                                  )
                                else
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
                                                : (resolvedMediaUrl.isEmpty
                                                    ? Center(
                                                        child: isHydrating
                                                            ? const CircularProgressIndicator(color: Color(0xff2B1564))
                                                            : const Icon(Icons.image, color: Colors.white24, size: 40),
                                                      )
                                                    : CachedNetworkImage(
                                                        imageUrl: resolvedMediaUrl,
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: 1080,
                                                        placeholder: (context, url) => Container(color: const Color(0xffF1F5F9)),
                                                        errorWidget: (context, url, error) => Container(
                                                          color: const Color(0xffCBD5E1),
                                                          child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                                        ),
                                                      ))),
                                      ),
                                    ),
                                  ),
                                if (!isHydrating && rawLocation.isNotEmpty && rawLocation.toLowerCase() != "unknown")
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: GestureDetector(
                                      onTap: () {
                                        MapDiscoveryScreen.initialSearchQuery = rawLocation;
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
                                  key: ValueKey('single_post_like_$index'),
                                  onTap: () => _toggleLike(index),
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
                                              color: isHydrating ? Colors.black38 : Colors.black87,
                                              width: 24,
                                              height: 24,
                                            ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isHydrating && !post.containsKey('likes_count') && !post.containsKey('likes')
                                            ? '...'
                                            : "$likes",
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  key: ValueKey('single_post_comment_$index'),
                                  onTap: () => _openComments(index),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/icons/uit_comment-dots.png',
                                        color: isHydrating ? Colors.black38 : Colors.black87,
                                        width: 22,
                                        height: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isHydrating && !post.containsKey('comments_count') && !post.containsKey('comments')
                                            ? '...'
                                            : "$commentsCount",
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  key: ValueKey('single_post_share_$index'),
                                  onTap: isHydrating
                                      ? null
                                      : () {
                                          final postIdStr = (parsedPostId ?? post["id"])?.toString();
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => ShareSheetWidget(
                                              postId: postIdStr,
                                              shareUrl: postIdStr != null ? 'https://hidely.kittuvirusstudio.in/post/$postIdStr' : null,
                                            ),
                                          );
                                        },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/icons/solar_share-linear.png',
                                        color: isHydrating ? Colors.black38 : Colors.black87,
                                        width: 22,
                                        height: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text("$sharesCount", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  key: ValueKey('single_post_bookmark_$index'),
                                  onTap: () => _toggleBookmark(index),
                                  child: Icon(
                                    isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                    color: isHydrating ? Colors.black38 : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Caption
                          if (!isHydrating)
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
                              child: MentionText(
                                prefixUsername: authorUsername,
                                text: caption,
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                        ],
                      );
                    }),
                  ),
                ),
              ),
      ),
    );
  }
}
