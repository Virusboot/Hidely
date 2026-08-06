import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:hidely_new/config/call_config.dart';
import 'package:hidely_new/services/auth_service.dart';

class VideoCallScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final String localUserId = AuthService().userId.isNotEmpty 
        ? AuthService().userId 
        : "user_${DateTime.now().millisecondsSinceEpoch}";
    final String localUserName = AuthService().userName.isNotEmpty 
        ? AuthService().userName 
        : "Guest User";

    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: CallConfig.appId,
        appSign: CallConfig.appSign,
        userID: localUserId,
        userName: localUserName,
        callID: callID,
        config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          ..onOnlySelfInRoom = (context) {
            Navigator.of(context).pop();
          },
      ),
    );
  }
}
