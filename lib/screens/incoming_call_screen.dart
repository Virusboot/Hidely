import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerUsername;
  final String callerAvatar;
  final String callType; // 'audio' or 'video'
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerUsername,
    required this.callerAvatar,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _ringTimer;
  Timer? _autoTimeoutTimer;
  bool _handledAction = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _startRingingFeedback();

    // Auto-dismiss if caller didn't cancel after 40s
    _autoTimeoutTimer = Timer(const Duration(seconds: 40), () {
      if (mounted && !_handledAction) {
        _handleDecline();
      }
    });
  }

  void _startRingingFeedback() {
    _stopRingingFeedback();
    HapticFeedback.heavyImpact();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
    });
  }

  void _stopRingingFeedback() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  Future<void> _handleAccept() async {
    if (_handledAction) return;
    _handledAction = true;
    _stopRingingFeedback();
    _autoTimeoutTimer?.cancel();
    NotificationPollingService().cancelIncomingCallNotification();

    bool micOk = true;
    bool camOk = true;
    if (!kIsWeb) {
      try {
        var micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          micStatus = await Permission.microphone.request();
        }
        micOk = micStatus.isGranted;

        if (widget.callType == 'video') {
          var camStatus = await Permission.camera.status;
          if (!camStatus.isGranted) {
            camStatus = await Permission.camera.request();
          }
          camOk = camStatus.isGranted;
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (!micOk || !camOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.callType == 'video'
                ? 'Microphone and Camera permissions are required for video calls.'
                : 'Microphone permission is required for voice calls.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ChatSocketService().sendCallSignal('call_decline', {
        'callId': widget.callId,
        'targetId': widget.callerId,
      });
      widget.onDecline();
      return;
    }

    widget.onAccept();
  }

  void _handleDecline() {
    if (_handledAction) return;
    _handledAction = true;
    _stopRingingFeedback();
    _autoTimeoutTimer?.cancel();
    NotificationPollingService().cancelIncomingCallNotification();
    ChatSocketService().sendCallSignal('call_decline', {
      'callId': widget.callId,
      'targetId': widget.callerId,
    });
    widget.onDecline();
  }

  @override
  void dispose() {
    _stopRingingFeedback();
    _autoTimeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.callerName.trim().isNotEmpty
        ? widget.callerName.trim()
        : (widget.callerUsername.isNotEmpty ? widget.callerUsername : 'Hidely User');
    final handle = widget.callerUsername.trim().isNotEmpty
        ? (widget.callerUsername.startsWith('@')
            ? widget.callerUsername
            : '@${widget.callerUsername}')
        : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleDecline();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF140B2E),
                Color(0xFF0F172A),
                Color(0xFF090D16),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.callType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: const Color(0xFFA855F7),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.callType == 'video'
                            ? 'HIDELY VIDEO CALL'
                            : 'HIDELY AUDIO CALL',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 1.0 + (_pulseController.value * 0.35);
                    final opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale * 1.18,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: opacity * 0.22),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: opacity * 0.38),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: UserAvatar(
                            avatarUrl: widget.callerAvatar,
                            displayName: displayName,
                            radius: 62,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    handle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  widget.callType == 'video'
                      ? 'wants to video chat with you...'
                      : 'is calling you...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 44),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _handleDecline,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF4444),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 22,
                                    spreadRadius: 2,
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
                          const SizedBox(height: 12),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _handleAccept,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF22C55E),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 22,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.callType == 'video'
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

