import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hidely_new/main.dart';
import 'package:hidely_new/screens/incoming_call_screen.dart';
import 'package:hidely_new/screens/webrtc_call_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';

enum _CallOverlayPhase { none, incoming, active }

class _CallSessionState {
  final _CallOverlayPhase phase;
  final String callId;
  final String callType; // 'audio' or 'video'
  final String peerUserId;
  final String peerName;
  final String peerUsername;
  final String peerAvatar;
  final int? conversationId;
  final bool isOutgoing;
  final bool isPipMode;
  final bool loggedOutcome;

  const _CallSessionState({
    required this.phase,
    required this.callId,
    required this.callType,
    required this.peerUserId,
    required this.peerName,
    this.peerUsername = '',
    this.peerAvatar = '',
    this.conversationId,
    required this.isOutgoing,
    this.isPipMode = false,
    this.loggedOutcome = false,
  });

  static const empty = _CallSessionState(
    phase: _CallOverlayPhase.none,
    callId: '',
    callType: 'audio',
    peerUserId: '',
    peerName: '',
    isOutgoing: false,
  );

  _CallSessionState copyWith({
    _CallOverlayPhase? phase,
    bool? isPipMode,
    bool? loggedOutcome,
  }) {
    return _CallSessionState(
      phase: phase ?? this.phase,
      callId: callId,
      callType: callType,
      peerUserId: peerUserId,
      peerName: peerName,
      peerUsername: peerUsername,
      peerAvatar: peerAvatar,
      conversationId: conversationId,
      isOutgoing: isOutgoing,
      isPipMode: isPipMode ?? this.isPipMode,
      loggedOutcome: loggedOutcome ?? this.loggedOutcome,
    );
  }
}

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final ValueNotifier<_CallSessionState> _stateNotifier =
      ValueNotifier<_CallSessionState>(_CallSessionState.empty);

  StreamSubscription<Map<String, dynamic>>? _signalSub;
  bool _initialized = false;
  bool _overlayMounted = false;
  Offset _pipOffset = const Offset(16, 100);

  bool get hasActiveCall => _stateNotifier.value.phase != _CallOverlayPhase.none;

  void ensureInitialized() {
    _connectSocketIfLoggedIn();
    if (_initialized) return;
    _initialized = true;

    AuthService().sessionEpochNotifier.addListener(_onSessionChanged);
    _signalSub?.cancel();
    _signalSub = ChatSocketService().onCallSignal.listen(_handleGlobalSignal);
  }

  void _onSessionChanged() {
    if (AuthService().isLoggedIn && !AuthService().isGuest) {
      _connectSocketIfLoggedIn();
    } else {
      ChatSocketService().disconnect();
      NotificationPollingService().cancelIncomingCallNotification();
      _stateNotifier.value = _CallSessionState.empty;
    }
  }

  void _connectSocketIfLoggedIn() {
    final token = AuthService().token;
    if (AuthService().isLoggedIn &&
        !AuthService().isGuest &&
        token != null &&
        token.isNotEmpty) {
      ChatSocketService().connect(token);
    }
  }

  void _handleGlobalSignal(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final callId = event['callId']?.toString() ?? '';
    if (callId.isEmpty) return;

    final current = _stateNotifier.value;
    final myUserId = AuthService().userId.trim();

    if (type == 'call_invite') {
      final senderId = event['senderId']?.toString() ?? '';
      final callerUsername = (event['callerUsername'] ?? '').toString();
      final callerName = (event['callerName'] ?? callerUsername).toString();
      if (senderId.isNotEmpty && senderId == myUserId) return;

      if (AuthService().isUserBlockedSync(callerUsername) ||
          AuthService().isUserBlockedSync(callerName)) {
        ChatSocketService().sendCallSignal('call_decline', {
          'callId': callId,
          'targetId': senderId,
        });
        return;
      }

      if (current.phase != _CallOverlayPhase.none) {
        if (current.callId == callId) return;
        ChatSocketService().sendCallSignal('call_busy', {
          'callId': callId,
          'targetId': senderId,
        });
        return;
      }

      final callType = event['callType']?.toString() == 'video' ? 'video' : 'audio';
      final convId = event['conversationId'] is int
          ? event['conversationId'] as int
          : int.tryParse('${event['conversationId'] ?? ''}');
      final callerAvatar = (event['callerAvatar'] ?? '').toString();

      ChatSocketService().sendCallSignal('call_ringing', {
        'callId': callId,
        'targetId': senderId,
      });

      NotificationPollingService().showIncomingCallNotification(
        callerName: callerName.isNotEmpty ? callerName : 'Hidely User',
        callType: callType,
      );

      final incomingSession = _CallSessionState(
        phase: _CallOverlayPhase.incoming,
        callId: callId,
        callType: callType,
        peerUserId: senderId,
        peerName: callerName.isNotEmpty ? callerName : 'Hidely User',
        peerUsername: callerUsername,
        peerAvatar: callerAvatar,
        conversationId: convId,
        isOutgoing: false,
      );

      if (_overlayMounted) {
        _stateNotifier.value = incomingSession;
      } else {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          _stateNotifier.value = incomingSession;
          nav.push(
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callId: callId,
                callerId: senderId,
                callerName: incomingSession.peerName,
                callerUsername: callerUsername,
                callerAvatar: callerAvatar,
                callType: callType,
                onAccept: () {
                  nav.pop();
                  _acceptIncomingCall(incomingSession);
                },
                onDecline: () {
                  nav.pop();
                  _clearCallSession();
                },
              ),
            ),
          );
        }
      }
      return;
    }

    if (type == 'call_ended' || type == 'call_hangup') {
      if (current.phase == _CallOverlayPhase.incoming &&
          current.callId == callId) {
        NotificationPollingService().cancelIncomingCallNotification();
        _clearCallSession();
        if (!_overlayMounted) {
          navigatorKey.currentState?.maybePop();
        }
      }
      return;
    }

    if (type == 'call_failed' || type == 'call_busy') {
      if (current.callId == callId) {
        final msg = type == 'call_busy'
            ? '${current.peerName} is on another call.'
            : (event['message']?.toString() ?? '${current.peerName} is unavailable.');
        _showGlobalToast(msg, isError: true);
      }
    }
  }

  Future<void> startCall({
    required BuildContext context,
    required String targetUserId,
    required String peerName,
    String peerUsername = '',
    String peerAvatar = '',
    int? conversationId,
    required String callType,
  }) async {
    ensureInitialized();

    if (hasActiveCall) {
      _showGlobalToast('You already have an active call.', isError: true);
      return;
    }

    if (targetUserId.trim().isEmpty) {
      _showGlobalToast('Unable to start call: recipient unavailable.', isError: true);
      return;
    }

    if (AuthService().isUserBlockedSync(peerUsername) ||
        AuthService().isUserBlockedSync(peerName)) {
      _showGlobalToast('Unblock this user before calling.', isError: true);
      return;
    }

    if (!kIsWeb) {
      try {
        var micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          micStatus = await Permission.microphone.request();
        }
        if (!micStatus.isGranted) {
          _showGlobalToast('Microphone permission is required for calling.', isError: true);
          return;
        }
        if (callType == 'video') {
          var camStatus = await Permission.camera.status;
          if (!camStatus.isGranted) {
            camStatus = await Permission.camera.request();
          }
          if (!camStatus.isGranted) {
            _showGlobalToast('Camera permission is required for video calls.', isError: true);
            return;
          }
        }
      } catch (_) {}
    }

    final myId = AuthService().userId.trim();
    final callId = 'call_${conversationId ?? 0}_${DateTime.now().millisecondsSinceEpoch}_$myId';

    final session = _CallSessionState(
      phase: _CallOverlayPhase.active,
      callId: callId,
      callType: callType == 'video' ? 'video' : 'audio',
      peerUserId: targetUserId.trim(),
      peerName: peerName.trim().isNotEmpty ? peerName.trim() : 'Hidely User',
      peerUsername: peerUsername,
      peerAvatar: peerAvatar,
      conversationId: conversationId,
      isOutgoing: true,
    );

    ChatSocketService().sendCallSignal('call_invite', {
      'callId': callId,
      'callType': session.callType,
      'targetUserId': session.peerUserId,
      'conversationId': conversationId,
      'callerName': AuthService().userName.isNotEmpty
          ? AuthService().userName
          : AuthService().userUsername,
      'callerUsername': AuthService().userUsername,
      'callerAvatar': AuthService().userProfilePicture,
    });

    if (_overlayMounted) {
      _stateNotifier.value = session;
    } else if (context.mounted) {
      _stateNotifier.value = session;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (routeCtx) => WebRtcCallScreen(
            callId: session.callId,
            callType: session.callType,
            targetUserId: session.peerUserId,
            peerName: session.peerName,
            peerUsername: session.peerUsername,
            peerAvatar: session.peerAvatar,
            conversationId: session.conversationId,
            isOutgoing: true,
            onCallEnded: (cType, secs, reason) =>
                _recordOutgoingCallLog(session, cType, secs, reason),
            onClose: () {
              _clearCallSession();
              if (routeCtx.mounted && Navigator.canPop(routeCtx)) {
                Navigator.pop(routeCtx);
              }
            },
          ),
        ),
      );
    }
  }

  void _acceptIncomingCall(_CallSessionState incoming) {
    final active = incoming.copyWith(phase: _CallOverlayPhase.active, isPipMode: false);
    if (_overlayMounted) {
      _stateNotifier.value = active;
    } else {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        _stateNotifier.value = active;
        nav.push(
          MaterialPageRoute(
            builder: (routeCtx) => WebRtcCallScreen(
              callId: active.callId,
              callType: active.callType,
              targetUserId: active.peerUserId,
              peerName: active.peerName,
              peerUsername: active.peerUsername,
              peerAvatar: active.peerAvatar,
              conversationId: active.conversationId,
              isOutgoing: false,
              onClose: () {
                _clearCallSession();
                if (routeCtx.mounted && Navigator.canPop(routeCtx)) {
                  Navigator.pop(routeCtx);
                }
              },
            ),
          ),
        );
      }
    }
  }

  void _clearCallSession() {
    NotificationPollingService().cancelIncomingCallNotification();
    _stateNotifier.value = _CallSessionState.empty;
  }

  Future<void> _recordOutgoingCallLog(
    _CallSessionState session,
    String callType,
    int durationSeconds,
    String reason,
  ) async {
    if (!session.isOutgoing || session.conversationId == null) return;
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    final isVideo = callType == 'video';
    final prefix = isVideo ? '📹' : '📞';
    final label = isVideo ? 'Video call' : 'Voice call';

    String text;
    if (durationSeconds > 0) {
      final mins = (durationSeconds ~/ 60).toString().padLeft(2, '0');
      final secs = (durationSeconds % 60).toString().padLeft(2, '0');
      text = '$prefix $label • $mins:$secs';
    } else if (reason == 'declined') {
      text = '$prefix Declined ${label.toLowerCase()}';
    } else if (reason == 'busy') {
      text = '$prefix Busy • ${label.toLowerCase()}';
    } else {
      text = '$prefix Missed ${label.toLowerCase()}';
    }

    await ApiService().sendChatMessage(
      token: token,
      conversationId: session.conversationId!,
      type: 'call_log',
      text: text,
    );
  }

  void _showGlobalToast(String msg, {bool isError = false}) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF1C0D5A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Wrap the MaterialApp root in [HidelyApp.builder] so incoming calls and
  /// floating PiP calls work cleanly over every screen without breaking routes.
  Widget wrapWithCallOverlay(BuildContext context, Widget child) {
    _overlayMounted = true;
    return ValueListenableBuilder<_CallSessionState>(
      valueListenable: _stateNotifier,
      builder: (ctx, session, _) {
        if (session.phase == _CallOverlayPhase.none) {
          return child;
        }

        if (session.phase == _CallOverlayPhase.incoming) {
          return Stack(
            children: [
              child,
              Positioned.fill(
                child: IncomingCallScreen(
                  key: ValueKey('incoming_${session.callId}'),
                  callId: session.callId,
                  callerId: session.peerUserId,
                  callerName: session.peerName,
                  callerUsername: session.peerUsername,
                  callerAvatar: session.peerAvatar,
                  callType: session.callType,
                  onAccept: () => _acceptIncomingCall(session),
                  onDecline: _clearCallSession,
                ),
              ),
            ],
          );
        }

        final callWidget = WebRtcCallScreen(
          key: ValueKey('active_${session.callId}'),
          callId: session.callId,
          callType: session.callType,
          targetUserId: session.peerUserId,
          peerName: session.peerName,
          peerUsername: session.peerUsername,
          peerAvatar: session.peerAvatar,
          conversationId: session.conversationId,
          isOutgoing: session.isOutgoing,
          isPipMode: session.isPipMode,
          onMinimize: () {
            _stateNotifier.value = session.copyWith(isPipMode: true);
          },
          onCallEnded: (cType, secs, reason) {
            if (session.isOutgoing) {
              _recordOutgoingCallLog(session, cType, secs, reason);
            }
          },
          onClose: _clearCallSession,
        );

        if (!session.isPipMode) {
          return Stack(
            children: [
              child,
              Positioned.fill(child: callWidget),
            ],
          );
        }

        final size = MediaQuery.of(ctx).size;
        return Stack(
          children: [
            child,
            Positioned(
              right: _pipOffset.dx,
              top: _pipOffset.dy,
              width: session.callType == 'video' ? 116 : 124,
              height: session.callType == 'video' ? 168 : 112,
              child: GestureDetector(
                onTap: () {
                  _stateNotifier.value = session.copyWith(isPipMode: false);
                },
                onPanUpdate: (details) {
                  _pipOffset = Offset(
                    (_pipOffset.dx - details.delta.dx).clamp(8.0, size.width - 130.0),
                    (_pipOffset.dy + details.delta.dy).clamp(40.0, size.height - 200.0),
                  );
                  _stateNotifier.value = session.copyWith(isPipMode: true);
                },
                child: callWidget,
              ),
            ),
          ],
        );
      },
    );
  }
}
