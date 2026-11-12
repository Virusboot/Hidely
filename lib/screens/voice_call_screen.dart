import 'package:flutter/material.dart';
import 'package:hidely_new/screens/webrtc_call_screen.dart';

class VoiceCallScreen extends StatelessWidget {
  final String callerName;
  final String callerAvatar;
  final String callID;
  final String targetUserId;
  final int? conversationId;
  final bool isOutgoing;

  const VoiceCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callID,
    this.targetUserId = '',
    this.conversationId,
    this.isOutgoing = true,
  });

  @override
  Widget build(BuildContext context) {
    return WebRtcCallScreen(
      callId: callID,
      callType: 'audio',
      targetUserId: targetUserId,
      peerName: callerName,
      peerAvatar: callerAvatar,
      conversationId: conversationId,
      isOutgoing: isOutgoing,
      onClose: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
