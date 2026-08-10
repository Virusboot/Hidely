import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadNotifications();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (AuthService().isGuest) {
      setState(() => _isLoading = false);
      return;
    }
    if (refresh) setState(() => _isRefreshing = true);

    final token = AuthService().token ?? '';
    final result = await ApiService().getNotifications(token: token);
    if (mounted) {
      setState(() {
        _notifications = result.data?['notifications'] ?? [];
        _isLoading = false;
        _isRefreshing = false;
      });
      _fadeController.forward(from: 0);

      if (token.isNotEmpty && _notifications.isNotEmpty) {
        ApiService().markNotificationsAsRead(token: token);
      }
    }
  }

  List<dynamic> get _effectiveNotifications {
    if (_notifications.isNotEmpty) return _notifications;
    return [
      {
        'id': '101',
        'type': 'like',
        'actor_name': 'Eleni K.',
        'actor_username': 'eleni_k',
        'actor_profile_picture': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        'post_image_url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=300',
        'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        'text': 'liked your post.',
        'is_read': false,
      },
      {
        'id': '102',
        'type': 'follow',
        'actor_name': 'Aarav Sharma',
        'actor_username': 'aarav_s',
        'actor_profile_picture': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'text': 'started following you.',
        'is_read': false,
      },
      {
        'id': '103',
        'type': 'comment',
        'actor_name': 'Priya Verma',
        'actor_username': 'priya_v',
        'actor_profile_picture': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
        'post_image_url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300',
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'text': 'commented: "Stunning view! 🔥"',
        'is_read': true,
      },
      {
        'id': '104',
        'type': 'follow',
        'actor_name': 'Sneha Kapoor',
        'actor_username': 'sneha_k',
        'actor_profile_picture': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'text': 'started following you.',
        'is_read': true,
      },
      {
        'id': '105',
        'type': 'like',
        'actor_name': 'Rohan Gupta',
        'actor_username': 'rohan_g',
        'actor_profile_picture': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        'post_image_url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=300',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'text': 'liked your post.',
        'is_read': true,
      },
    ];
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }

  Map<String, List<dynamic>> _groupNotifications() {
    final list = _effectiveNotifications;
    final now = DateTime.now();
    final today = <dynamic>[];
    final thisWeek = <dynamic>[];
    final earlier = <dynamic>[];

    for (final n in list) {
      final raw = n['created_at'];
      if (raw == null) {
        earlier.add(n);
        continue;
      }
      final dt = DateTime.tryParse(raw.toString())?.toLocal();
      if (dt == null) {
        earlier.add(n);
        continue;
      }
      final diff = now.difference(dt);
      if (diff.inDays < 1) {
        today.add(n);
      } else if (diff.inDays < 7) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }
    return {'Today': today, 'This Week': thisWeek, 'Earlier': earlier};
  }

  (IconData, Color) _typeIconAndColor(String? type) {
    switch (type) {
      case 'like':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'comment':
        return (Icons.mode_comment_rounded, const Color(0xFF2196F3));
      case 'comment_like':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'follow':
        return (Icons.person_add_rounded, const Color(0xFF9C27B0));
      case 'new_post':
        return (Icons.photo_camera_rounded, const Color(0xFF00BCD4));
      case 'points_earned':
        return (Icons.star_rounded, const Color(0xFFFFC107));
      default:
        return (Icons.notifications_rounded, const Color(0xFF607D8B));
    }
  }

  String _buildActionText(dynamic notification) {
    final type = notification['type'] as String?;
    final actorName = (notification['actor_name'] ??
            notification['actor_username'] ??
            'Someone')
        .toString();
    final text = notification['text']?.toString() ?? '';

    if (text.isNotEmpty) {
      if (text.startsWith(actorName)) {
        return text.replaceFirst(actorName, '').trim();
      }
      return text;
    }

    switch (type) {
      case 'like':
        return 'liked your post.';
      case 'comment':
        return 'commented on your post.';
      case 'comment_like':
        return 'liked your comment.';
      case 'follow':
        return 'started following you.';
      case 'new_post':
        return 'shared a new post.';
      case 'points_earned':
        return 'You earned points!';
      default:
        return 'sent you a notification.';
    }
  }

  void _openProfile(String? username, String? pic) {
    if (username == null || username.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorProfileScreen(
          username: username,
          avatarPath: pic ?? 'assets/images/nomad_nate_avatar.png',
          rank: 'Explorer',
        ),
      ),
    );
  }

  void _openPost(dynamic postId, String? postImg) {
    final mockPost = {
      'id': postId ?? 1,
      'image_url': postImg ?? 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600',
      'caption': 'Exploring breathtaking views! 🌄✨',
      'likes_count': 142,
      'comments_count': 18,
      'author_username': 'traveler',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePostViewScreen(
          posts: [mockPost],
          initialIndex: 0,
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
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffEEF2FF), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
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
                      const SizedBox(width: 14),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      if (_isRefreshing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff2B1564),
                          ),
                        ),
                    ],
                  ),
                ),

                // Body List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xff2B1564),
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: RefreshIndicator(
                            color: const Color(0xff2B1564),
                            onRefresh: () =>
                                _loadNotifications(refresh: true),
                            child: _buildGroupedList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupNotifications();
    final groupOrder = ['Today', 'This Week', 'Earlier'];
    final items = <Widget>[];

    for (final groupName in groupOrder) {
      final groupList = groups[groupName] ?? [];
      if (groupList.isEmpty) continue;

      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(
            groupName,
            style: const TextStyle(
              color: Color(0xff1C0D5A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      );

      for (final notif in groupList) {
        items.add(_buildNotificationTile(notif));
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      children: items,
    );
  }

  Widget _buildNotificationTile(dynamic notification) {
    final type = notification['type'] as String?;
    final actorName = (notification['actor_name'] ??
            notification['actor_username'] ??
            'User')
        .toString();
    final actorPic = notification['actor_profile_picture']?.toString();
    final actorUsername = notification['actor_username']?.toString() ?? 'user';
    final postImg = notification['post_image_url']?.toString();
    final postId = notification['post_id'];
    final isRead = notification['is_read'] == true;
    final timeAgo = notification['created_at'] != null
        ? _formatTime(notification['created_at'].toString())
        : '';
    final actionText = _buildActionText(notification);
    final (typeIcon, typeColor) = _typeIconAndColor(type);

    return GestureDetector(
      onTap: () {
        if (type == 'follow') {
          _openProfile(actorUsername, actorPic);
        } else if (type == 'like' || type == 'comment' || postImg != null) {
          _openPost(postId, postImg);
        } else {
          _openProfile(actorUsername, actorPic);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: isRead ? Colors.transparent : const Color(0xffEEF2FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar (Tap opens profile)
            GestureDetector(
              onTap: () => _openProfile(actorUsername, actorPic),
              child: Stack(
                children: [
                  ClipOval(
                    child: Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xffCBD5E1),
                      child: _buildAvatar(actorPic, actorName),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(typeIcon, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Notification Message & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$actorName ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1C0D5A),
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        TextSpan(
                          text: actionText,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.4),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right side: Post Image Thumbnail OR Follow Button
            if (type == 'follow')
              _FollowButton(actorUsername: actorUsername)
            else if (postImg != null && postImg.isNotEmpty)
              GestureDetector(
                onTap: () => _openPost(postId, postImg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildThumbnail(postImg),
                ),
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? picPath, String name) {
    if (picPath != null && picPath.isNotEmpty) {
      if (picPath.startsWith('http://') || picPath.startsWith('https://')) {
        return Image.network(
          picPath,
          fit: BoxFit.cover,
          width: 44,
          height: 44,
          errorBuilder: (_, __, ___) => _initialsAvatar(name),
        );
      }
      if (picPath.startsWith('assets/')) {
        return Image.asset(
          picPath,
          fit: BoxFit.cover,
          width: 44,
          height: 44,
          errorBuilder: (_, __, ___) => _initialsAvatar(name),
        );
      }
      final fullUrl = picPath.startsWith('/')
          ? '${ApiService().baseUrl}$picPath'
          : '${ApiService().baseUrl}/$picPath';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        width: 44,
        height: 44,
        errorBuilder: (_, __, ___) => _initialsAvatar(name),
      );
    }
    return _initialsAvatar(name);
  }

  Widget _initialsAvatar(String name) {
    final char = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xff1C0D5A).withOpacity(0.08),
      alignment: Alignment.center,
      child: Text(
        char,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xff1C0D5A),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildThumbnail(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumbnail(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumbnail(),
      );
    }
    final fullUrl = path.startsWith('/')
        ? '${ApiService().baseUrl}$path'
        : '${ApiService().baseUrl}/$path';
    return Image.network(
      fullUrl,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackThumbnail(),
    );
  }

  Widget _fallbackThumbnail() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xffE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_rounded, size: 20, color: Color(0xff94A3B8)),
      );
}

// ── Follow Button widget ─────────────────────────────────────────────────────
class _FollowButton extends StatefulWidget {
  final String? actorUsername;
  const _FollowButton({this.actorUsername});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;
  bool _loading = false;

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _following = !_following;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _following ? const Color(0xFFF1F5F9) : const Color(0xff1C0D5A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _following ? const Color(0xFFCBD5E1) : const Color(0xff1C0D5A),
            width: 1,
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xff1C0D5A),
                ),
              )
            : Text(
                _following ? 'Following' : 'Follow',
                style: TextStyle(
                  color: _following ? const Color(0xff1C0D5A) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
      ),
    );
  }
}
