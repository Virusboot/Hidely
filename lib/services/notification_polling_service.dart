import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/main.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/notification_screen.dart';
import 'package:hidely_new/screens/tags_and_mentions_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';

class NotificationPollingService with WidgetsBindingObserver {
  static final NotificationPollingService _instance = NotificationPollingService._internal();
  factory NotificationPollingService() => _instance;
  NotificationPollingService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  Future<void>? _initFuture;
  bool _isInitialized = false;
  bool _isPolling = false;
  DateTime? _pollStartedAt;
  bool _isAppBackgrounded = false;
  int _lastSeenId = 0;
  int _pollEpoch = 0;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<dynamic>> notificationsNotifier = ValueNotifier<List<dynamic>>(const []);
  final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier<bool>(false);

  String get _scopedUserKey {
    final uid = AuthService().userId.trim();
    if (uid.isNotEmpty) return uid;
    final uname = AuthService().userUsername.trim().toLowerCase();
    return uname.isNotEmpty ? uname : 'guest';
  }

  String get _lastSeenIdKey => 'last_seen_notification_id_$_scopedUserKey';
  String get _cachedNotificationsKey => 'cached_notifications_$_scopedUserKey';
  String get _cachedUnreadCountKey => 'cached_unread_count_$_scopedUserKey';

  static const Set<String> _systemNotificationTypes = {
    'points_earned',
    'level_up',
    'badge_earned',
    'place_discovered',
    'official_hidely_post',
    'weekly_travel_suggestions',
    'system_announcement',
  };

  static bool isUnreadNotification(dynamic notif) {
    if (notif is! Map) return false;
    final val = notif['is_read'];
    return !(val == true || val == 1 || val == 'true' || val == '1');
  }

  static int parseNotificationId(dynamic notif) {
    if (notif is! Map) return 0;
    final rawId = notif['id'] ?? notif['_id'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '0') ?? 0;
  }

  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      // Register lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      if (!kIsWeb) {
        // Initialize local notifications
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher_new');
        const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
        const InitializationSettings initSettings =
            InitializationSettings(android: androidSettings, iOS: iosSettings);

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            if (details.payload != null) {
              _handleNotificationClick(details.payload!);
            }
          },
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'hidely_notifications',
              'Hidely Notifications',
              description:
                  'Notifications for likes, comments, followers, messages, official posts, and travel digests',
              importance: Importance.max,
            ),
          );
          await androidPlugin.requestNotificationsPermission();
        }

        await _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      final prefs = await SharedPreferences.getInstance();
      _lastSeenId = prefs.getInt(_lastSeenIdKey) ?? 0;
      await loadCachedNotifications();

      _isInitialized = true;
      debugPrint('[NotificationPollingService] Initialized. Last seen ID: $_lastSeenId');
    } catch (e) {
      debugPrint('[NotificationPollingService] Initialization error: $e');
      _initFuture = null;
    }
  }

  Future<List<dynamic>> loadCachedNotifications() async {
    if (!AuthService().isLoggedIn || AuthService().isGuest) {
      notificationsNotifier.value = const [];
      unreadCountNotifier.value = 0;
      return const [];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cachedNotificationsKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          final cloned = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          notificationsNotifier.value = cloned;
          final storedUnread = prefs.getInt(_cachedUnreadCountKey);
          unreadCountNotifier.value =
              storedUnread ?? cloned.where(isUnreadNotification).length;
          return cloned;
        }
      }
      final storedUnread = prefs.getInt(_cachedUnreadCountKey) ?? 0;
      unreadCountNotifier.value = storedUnread;
    } catch (e) {
      debugPrint('[NotificationPollingService] Cache read error: $e');
    }
    return notificationsNotifier.value;
  }

  Future<void> _saveCachedNotifications(List<dynamic> items, int unreadCount) async {
    final normalized = items
        .whereType<Map>()
        .take(100)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    notificationsNotifier.value = normalized;
    unreadCountNotifier.value = unreadCount;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedNotificationsKey, jsonEncode(normalized));
      await prefs.setInt(_cachedUnreadCountKey, unreadCount);
    } catch (e) {
      debugPrint('[NotificationPollingService] Cache write error: $e');
    }
  }

  /// Called by UI screens (e.g. NotificationScreen) to keep cache, badge, and lastSeenId synced.
  Future<void> syncFromNotifications(List<dynamic> notifications, {int? unreadCount}) async {
    final computedUnread = unreadCount ?? notifications.where(isUnreadNotification).length;
    await _saveCachedNotifications(notifications, computedUnread);

    int maxId = _lastSeenId;
    for (final notif in notifications) {
      final id = parseNotificationId(notif);
      if (id > maxId) maxId = id;
    }
    if (maxId > _lastSeenId) {
      _lastSeenId = maxId;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSeenIdKey, _lastSeenId);
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isAppBackgrounded = true;
      debugPrint('[NotificationPollingService] App backgrounded. Pausing polling execution.');
    } else if (state == AppLifecycleState.resumed) {
      _isAppBackgrounded = false;
      debugPrint('[NotificationPollingService] App resumed.');
      if (AuthService().isLoggedIn) {
        if (_pollingTimer == null || !_pollingTimer!.isActive) {
          startPolling();
        } else {
          refreshNow();
        }
      }
    }
  }

  void startPolling() {
    if (!AuthService().isLoggedIn || AuthService().isGuest) return;
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    debugPrint('[NotificationPollingService] Started polling every 15 seconds.');

    final int epoch = ++_pollEpoch;
    _isPolling = false;
    _pollStartedAt = null;
    sessionExpiredNotifier.value = false;

    Future(() async {
      if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
      await initialize();
      if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
      _lastSeenId = prefs.getInt(_lastSeenIdKey) ?? 0;
      await loadCachedNotifications();
      if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
      debugPrint(
        '[NotificationPollingService] Loaded last seen ID: $_lastSeenId for user: ${AuthService().userId}',
      );

      await _pollNotifications();
      if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (epoch != _pollEpoch || !AuthService().isLoggedIn) return;
        _pollNotifications();
      });
    });
  }

  void restartPolling() {
    stopPolling();
    startPolling();
  }

  Future<void> refreshNow() async {
    await _pollNotifications();
  }

  void stopPolling() {
    _pollEpoch++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _pollStartedAt = null;
    _lastSeenId = 0;
    unreadCountNotifier.value = 0;
    notificationsNotifier.value = const [];
    sessionExpiredNotifier.value = false;
    debugPrint('[NotificationPollingService] Stopped polling.');
  }

  Future<void> _pollNotifications() async {
    if (_isAppBackgrounded) return; // Skip polling when backgrounded
    if (_isPolling) {
      final stuckTooLong = _pollStartedAt != null &&
          DateTime.now().difference(_pollStartedAt!).inSeconds > 35;
      if (!stuckTooLong) {
        debugPrint('[NotificationPollingService] Skip tick — previous poll still in progress.');
        return;
      }
      debugPrint('[NotificationPollingService] Resetting stale poll lock after 35s timeout.');
      _isPolling = false;
    }
    if (!AuthService().isLoggedIn || AuthService().isGuest) return; // Don't poll for guests

    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    _isPolling = true;
    _pollStartedAt = DateTime.now();

    try {
      final result = await ApiService()
          .getNotifications(token: token, limit: 50)
          .timeout(const Duration(seconds: 30));

      if (result.success) {
        sessionExpiredNotifier.value = false;
        final rawList = result.data?['notifications'];
        final notificationsList = rawList is List ? rawList : const <dynamic>[];
        final int unreadCount = result.data?['unread_count'] is int
            ? result.data!['unread_count'] as int
            : notificationsList.where(isUnreadNotification).length;

        await _saveCachedNotifications(notificationsList, unreadCount);
        if (notificationsList.isEmpty) return;

        final prefs = await SharedPreferences.getInstance();
        final bool osNotificationsEnabled = prefs.getBool('enable_notifications') ?? true;

        int maxIdFound = _lastSeenId;
        int bannersShown = 0;

        for (var i = notificationsList.length - 1; i >= 0; i--) {
          final notif = notificationsList[i];
          if (notif is! Map) continue;
          final int notifId = parseNotificationId(notif);
          final bool isRead = !isUnreadNotification(notif);

          // If the notification is newer than our last seen, and it is unread, show a banner.
          if (notifId > _lastSeenId && !isRead) {
            if (osNotificationsEnabled && bannersShown < 5) {
              await _showLocalNotification(Map<String, dynamic>.from(notif));
              bannersShown++;
            }
            if (notifId > maxIdFound) {
              maxIdFound = notifId;
            }
          } else if (notifId > maxIdFound) {
            maxIdFound = notifId;
          }
        }

        // Update last seen ID
        if (maxIdFound > _lastSeenId) {
          _lastSeenId = maxIdFound;
          await prefs.setInt(_lastSeenIdKey, _lastSeenId);
        }
      } else {
        final errLower = (result.error ?? result.message).toLowerCase();
        if (result.isUnauthorized ||
            errLower.contains('expired') ||
            errLower.contains('token is invalid')) {
          sessionExpiredNotifier.value = true;
        }
        debugPrint(
          '[NotificationPollingService] Poll non-200 (status=${result.statusCode}): ${result.message}',
        );
      }
    } catch (e) {
      debugPrint('[NotificationPollingService] Error polling notifications: $e');
    } finally {
      _isPolling = false;
      _pollStartedAt = null;
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    if (kIsWeb) return;

    final type = (notif['type'] ?? 'notification').toString();
    final actorId = notif['actor_id']?.toString();
    final actorUsername = notif['actor_username']?.toString();
    final currentUserId = AuthService().userId;
    if (!_systemNotificationTypes.contains(type) &&
        AuthService().isUserBlockedSync(actorUsername)) {
      return;
    }
    if (!_systemNotificationTypes.contains(type) &&
        actorId != null &&
        currentUserId.isNotEmpty &&
        actorId == currentUserId) {
      // Skip local banner if social action was performed by current user
      return;
    }

    final rawActorName = (notif['actor_name'] ?? '').toString().trim();
    final rawActorUser = (notif['actor_username'] ?? '').toString().trim();
    final actorName = rawActorName.isNotEmpty
        ? rawActorName
        : (rawActorUser.isNotEmpty ? rawActorUser : 'Someone');

    String title = 'Hidely';
    String body = (notif['body'] ?? notif['text'] ?? '$actorName interacted with your profile.')
        .toString();

    if (type == 'like' || type == 'new_like') {
      title = 'New Like ❤️';
      body = '$actorName liked your post.';
    } else if (type == 'comment' || type == 'new_comment') {
      title = 'New Comment 💬';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName commented on your post.';
    } else if (type == 'comment_like') {
      title = 'New Comment Like ❤️';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName liked your comment.';
    } else if (type == 'follow' || type == 'new_follower') {
      title = 'New Follower 👤';
      body = '$actorName started following you.';
    } else if (type == 'message' || type == 'new_message') {
      title = 'New Message 📩';
      final msgText = (notif['text'] ?? '').toString().trim();
      body = msgText.isNotEmpty ? '$actorName: $msgText' : '$actorName sent you a message.';
    } else if (type == 'new_post') {
      title = 'New Post 📸';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName posted a new travel post.';
    } else if (type == 'tag') {
      title = 'Tagged You 🏷️';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName tagged you in a post.';
    } else if (type == 'tag_request') {
      title = 'Tag Approval Needed 🏷️';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName tagged you in a post. Tap to review.';
    } else if (type == 'mention') {
      title = 'New @Mention 💬';
      body = (notif['text']?.toString().trim().isNotEmpty ?? false)
          ? notif['text'].toString()
          : '$actorName mentioned you.';
    } else if (type == 'official_hidely_post') {
      title = 'Official Hidely Spot 🌟';
      body = (notif['body'] ?? notif['text'] ?? 'Discover our newly featured secret location in India!')
          .toString();
    } else if (type == 'weekly_travel_suggestions') {
      title = 'Weekly Travel Suggestions 🏕️';
      body = (notif['body'] ?? notif['text'] ?? 'Explore 3 top hidden weekend getaways handpicked for you!')
          .toString();
    } else if (type == 'points_earned') {
      title = 'Points Earned ⭐';
    } else if (type == 'level_up') {
      title = 'Level Up! 🏆';
    } else if (type == 'badge_earned') {
      title = 'New Badge Earned 💎';
    } else if (type == 'place_discovered') {
      title = 'Discovery Verified 📍';
    } else if (type == 'system_announcement') {
      title = 'Hidely Update 📢';
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'hidely_notifications',
      'Hidely Notifications',
      channelDescription:
          'Notifications for likes, comments, followers, messages, official posts, and travel digests',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher_new',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final rawId = parseNotificationId(notif);
    final int safeNotifId = rawId > 0 ? (rawId % 2147483647) : DateTime.now().millisecondsSinceEpoch % 2147483647;

    try {
      await _localNotifications.show(
        safeNotifId,
        title,
        body,
        platformChannelSpecifics,
        payload: jsonEncode(notif),
      );
    } catch (e) {
      debugPrint('[NotificationPollingService] Failed showing local notification: $e');
    }
  }

  void _handleNotificationClick(String payload) async {
    try {
      final notif = jsonDecode(payload);
      final type = (notif['type'] ?? 'notification').toString();
      final actorUsername = (notif['actor_username'] ?? notif['actor_name'] ?? '').toString();
      final postIdStr = (notif['post_id'] ?? notif['target_id'])?.toString();
      final int? postIdInt = postIdStr != null ? int.tryParse(postIdStr) : null;

      final context = navigatorKey.currentContext;
      if (context == null) return;

      if (type == 'tag_request') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TagsAndMentionsScreen()),
        );
        return;
      }

      if ((type == 'like' ||
              type == 'new_like' ||
              type == 'comment' ||
              type == 'new_comment' ||
              type == 'comment_like' ||
              type == 'new_post' ||
              type == 'tag' ||
              type == 'mention' ||
              type == 'official_hidely_post') &&
          postIdInt != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xff2B1564)),
          ),
        );

        final token = AuthService().token ?? '';
        final result = await ApiService().getPostById(
          postId: postIdInt,
          token: token.isNotEmpty ? token : null,
        );

        if (context.mounted) Navigator.pop(context);

        if (result.success && result.data != null) {
          final post = result.data?['post'] ?? result.data;
          if (context.mounted && post != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SinglePostViewScreen(
                  posts: [post],
                  initialIndex: 0,
                ),
              ),
            );
            return;
          }
        }
      } else if ((type == 'follow' || type == 'new_follower') &&
          actorUsername.isNotEmpty &&
          actorUsername != 'user') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorProfileScreen(
              username: actorUsername,
              avatarPath: notif['actor_profile_picture'] ?? notif['profile_picture'] ?? '',
              rank: notif['actor_rank'] ?? notif['rank'] ?? 'Explorer',
            ),
          ),
        );
        return;
      } else if (type == 'message' || type == 'new_message') {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        MainWrapperState.activeState?.setIndex(2);
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        );
      }
    } catch (e) {
      debugPrint('[NotificationPollingService] Click navigation failed: $e');
    }
  }
}
