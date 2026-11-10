import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/login_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/tags_and_mentions_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
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
  bool _isGuest = false;
  bool _isSessionExpired = false;
  bool _isSelfSync = false;
  String? _errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  final Set<String> _followingUserIds = {};

  static const Set<String> _systemNotificationTypes = {
    'points_earned',
    'level_up',
    'badge_earned',
    'place_discovered',
    'official_hidely_post',
    'weekly_travel_suggestions',
    'system_announcement',
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    AuthService().blockedUsersNotifier.addListener(_onBlockedUsersChanged);
    NotificationPollingService()
        .notificationsNotifier
        .addListener(_onServiceNotificationsChanged);
    _initAndLoadNotifications();
  }

  @override
  void dispose() {
    AuthService().blockedUsersNotifier.removeListener(_onBlockedUsersChanged);
    NotificationPollingService()
        .notificationsNotifier
        .removeListener(_onServiceNotificationsChanged);
    _fadeController.dispose();
    super.dispose();
  }

  bool _isFromBlockedUser(dynamic n) {
    if (n is! Map) return false;
    final type = n['type']?.toString();
    if (_isSystemType(type)) return false;
    return AuthService().isUserBlockedSync(n['actor_username']?.toString());
  }

  List<dynamic> _filterNotifications(List<dynamic> items) {
    return items.where((n) => !_isFromBlockedUser(n)).toList();
  }

  void _onBlockedUsersChanged() {
    if (!mounted) return;
    setState(() {
      _notifications = _filterNotifications(_notifications);
    });
  }

  void _onServiceNotificationsChanged() {
    if (!mounted || _isSelfSync || _isLoading) return;
    final latest = NotificationPollingService().notificationsNotifier.value;
    if (latest.isNotEmpty) {
      setState(() {
        _notifications = _filterNotifications(
          latest
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
        if (!NotificationPollingService().sessionExpiredNotifier.value) {
          _isSessionExpired = false;
          _errorMessage = null;
        }
      });
    }
  }

  Future<void> _initAndLoadNotifications() async {
    final token = AuthService().token ?? '';
    if (AuthService().isGuest || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isGuest = true;
          _isSessionExpired = false;
          _errorMessage = null;
          _notifications = [];
          _isLoading = false;
        });
        _fadeController.value = 1.0;
      }
      return;
    }

    // Immediately hydrate any cached notifications so notifications already received
    // on this device never disappear behind a loading spinner or transient error.
    final memoryCached = _filterNotifications(
      NotificationPollingService().notificationsNotifier.value,
    );
    if (memoryCached.isNotEmpty && mounted) {
      setState(() {
        _notifications = List<dynamic>.from(memoryCached);
        _isLoading = false;
      });
      _fadeController.value = 1.0;
    } else {
      final diskCached = _filterNotifications(
        await NotificationPollingService().loadCachedNotifications(),
      );
      if (diskCached.isNotEmpty && mounted) {
        setState(() {
          _notifications = List<dynamic>.from(diskCached);
          _isLoading = false;
        });
        _fadeController.value = 1.0;
      }
    }

    await _loadNotifications(refresh: _notifications.isNotEmpty);
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    final token = AuthService().token ?? '';
    if (AuthService().isGuest || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isGuest = true;
          _isSessionExpired = false;
          _errorMessage = null;
          _notifications = [];
          _isLoading = false;
          _isRefreshing = false;
        });
        _fadeController.value = 1.0;
      }
      return;
    }

    if (refresh && mounted) {
      setState(() => _isRefreshing = true);
    }

    final results = await Future.wait([
      ApiService().getNotifications(token: token, limit: 50),
      ApiService().getFollowing(token: token),
    ]);

    final notifResult = results[0];
    final followingResult = results[1];

    if (!mounted) return;

    if (followingResult.success && followingResult.data != null) {
      final Set<String> updatedFollowing = {};
      final list = followingResult.data?['following'] as List? ?? [];
      for (var user in list) {
        if (user is Map) {
          if (user['id'] != null) updatedFollowing.add(user['id'].toString());
          if (user['_id'] != null) updatedFollowing.add(user['_id'].toString());
          if (user['username'] != null) {
            updatedFollowing.add(user['username'].toString().toLowerCase());
          }
        }
      }
      _followingUserIds
        ..clear()
        ..addAll(updatedFollowing);
    }

    if (notifResult.success) {
      final rawList = notifResult.data?['notifications'];
      final fetched = _filterNotifications(
        rawList is List ? List<dynamic>.from(rawList) : <dynamic>[],
      );
      final int? unreadCount = notifResult.data?['unread_count'] is int
          ? notifResult.data!['unread_count'] as int
          : null;

      NotificationPollingService().sessionExpiredNotifier.value = false;
      _isSelfSync = true;
      try {
        await NotificationPollingService().syncFromNotifications(
          fetched,
          unreadCount: unreadCount,
        );
      } finally {
        _isSelfSync = false;
      }

      if (!mounted) return;
      final bool shouldAnimate = _isLoading || _notifications.isEmpty;
      setState(() {
        _isGuest = false;
        _notifications = fetched;
        _isSessionExpired = false;
        _errorMessage = null;
        _isLoading = false;
        _isRefreshing = false;
      });
      if (shouldAnimate) {
        _fadeController.forward(from: 0);
      } else {
        _fadeController.value = 1.0;
      }
    } else {
      final errText = (notifResult.error ?? notifResult.message).toLowerCase();
      final bool expired = notifResult.isUnauthorized ||
          errText.contains('expired') ||
          errText.contains('token is invalid') ||
          errText.contains('unauthorized') ||
          errText.contains('not authenticated');

      if (expired) {
        NotificationPollingService().sessionExpiredNotifier.value = true;
      }

      setState(() {
        _isGuest = false;
        _isSessionExpired = expired;
        _errorMessage = expired
            ? 'Your login session has expired. Please log in again to load the latest notifications.'
            : (notifResult.message.isNotEmpty
                ? notifResult.message
                : 'Unable to load notifications right now.');
        _isLoading = false;
        _isRefreshing = false;
      });
      _fadeController.value = 1.0;
    }
  }

  Future<void> _loadFollowingList() async {
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;

    final followingResult = await ApiService().getFollowing(token: token);
    if (followingResult.success && followingResult.data != null && mounted) {
      final list = followingResult.data?['following'] as List? ?? [];
      final Set<String> updatedFollowing = {};
      for (var user in list) {
        if (user is Map) {
          if (user['id'] != null) updatedFollowing.add(user['id'].toString());
          if (user['_id'] != null) updatedFollowing.add(user['_id'].toString());
          if (user['username'] != null) {
            updatedFollowing.add(user['username'].toString().toLowerCase());
          }
        }
      }
      setState(() {
        _followingUserIds.clear();
        _followingUserIds.addAll(updatedFollowing);
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;

    final result = await ApiService().markNotificationsAsRead(token: token);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (var n in _notifications) {
          if (n is Map) {
            n['is_read'] = true;
          }
        }
      });
      final int unreadCount = result.data?['unread_count'] is int
          ? result.data!['unread_count'] as int
          : 0;
      _isSelfSync = true;
      try {
        await NotificationPollingService().syncFromNotifications(
          _notifications,
          unreadCount: unreadCount,
        );
      } finally {
        _isSelfSync = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : 'Could not mark notifications as read.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markSingleAsRead(dynamic notification) async {
    if (notification is! Map) return;
    final token = AuthService().token ?? '';
    if (token.isEmpty) return;

    final notifId = NotificationPollingService.parseNotificationId(notification);
    if (notifId > 0 && NotificationPollingService.isUnreadNotification(notification)) {
      setState(() {
        notification['is_read'] = true;
      });
      _isSelfSync = true;
      await NotificationPollingService()
          .syncFromNotifications(_notifications)
          .whenComplete(() => _isSelfSync = false);
      final res = await ApiService().markSingleNotificationAsRead(
        token: token,
        notificationId: notifId,
      );
      if (res.success && res.data?['unread_count'] is int) {
        _isSelfSync = true;
        try {
          await NotificationPollingService().syncFromNotifications(
            _notifications,
            unreadCount: res.data!['unread_count'] as int,
          );
        } finally {
          _isSelfSync = false;
        }
      }
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
      if (_isFromBlockedUser(n)) continue;
      final isRead = !NotificationPollingService.isUnreadNotification(n);
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

  bool _isSystemType(String? type) =>
      type != null && _systemNotificationTypes.contains(type);

  String _resolveActorName(dynamic notification, String? type) {
    final rawName = (notification['actor_name'] ?? '').toString().trim();
    if (rawName.isNotEmpty) return rawName;
    final rawUsername = (notification['actor_username'] ?? '').toString().trim();
    if (rawUsername.isNotEmpty) return rawUsername;
    return _isSystemType(type) ? 'Hidely' : 'Explorer';
  }

  (IconData, Color) _typeIconAndColor(String? type) {
    switch (type) {
      case 'like':
      case 'new_like':
      case 'post_liked':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'comment':
      case 'new_comment':
        return (Icons.mode_comment_rounded, const Color(0xFF2196F3));
      case 'comment_like':
        return (Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'follow':
      case 'new_follower':
        return (Icons.person_add_rounded, const Color(0xFF9C27B0));
      case 'message':
      case 'new_message':
        return (Icons.chat_bubble_rounded, const Color(0xFF4F46E5));
      case 'tag':
      case 'tag_request':
        return (Icons.local_offer_rounded, const Color(0xFF3949AB));
      case 'mention':
        return (Icons.alternate_email_rounded, const Color(0xFF5D3EBC));
      case 'new_post':
        return (Icons.photo_camera_rounded, const Color(0xFF00BCD4));
      case 'official_hidely_post':
        return (Icons.stars_rounded, const Color(0xFFFF9800));
      case 'points_earned':
        return (Icons.star_rounded, const Color(0xFFFFC107));
      case 'level_up':
        return (Icons.emoji_events_rounded, const Color(0xFFF59E0B));
      case 'badge_earned':
        return (Icons.workspace_premium_rounded, const Color(0xFF8B5CF6));
      case 'place_discovered':
        return (Icons.location_on_rounded, const Color(0xFF10B981));
      case 'weekly_travel_suggestions':
        return (Icons.explore_rounded, const Color(0xFF06B6D4));
      case 'system_announcement':
        return (Icons.campaign_rounded, const Color(0xFF2B1564));
      default:
        return (Icons.notifications_rounded, const Color(0xFF2B1564));
    }
  }

  String _buildActionText(dynamic notification) {
    final type = notification['type']?.toString();
    final actorName = _resolveActorName(notification, type);
    final text = (notification['text'] ?? notification['body'] ?? '').toString().trim();

    if (text.isNotEmpty) {
      if (actorName.isNotEmpty &&
          text.toLowerCase().startsWith('${actorName.toLowerCase()} ')) {
        return text.substring(actorName.length).trimLeft();
      }
      return text;
    }

    switch (type) {
      case 'like':
      case 'new_like':
      case 'post_liked':
        return 'liked your post.';
      case 'comment':
      case 'new_comment':
        return 'commented on your post.';
      case 'comment_like':
        return 'liked your comment.';
      case 'follow':
      case 'new_follower':
        return 'started following you.';
      case 'message':
      case 'new_message':
        return 'sent you a message.';
      case 'tag':
        return 'tagged you in a post.';
      case 'tag_request':
        return 'tagged you in a post. Tap to review.';
      case 'mention':
        return 'mentioned you.';
      case 'new_post':
        return 'shared a new post.';
      case 'official_hidely_post':
        return 'posted a new featured hidden place!';
      case 'weekly_travel_suggestions':
        return 'Explore handpicked weekend getaways!';
      case 'points_earned':
        return 'You earned points!';
      case 'level_up':
        return 'Congratulations on leveling up!';
      case 'badge_earned':
        return 'You unlocked a new badge!';
      case 'place_discovered':
        return 'Your hidden place discovery was verified!';
      case 'system_announcement':
        return 'shared an update.';
      default:
        return 'sent you a notification.';
    }
  }

  Future<void> _openProfile(String? username, String? pic) async {
    final cleaned = (username ?? '').trim();
    if (cleaned.isEmpty ||
        cleaned.toLowerCase() == 'user' ||
        cleaned.toLowerCase() == 'hidely') {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorProfileScreen(
          username: cleaned,
          avatarPath: (pic != null && pic.isNotEmpty)
              ? pic
              : 'assets/images/nomad_nate_avatar.png',
          rank: 'Explorer',
        ),
      ),
    );
    if (mounted) {
      _loadFollowingList();
    }
  }

  void _openPost(dynamic postId, String? postImg) {
    if (postId == null) return;
    final dynamic normalizedId = int.tryParse(postId.toString()) ?? postId;
    final Map<String, dynamic> postData = {
      'id': normalizedId,
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

  Future<void> _openLoginScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      _loadNotifications(refresh: true);
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
                      const Expanded(
                        child: Text(
                          'Notifications',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (_notifications.any(
                          NotificationPollingService.isUnreadNotification))
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
                            child: _notifications.isEmpty
                                ? _buildEmptyOrStatusState()
                                : _buildGroupedList(),
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

  Widget _buildEmptyOrStatusState() {
    IconData icon = Icons.notifications_none_rounded;
    Color accent = const Color(0xff2B1564);
    String title = "No Notifications Yet";
    String subtitle =
        "When people like your posts, comment, follow you, or earn points, you'll see them right here.";
    bool showRetry = false;
    bool showLogin = false;

    if (_isGuest) {
      icon = Icons.lock_outline_rounded;
      title = "Sign In for Notifications";
      subtitle =
          "Log in to see likes, comments, new followers, messages, and rewards.";
      showLogin = true;
    } else if (_isSessionExpired) {
      icon = Icons.lock_clock_rounded;
      accent = const Color(0xFFD97706);
      title = "Session Expired";
      subtitle = _errorMessage ??
          "Your login session has expired. Please log in again to load your notifications.";
      showLogin = true;
      showRetry = true;
    } else if (_errorMessage != null) {
      icon = Icons.cloud_off_rounded;
      accent = const Color(0xFFE11D48);
      title = "Could Not Load Notifications";
      subtitle = _errorMessage!;
      showRetry = true;
    }

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
                    color: accent.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 54,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showLogin || showRetry) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (showLogin)
                        ElevatedButton.icon(
                          onPressed: _openLoginScreen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2B1564),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: Text(_isGuest ? 'Log In' : 'Log In Again'),
                        ),
                      if (showRetry)
                        OutlinedButton.icon(
                          onPressed: () => _loadNotifications(refresh: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2B1564),
                            side: const BorderSide(color: Color(0xff2B1564)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncBanner() {
    if (_errorMessage == null && !_isSessionExpired) {
      return const SizedBox.shrink();
    }
    final Color bg = _isSessionExpired
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFFF1F2);
    final Color border = _isSessionExpired
        ? const Color(0xFFFDE68A)
        : const Color(0xFFFECDD3);
    final Color fg = _isSessionExpired
        ? const Color(0xFF92400E)
        : const Color(0xFF9F1239);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            _isSessionExpired
                ? Icons.lock_clock_rounded
                : Icons.sync_problem_rounded,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isSessionExpired
                  ? 'Session expired — showing saved notifications. Log in again to sync.'
                  : 'Showing saved notifications. Pull down or tap retry to sync.',
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isSessionExpired
                ? _openLoginScreen
                : () => _loadNotifications(refresh: true),
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isSessionExpired ? 'Log In' : 'Retry',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupNotifications();
    final groupOrder = ['New', 'Today', 'Yesterday', 'This Week', 'Older'];
    final items = <Widget>[];

    if (_errorMessage != null || _isSessionExpired) {
      items.add(_buildSyncBanner());
    }

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
    final type = notification['type']?.toString();
    final actorName = _resolveActorName(notification, type);
    final actorPic = notification['actor_profile_picture']?.toString();
    final actorUsername = (notification['actor_username'] ?? '').toString().trim();
    final actorId = notification['actor_id']?.toString() ??
        notification['actor_user_id']?.toString() ??
        notification['user_id']?.toString();
    final bool isVerified = notification['actor_is_verified'] == true ||
        notification['actor_is_verified'] == 1 ||
        notification['actor_is_verified'] == 'true';
    final postImg = (notification['post_image_url'] ?? notification['image_url'])?.toString();
    final postId = notification['post_id'] ??
        notification['postId'] ??
        notification['target_id'];
    final bool isRead = !NotificationPollingService.isUnreadNotification(notification);
    final timeAgo = notification['created_at'] != null
        ? _formatTime(notification['created_at'].toString())
        : '';
    final actionText = _buildActionText(notification);
    final (typeIcon, typeColor) = _typeIconAndColor(type);

    final bool canOpenActorProfile = !_isSystemType(type) &&
        actorUsername.isNotEmpty &&
        actorUsername.toLowerCase() != 'user' &&
        actorUsername.toLowerCase() != 'hidely';

    final bool isFollowing = (actorId != null && _followingUserIds.contains(actorId)) ||
        (actorUsername.isNotEmpty &&
            _followingUserIds.contains(actorUsername.toLowerCase())) ||
        notification['actor_is_following'] == true ||
        notification['is_following'] == true;

    return InkWell(
      onTap: () {
        _markSingleAsRead(notification);
        if (type == 'follow' || type == 'new_follower') {
          if (canOpenActorProfile) {
            _openProfile(actorUsername, actorPic);
          }
        } else if (type == 'message' || type == 'new_message') {
          Navigator.of(context).popUntil((route) => route.isFirst);
          MainWrapperState.activeState?.setIndex(2);
        } else if (type == 'tag_request') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TagsAndMentionsScreen(),
            ),
          );
        } else if (postId != null &&
            (type == 'like' ||
                type == 'post_liked' ||
                type == 'comment' ||
                type == 'comment_like' ||
                type == 'new_like' ||
                type == 'new_comment' ||
                type == 'new_post' ||
                type == 'tag' ||
                type == 'mention' ||
                type == 'place_discovered' ||
                type == 'official_hidely_post' ||
                (postImg != null && postImg.isNotEmpty))) {
          _openPost(postId, postImg);
        } else if (canOpenActorProfile) {
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
              onTap: canOpenActorProfile
                  ? () => _openProfile(actorUsername, actorPic)
                  : null,
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
            if ((type == 'follow' || type == 'new_follower') &&
                canOpenActorProfile)
              _FollowButton(
                actorId: actorId,
                actorUsername: actorUsername,
                isFollowing: isFollowing,
                onToggle: (newStatus) {
                  setState(() {
                    if (actorId != null) {
                      if (newStatus) {
                        _followingUserIds.add(actorId);
                      } else {
                        _followingUserIds.remove(actorId);
                      }
                    }
                    if (actorUsername.isNotEmpty) {
                      if (newStatus) {
                        _followingUserIds.add(actorUsername.toLowerCase());
                      } else {
                        _followingUserIds.remove(actorUsername.toLowerCase());
                      }
                    }
                  });
                },
              )
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
  final String? actorId;
  final String? actorUsername;
  final bool isFollowing;
  final ValueChanged<bool>? onToggle;

  const _FollowButton({
    this.actorId,
    this.actorUsername,
    this.isFollowing = false,
    this.onToggle,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late bool _following;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _following = widget.isFollowing;
  }

  @override
  void didUpdateWidget(covariant _FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _following = widget.isFollowing;
    }
  }

  Future<void> _toggle() async {
    final targetId = widget.actorId ?? widget.actorUsername;
    if (_loading || targetId == null || targetId.isEmpty) return;
    setState(() => _loading = true);
    final token = AuthService().token ?? '';
    if (token.isNotEmpty) {
      final res = await ApiService().toggleFollowCreator(token: token, creatorId: targetId);
      if (mounted) {
        final bool newStatus = (res.success && res.data != null && res.data?['is_following'] != null)
            ? (res.data?['is_following'] == true)
            : !_following;
        setState(() {
          _following = newStatus;
          _loading = false;
        });
        widget.onToggle?.call(newStatus);
        return;
      }
    }
    if (mounted) {
      setState(() {
        _following = !_following;
        _loading = false;
      });
      widget.onToggle?.call(_following);
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
