import 'package:flutter/material.dart';
import 'dart:async';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:hidely_new/config/call_config.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String callID;

  const VideoCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callID,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? _callTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startTimer();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.camera,
        Permission.microphone,
      ].request();
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });

        // 45-Second Video Call Timeout if unanswered
        if (_secondsElapsed >= 45) {
          _callTimer?.cancel();
          if (mounted && Navigator.canPop(context)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("User unavailable. Video call timed out."),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  Widget _buildCallerAvatar(double size) {
    final avatarUrl = widget.callerAvatar;
    final isNetwork = avatarUrl.startsWith("http") || avatarUrl.startsWith("uploads");

    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xff1E293B),
          child: const Icon(Icons.person, color: Colors.white54, size: 36),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xff1E293B),
          child: const Icon(Icons.person, color: Colors.white54, size: 36),
        ),
      );
    } else if (avatarUrl.isNotEmpty && !avatarUrl.contains("default")) {
      return Image.asset(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xff1E293B),
          child: const Icon(Icons.person, color: Colors.white54, size: 36),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      color: const Color(0xff334155),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : "V",
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String localUserId = AuthService().userId.isNotEmpty 
        ? AuthService().userId 
        : "user_${DateTime.now().millisecondsSinceEpoch}";
    final String localUserName = AuthService().userName.isNotEmpty 
        ? AuthService().userName 
        : "Guest User";

    final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
      ..turnOnCameraWhenJoining = true
      ..turnOnMicrophoneWhenJoining = true
      ..useSpeakerWhenJoining = true
      ..layout = ZegoLayout.pictureInPicture(
        isSmallViewDraggable: true,
        switchLargeOrSmallViewByClick: true,
      )
      ..audioVideoViewConfig = ZegoPrebuiltAudioVideoViewConfig(
        useVideoViewAspectFill: true,
        showAvatarInAudioMode: true,
        showSoundWavesInAudioMode: true,
      )
      ..topMenuBarConfig = ZegoTopMenuBarConfig(
        isVisible: false,
      )
      ..bottomMenuBarConfig = ZegoBottomMenuBarConfig(
        buttons: [
          ZegoMenuBarButtonName.toggleCameraButton,
          ZegoMenuBarButtonName.toggleMicrophoneButton,
          ZegoMenuBarButtonName.hangUpButton,
          ZegoMenuBarButtonName.switchCameraButton,
          ZegoMenuBarButtonName.switchAudioOutputButton,
        ],
        style: ZegoMenuBarStyle.light,
      )
      ..onOnlySelfInRoom = (context) {
        Navigator.of(context).pop();
      }
      ..avatarBuilder = (BuildContext context, Size size, ZegoUIKitUser? user, Map<String, dynamic> extraInfo) {
        return Container(
          width: size.width,
          height: size.height,
          color: const Color(0xff0F172A),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xff8B5CF6), Color(0xff3B82F6)],
                ),
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xff1E293B),
                ),
                child: ClipOval(
                  child: _buildCallerAvatar(90),
                ),
              ),
            ),
          ),
        );
      }
      ..foreground = SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Glass Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.callerName.isNotEmpty ? widget.callerName : "Video Call",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xff10B981),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(_secondsElapsed),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "• HD Video",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 13, color: Color(0xff34D399)),
                          const SizedBox(width: 4),
                          Text(
                            "Encrypted",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.87),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
      ..background = Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff090D16),
              Color(0xff0F172A),
            ],
          ),
        ),
      );

    return Scaffold(
      backgroundColor: const Color(0xff090D16),
      body: SafeArea(
        child: ZegoUIKitPrebuiltCall(
          appID: CallConfig.appId,
          appSign: CallConfig.appSign,
          userID: localUserId,
          userName: localUserName,
          callID: widget.callID,
          config: config,
        ),
      ),
    );
  }
}
