import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

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
    }
  }

  Future<void> _markAllAsRead() async {
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;

    final result = await ApiService().markNotificationsAsRead(token: token);
    if (result.success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markSingleAsRead(dynamic notification) async {
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;

    final notifId = notification['id'] ?? (notification['_id'] is int ? notification['_id'] : int.tryParse(notification['_id']?.toString() ?? '0') ?? 0);
    if (notifId is int && notifId > 0 && notification['is_read'] != true) {
      setState(() {
        notification['is_read'] = true;
      });
      ApiService().markSingleNotificationAsRead(token: token, notificationId: notifId);
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays == 1) return '1d';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }

  Map<String, List<dynamic>> _groupNotifications() {
    final now = DateTime.now();
    final newItems = <dynamic>[];
    final today = <dynamic>[];
    final yesterday = <dynamic>[];
    final thisWeek = <dynamic>[];
    final older = <dynamic>[];

    for (final n in _notifications) {
      final isRead = n['is_read'] == true || n['is_read'] == 1 || n['is_read'] == 'true';
      if (!isRead) {
        newItems.add(n);
        continue;
      }
      final raw = n['created_at'];
      if (raw == null) {
        older.add(n);
        continue;
      }
      final dt = DateTime.tryParse(raw.toString())?.toLocal();
      if (dt == null) {
        older.add(n);
        continue;
      }
      final diff = now.difference(dt);
      if (diff.inHours < 24) {
        today.add(n);
      } else if (diff.inDays < 2) {
        yesterday.add(n);
      } else if (diff.inDays < 7) {
        thisWeek.add(n);
      } else {
        older.add(n);
      }
    }
    return {
      'New': newItems,
      'Today': today,
      'Yesterday': yesterday,
      'This Week': thisWeek,
      'Older': older,
    };
  }

  (IconData, Color) _typeIconAndColor(String? type) {
    switch (type) {
      case 'like':
      case 'new_like':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'comment':
      case 'new_comment':
        return (Icons.mode_comment_rounded, const Color(0xFF2196F3));
      case 'comment_like':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'follow':
      case 'new_follower':
        return (Icons.person_add_rounded, const Color(0xFF9C27B0));
      case 'new_post':
        return (Icons.photo_camera_rounded, const Color(0xFF00BCD4));
      case 'official_hidely_post':
        return (Icons.stars_rounded, const Color(0xFFFF9800));
      case 'points_earned':
        return (Icons.star_rounded, const Color(0xFFFFC107));
      default:
        return (Icons.notifications_rounded, const Color(0xFF2B1564));
    }
  }

  String _buildActionText(dynamic notification) {
    final type = notification['type'] as String?;
    final actorName = (notification['actor_name'] ?? notification['actor_username'] ?? 'Someone').toString();
    final text = notification['text']?.toString() ?? '';

    if (text.isNotEmpty) {
      if (text.startsWith(actorName)) {
        return text.replaceFirst(actorName, '').trim();
      }
      return text;
    }

    switch (type) {
      case 'like':
      case 'new_like':
        return 'liked your post.';
      case 'comment':
      case 'new_comment':
        return 'commented on your post.';
      case 'comment_like':
        return 'liked your comment.';
      case 'follow':
      case 'new_follower':
        return 'started following you.';
      case 'new_post':
        return 'shared a new post.';
      case 'official_hidely_post':
        return 'posted a new featured hidden place!';
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
    if (postId == null) return;
    final postData = {
      'id': postId,
      if (postImg != null && postImg.isNotEmpty) 'image_url': postImg,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePostViewScreen(
          posts: [postData],
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
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xff1C0D5A),
                              size: 18.0,
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
                      if (_notifications.any((n) => n['is_read'] != true && n['is_read'] != 1 && n['is_read'] != 'true'))
                        TextButton.icon(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xff2B1564)),
                          label: const Text(
                            'Mark all read',
                            style: TextStyle(
                              color: Color(0xff2B1564),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                            onRefresh: () => _loadNotifications(refresh: true),
                            child: _notifications.isEmpty ? _buildEmptyState() : _buildGroupedList(),
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

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xff2B1564).withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 54,
                    color: Color(0xff2B1564),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No Notifications Yet",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "When people like your posts, comment, follow you, or earn points, you'll see them right here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupNotifications();
    final groupOrder = ['New', 'Today', 'Yesterday', 'This Week', 'Older'];
    final items = <Widget>[];

    for (final groupName in groupOrder) {
      final groupList = groups[groupName] ?? [];
      if (groupList.isEmpty) continue;

      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            groupName,
            style: const TextStyle(
              color: Color(0xff1C0D5A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.only(bottom: 32),
      children: items,
    );
  }

  Widget _buildNotificationTile(dynamic notification) {
    final type = notification['type'] as String?;
    final actorName = (notification['actor_name'] ?? notification['actor_username'] ?? 'User').toString();
    final actorPic = notification['actor_profile_picture']?.toString();
    final actorUsername = notification['actor_username']?.toString() ?? 'user';
    final bool isVerified = notification['actor_is_verified'] == true || notification['actor_is_verified'] == 1 || notification['actor_is_verified'] == 'true';
    final postImg = notification['post_image_url']?.toString();
    final postId = notification['post_id'];
    final bool isRead = notification['is_read'] == true || notification['is_read'] == 1 || notification['is_read'] == 'true';
    final timeAgo = notification['created_at'] != null ? _formatTime(notification['created_at'].toString()) : '';
    final actionText = _buildActionText(notification);
    final (typeIcon, typeColor) = _typeIconAndColor(type);

    return InkWell(
      onTap: () {
        _markSingleAsRead(notification);
        if (type == 'follow' || type == 'new_follower') {
          _openProfile(actorUsername, actorPic);
        } else if (type == 'like' || type == 'comment' || type == 'new_like' || type == 'new_comment' || postImg != null) {
          _openPost(postId, postImg);
        } else {
          _openProfile(actorUsername, actorPic);
        }
      },
      child: Container(
        color: isRead ? Colors.transparent : const Color(0xffEEF2FF).withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instagram Style Gradient Ring Avatar
            GestureDetector(
              onTap: () => _openProfile(actorUsername, actorPic),
              child: Stack(
                children: [
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
                        avatarUrl: actorPic,
                        displayName: actorName,
                        radius: 20,
                      ),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$actorName ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff1C0D5A),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                              TextSpan(
                                text: actionText,
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black.withOpacity(0.75),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xff3897F0),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.45),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xff3897F0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right side: Post Image Thumbnail OR Follow Button
            if (type == 'follow' || type == 'new_follower')
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
    if (_loading || widget.actorUsername == null || widget.actorUsername!.isEmpty) return;
    setState(() => _loading = true);
    final token = AuthService().token ?? '';
    if (token.isNotEmpty) {
      final res = await ApiService().toggleFollowCreator(token: token, creatorId: widget.actorUsername!);
      if (res.success && mounted) {
        setState(() {
          _following = !_following;
          _loading = false;
        });
        return;
      }
    }
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
