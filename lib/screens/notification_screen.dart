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

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (AuthService().isGuest) {
      setState(() => _isLoading = false);
      return;
    }
    final token = AuthService().token ?? '';
    final result = await ApiService().getNotifications(token: token);
    if (mounted) {
      setState(() {
        _notifications = result.data?['notifications'] ?? [];
        _isLoading = false;
      });
      if (token.isNotEmpty && _notifications.isNotEmpty) {
        await ApiService().markNotificationsAsRead(token: token);
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "now";
      if (diff.inHours < 1) return "${diff.inMinutes}m";
      if (diff.inDays < 1) return "${diff.inHours}h";
      return "${diff.inDays}d";
    } catch (_) {
      return "";
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xffE0F2FE),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
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
                      const SizedBox(width: 16),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
                      : _notifications.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 48, color: Colors.black38),
                                  SizedBox(height: 12),
                                  Text(
                                    "No new notifications",
                                    style: TextStyle(color: Colors.black38, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                return _buildNotificationItem(_notifications[index]);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notification) {
    final type = notification["type"];
    final actorName = notification["actor_name"] ?? notification["actor_username"] ?? "User";
    final actorPic = notification["actor_profile_picture"];
    final text = notification["text"] ?? "";
    final timeAgo = notification["created_at"] != null ? _formatTime(notification["created_at"].toString()) : "";
    final postImg = notification["post_image_url"];
    final postId = notification["post_id"];
    final actorUsername = notification["actor_username"];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: GestureDetector(
        onTap: () async {
          if (type == 'follow') {
            if (actorUsername != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatorProfileScreen(
                    username: actorUsername,
                    avatarPath: "assets/images/nomad_nate_avatar.png",
                    rank: "Silver",
                  ),
                ),
              ).then((_) => _loadNotifications());
            }
          } else if (postId != null) {
            // Load full post details and navigate
            final token = AuthService().token;
            final postResult = await ApiService().getPostById(postId: postId, token: token);
            if (postResult.success && mounted) {
              final post = postResult.data?['post'];
              if (post != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SinglePostViewScreen(post: post),
                  ),
                ).then((_) => _loadNotifications());
              }
            }
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xffCBD5E1),
              backgroundImage: actorPic != null && actorPic.toString().isNotEmpty
                  ? NetworkImage('${ApiService().baseUrl}/$actorPic') as ImageProvider
                  : const AssetImage("assets/images/nomad_nate_avatar.png"),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "$actorName ",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14.5),
                    ),
                    TextSpan(
                      text: text.startsWith(actorName) 
                          ? text.replaceFirst(actorName, '').trim() 
                          : text,
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 14.5),
                    ),
                    TextSpan(
                      text: "  $timeAgo",
                      style: const TextStyle(color: Colors.black38, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (postImg != null && postImg.toString().isNotEmpty)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage('${ApiService().baseUrl}/$postImg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}