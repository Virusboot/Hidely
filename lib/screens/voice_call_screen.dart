import 'package:flutter/material.dart';
import 'dart:async';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:hidely_new/config/call_config.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String callID;

  const VoiceCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callID,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _callTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startTimer();
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });

        // 45-Second Call Timeout if unanswered
        if (_secondsElapsed >= 45) {
          _callTimer?.cancel();
          if (mounted && Navigator.canPop(context)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("User unavailable. Call timed out."),
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
    _pulseController.dispose();
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
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xff1E293B),
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
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
          child: const Icon(Icons.person, color: Colors.white54, size: 40),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      color: const Color(0xff334155),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : "U",
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

    final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
      ..turnOnMicrophoneWhenJoining = true
      ..useSpeakerWhenJoining = false
      ..audioVideoViewConfig = ZegoPrebuiltAudioVideoViewConfig(
        showAvatarInAudioMode: true,
        showSoundWavesInAudioMode: true,
      )
      ..topMenuBarConfig = ZegoTopMenuBarConfig(
        isVisible: false,
      )
      ..bottomMenuBarConfig = ZegoBottomMenuBarConfig(
        buttons: [
          ZegoMenuBarButtonName.toggleMicrophoneButton,
          ZegoMenuBarButtonName.hangUpButton,
          ZegoMenuBarButtonName.switchAudioOutputButton,
        ],
        style: ZegoMenuBarStyle.light,
      )
      ..onOnlySelfInRoom = (context) {
        Navigator.of(context).pop();
      }
      ..avatarBuilder = (BuildContext context, Size size, ZegoUIKitUser? user, Map<String, dynamic> extraInfo) {
        return ClipOval(
          child: _buildCallerAvatar(size.width),
        );
      }
      ..background = Stack(
        children: [
          // Dark ambient gradient backdrop
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff090D16),
                  Color(0xff130F26),
                  Color(0xff0B1120),
                ],
              ),
            ),
          ),

          // Glowing background circles
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.5 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff7C3AED).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            right: MediaQuery.of(context).size.width * 0.5 - 120,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff2563EB).withOpacity(0.18),
                    blurRadius: 90,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 30),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: Color(0xff10B981)),
                            SizedBox(width: 6),
                            Text(
                              "End-to-End Encrypted",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const Spacer(),

                // Pulsing rings around avatar
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final progress = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring
                        Container(
                          width: 140 + (progress * 60),
                          height: 140 + (progress * 60),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xff8B5CF6).withOpacity((1 - progress) * 0.4),
                              width: 2,
                            ),
                          ),
                        ),
                        // Inner pulse ring
                        Container(
                          width: 140 + (progress * 30),
                          height: 140 + (progress * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xff3B82F6).withOpacity((1 - progress) * 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xff8B5CF6), Color(0xff3B82F6), Color(0xffEC4899)],
                      ),
                    ),
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xff0F172A),
                      ),
                      child: ClipOval(
                        child: _buildCallerAvatar(130),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Caller Name
                Text(
                  widget.callerName.isNotEmpty ? widget.callerName : "Unknown Caller",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Call Duration & Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xff1E293B).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xff10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_secondsElapsed),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sound Wave Spectrum Animation Graphic
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final val = (index % 2 == 0) 
                            ? _pulseController.value 
                            : (1 - _pulseController.value);
                        final height = 10.0 + (val * 24.0 * (1 + (index % 3) * 0.3));
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xff8B5CF6).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    );
                  }),
                ),

                const Spacer(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
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
