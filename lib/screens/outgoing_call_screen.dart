import 'package:flutter/material.dart';
import 'package:hidely_new/screens/webrtc_call_screen.dart';

class OutgoingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerAvatar;
  final String callID;
  final bool isVideo;
  final String targetUserId;
  final int? conversationId;

  const OutgoingCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callID,
    this.isVideo = true,
    this.targetUserId = '',
    this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return WebRtcCallScreen(
      callId: callID,
      callType: isVideo ? 'video' : 'audio',
      targetUserId: targetUserId,
      peerName: callerName,
      peerAvatar: callerAvatar,
      conversationId: conversationId,
      isOutgoing: true,
      onClose: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
