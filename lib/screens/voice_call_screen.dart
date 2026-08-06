import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class VoiceCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;

  const VoiceCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool isMuted = false;
  bool isSpeaker = false;
  bool isConnected = false;
  int durationInSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulate connecting
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isConnected = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              durationInSeconds++;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get formattedDuration {
    final minutes = (durationInSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (durationInSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1A1A24),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  "Voice Call",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 60),
            // Avatar
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.callerAvatar.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: widget.callerAvatar,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 60, color: Colors.grey),
                      )
                    : Image.asset(
                        widget.callerAvatar.isNotEmpty ? widget.callerAvatar : "assets/images/user1.jpg",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(Icons.person, size: 60, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // Caller Name
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            // Call Status / Duration
            Text(
              isConnected ? formattedDuration : "Ringing...",
              style: TextStyle(
                color: isConnected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            // Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xff2A2A35),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: 'Speaker',
                        isActive: isSpeaker,
                        onTap: () {
                          setState(() {
                            isSpeaker = !isSpeaker;
                          });
                          HapticFeedback.lightImpact();
                        },
                      ),
                      _buildControlButton(
                        icon: Icons.videocam_off_rounded,
                        label: 'Video',
                        isActive: false,
                        onTap: () {
                          HapticFeedback.lightImpact();
                        },
                      ),
                      _buildControlButton(
                        icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: 'Mute',
                        isActive: isMuted,
                        onTap: () {
                          setState(() {
                            isMuted = !isMuted;
                          });
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? const Color(0xff1A1A24) : Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        )
      ],
    );
  }
}
