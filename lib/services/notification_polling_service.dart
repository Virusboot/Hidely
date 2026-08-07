import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/main.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';

class NotificationPollingService {
  static final NotificationPollingService _instance = NotificationPollingService._internal();
  factory NotificationPollingService() => _instance;
  NotificationPollingService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  bool _isInitialized = false;
  String get _lastSeenIdKey => 'last_seen_notification_id_${AuthService().userId}';
  int _lastSeenId = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          _handleNotificationClick(details.payload!);
        }
      },
    );

    // Load last seen notification ID
    final prefs = await SharedPreferences.getInstance();
    _lastSeenId = prefs.getInt(_lastSeenIdKey) ?? 0;

    // Request permissions for iOS and Android 13+
    _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _isInitialized = true;
    debugPrint('[NotificationPollingService] Initialized. Last seen ID: $_lastSeenId');
  }

  void startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    debugPrint('[NotificationPollingService] Started polling every 15 seconds.');

    // Force reload active user's last seen notification ID to prevent cross-session state leaks
    SharedPreferences.getInstance().then((prefs) {
      _lastSeenId = prefs.getInt(_lastSeenIdKey) ?? 0;
      debugPrint('[NotificationPollingService] Loaded last seen ID: $_lastSeenId for user: ${AuthService().userId}');
      
      _pollNotifications();
      _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _pollNotifications();
      });
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[NotificationPollingService] Stopped polling.');
  }

  Future<void> _pollNotifications() async {
    if (AuthService().isGuest) return; // Don't poll for guests

    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    try {
      final result = await ApiService().getNotifications(token: token);
      if (result.success) {
        final notificationsList = result.data?['notifications'] as List? ?? [];
        if (notificationsList.isEmpty) return;

        int maxIdFound = _lastSeenId;

        for (var i = notificationsList.length - 1; i >= 0; i--) {
          final notif = notificationsList[i];
          final int notifId = notif['id'] ?? (notif['_id'] is int ? notif['_id'] : int.tryParse(notif['_id']?.toString() ?? '0') ?? 0);
          final bool isRead = notif['is_read'] == 1 || notif['is_read'] == true || notif['is_read'] == 'true';

          // If the notification is newer than our last seen, and it is unread, show a banner.
          if (notifId > _lastSeenId && !isRead) {
            _showLocalNotification(notif);
            if (notifId > maxIdFound) {
              maxIdFound = notifId;
            }
          }
        }

        // Update last seen ID
        if (maxIdFound > _lastSeenId) {
          _lastSeenId = maxIdFound;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_lastSeenIdKey, _lastSeenId);
        }
      }
    } catch (e) {
      debugPrint('[NotificationPollingService] Error polling notifications: $e');
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    final type = notif['type'] ?? 'notification';
    final actorName = notif['actor_name'] ?? notif['actor_username'] ?? 'Someone';
    
    String title = 'Hidely';
    String body = notif['body'] ?? '$actorName interacted with your profile.';

    if (type == 'like' || type == 'new_like') {
      title = 'New Like ❤️';
      body = '$actorName liked your post.';
    } else if (type == 'comment' || type == 'new_comment') {
      title = 'New Comment 💬';
      body = '$actorName commented on your post.';
    } else if (type == 'follow' || type == 'new_follower') {
      title = 'New Follower 👤';
      body = '$actorName started following you.';
    } else if (type == 'message' || type == 'new_message') {
      title = 'New Message 📩';
      body = '$actorName sent you a message.';
    } else if (type == 'official_hidely_post') {
      title = 'Official Hidely Spot 🌟';
      body = notif['body'] ?? 'Discover our newly featured secret location in India!';
    } else if (type == 'weekly_travel_suggestions') {
      title = 'Weekly Travel Suggestions 🏕️';
      body = notif['body'] ?? 'Explore 3 top hidden weekend getaways handpicked for you!';
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'hidely_notifications', 
      'Hidely Notifications',
      channelDescription: 'Notifications for likes, comments, followers, messages, official posts, and travel digests',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    final notifId = notif['id'] ?? (notif['_id'] is int ? notif['_id'] : int.tryParse(notif['_id']?.toString() ?? '0') ?? 0);
    
    await _localNotifications.show(
      notifId,
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(notif),
    );
  }

  void _handleNotificationClick(String payload) async {
    try {
      final notif = jsonDecode(payload);
      final type = notif['type'] ?? 'notification';
      final actorUsername = notif['actor_username'] ?? notif['actor_name'] ?? '';
      
      final postId = notif['post_id']?.toString() ?? notif['target_id']?.toString();

      final context = navigatorKey.currentContext;
      if (context == null) return;

      if ((type == 'like' || type == 'new_like' || type == 'comment' || type == 'new_comment') && postId != null && postId.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xff2B1564)),
          ),
        );

        final token = AuthService().token ?? '';
        final result = await ApiService().getPostById(postId: int.parse(postId), token: token.isNotEmpty ? token : null);
        
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
          }
        }
      } else if ((type == 'follow' || type == 'new_follower') && actorUsername.isNotEmpty) {
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
      }
    } catch (e) {
      debugPrint('[NotificationPollingService] Click navigation failed: $e');
    }
  }
}
