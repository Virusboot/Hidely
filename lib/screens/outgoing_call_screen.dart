import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hidely_new/screens/video_call_screen.dart';
import 'package:hidely_new/screens/voice_call_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String callID;
  final bool isVideo;

  const OutgoingCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callID,
    this.isVideo = true,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _pulseController;
  bool _isMuted = false;
  bool _isSpeaker = true;
  final String _callStatus = "Ringing...";

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _acceptCall() async {
    if (!mounted) return;

    // Proactively request camera & microphone permissions
    try {
      await [
        Permission.camera,
        Permission.microphone,
      ].request();
    } catch (e) {
      debugPrint("Permission error: $e");
    }

    if (!mounted) return;

    if (widget.isVideo) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => VideoCallScreen(
            callerName: widget.callerName,
            callerAvatar: widget.callerAvatar,
            callID: widget.callID,
          ),
          transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(
            opacity: anim1,
            child: child,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => VoiceCallScreen(
            callerName: widget.callerName,
            callerAvatar: widget.callerAvatar,
            callID: widget.callID,
          ),
          transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(
            opacity: anim1,
            child: child,
          ),
        ),
      );
    }
  }

  void _cancelCall() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Call ended with ${widget.callerName}"),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAvatar(double size) {
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
          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : "C",
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
    return Scaffold(
      backgroundColor: const Color(0xff080C14),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff0D1322),
                  Color(0xff18102C),
                  Color(0xff0A0E17),
                ],
              ),
            ),
          ),

          // Glowing background atmosphere
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.5 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: widget.isVideo 
                        ? const Color(0xff3B82F6).withOpacity(0.25) 
                        : const Color(0xff8B5CF6).withOpacity(0.25),
                    blurRadius: 110,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Top Bar with Security Lock
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _cancelCall,
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 26),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                              size: 14,
                              color: const Color(0xff38BDF8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isVideo ? "HD Video Call" : "Voice Call",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                const Spacer(),

                // Pulsing Avatar with Ringing Waves
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final progress = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140 + (progress * 70),
                          height: 140 + (progress * 70),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (widget.isVideo ? const Color(0xff3B82F6) : const Color(0xff8B5CF6))
                                  .withOpacity((1 - progress) * 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 140 + (progress * 35),
                          height: 140 + (progress * 35),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (widget.isVideo ? const Color(0xff60A5FA) : const Color(0xffA78BFA))
                                  .withOpacity((1 - progress) * 0.7),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.isVideo 
                            ? [const Color(0xff3B82F6), const Color(0xff60A5FA), const Color(0xff93C5FD)]
                            : [const Color(0xff8B5CF6), const Color(0xffA78BFA), const Color(0xffC084FC)],
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
                        child: _buildAvatar(130),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Recipient Name
                Text(
                  widget.callerName.isNotEmpty ? widget.callerName : "User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 10),

                // Ringing Status
                AnimatedBuilder(
                  animation: _ringController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ring_volume_rounded,
                          size: 18,
                          color: const Color(0xff38BDF8).withOpacity(0.5 + (_ringController.value * 0.5)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Calling ${widget.callerName}... ($_callStatus)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),

                // Bottom Call Controls: Mute, Decline (Red), Pick Up / Answer (Green)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute Toggle Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isMuted = !_isMuted;
                                  });
                                },
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isMuted ? Colors.white : Colors.white.withOpacity(0.12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                    color: _isMuted ? Colors.black87 : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isMuted ? "Muted" : "Mute",
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),

                          // Red Decline / Cancel Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _cancelCall,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xffEF4444), Color(0xffDC2626)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xffEF4444).withOpacity(0.4),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.call_end_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),

                          // Green Accept / Pick Up Call Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _acceptCall,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xff10B981), Color(0xff059669)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xff10B981).withOpacity(0.45),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Pick Up",
                                style: TextStyle(color: Color(0xff34D399), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          // Speaker Toggle Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSpeaker = !_isSpeaker;
                                  });
                                },
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isSpeaker ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    _isSpeaker ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isSpeaker ? "Speaker" : "Earpiece",
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
