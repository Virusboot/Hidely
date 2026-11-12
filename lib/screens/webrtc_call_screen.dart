import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hidely_new/config/call_config.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class WebRtcCallScreen extends StatefulWidget {
  final String callId;
  final String callType; // 'audio' or 'video'
  final String targetUserId;
  final String peerName;
  final String peerUsername;
  final String peerAvatar;
  final int? conversationId;
  final bool isOutgoing;
  final bool isPipMode;
  final VoidCallback? onMinimize;
  final void Function(String callType, int durationSeconds, String endReason)? onCallEnded;
  final VoidCallback onClose;

  const WebRtcCallScreen({
    super.key,
    required this.callId,
    required this.callType,
    required this.targetUserId,
    required this.peerName,
    this.peerUsername = '',
    this.peerAvatar = '',
    this.conversationId,
    required this.isOutgoing,
    this.isPipMode = false,
    this.onMinimize,
    this.onCallEnded,
    required this.onClose,
  });

  @override
  State<WebRtcCallScreen> createState() => _WebRtcCallScreenState();
}

class _WebRtcCallScreenState extends State<WebRtcCallScreen>
    with SingleTickerProviderStateMixin {
  bool _micEnabled = true;
  late bool _camEnabled;
  late bool _speakerEnabled;
  bool _remoteMicEnabled = true;
  bool _remoteCamEnabled = true;
  bool _isRemoteRinging = false;
  bool _isConnected = false;
  bool _hasEnded = false;

  int _secondsElapsed = 0;
  Timer? _timer;
  Timer? _ringingTimeoutTimer;
  Timer? _connectionWatchdog;
  late AnimationController _pulseController;

  // Draggable local PiP position (Instagram style)
  double _localPipRight = 16;
  double _localPipBottom = 128;

  // WebRTC state
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  StreamSubscription<Map<String, dynamic>>? _signalSub;

  String? _remoteParticipantId;
  bool _hasRemoteDescription = false;
  bool _isCreatingPeerConnection = false;
  bool _isSettingUpMedia = false;
  bool _isSendingOffer = false;
  Completer<void>? _setupMediaCompleter;
  final Completer<void> _mediaReady = Completer<void>();

  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  final List<Map<String, dynamic>> _queuedLocalCandidates = [];
  final Set<String> _processedCandidateKeys = {};

  final Map<String, dynamic> _iceConfig = {
    'iceServers': List<Map<String, dynamic>>.from(CallConfig.defaultIceServers),
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  String get _myUserId => AuthService().userId.trim();

  @override
  void initState() {
    super.initState();
    _camEnabled = widget.callType == 'video';
    _remoteCamEnabled = widget.callType == 'video';
    _speakerEnabled = widget.callType == 'video';
    if (widget.targetUserId.trim().isNotEmpty) {
      _remoteParticipantId = widget.targetUserId.trim();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Subscribe to signaling BEFORE async media setup so offers/candidates aren't missed
    _listenToSignaling();
    _initWebRtc();
    _startTimer();
    _startRingingTimeout();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isConnected) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  void _startRingingTimeout() {
    if (!widget.isOutgoing) return;
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 35), () {
      if (!mounted || _isConnected || _hasEnded) return;
      _finishCall(sendHangup: true, reason: 'no_answer');
    });
  }

  Future<void> _fetchIceConfig() async {
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await ApiService().getChatIceServers(token: token);
      if (res.success && res.data != null && res.data!['iceServers'] is List) {
        final rawList = res.data!['iceServers'] as List;
        final parsed = <Map<String, dynamic>>[];
        for (final entry in rawList) {
          if (entry is Map) {
            parsed.add(Map<String, dynamic>.from(entry));
          }
        }
        if (parsed.isNotEmpty) {
          _iceConfig['iceServers'] = parsed;
        }
      }
    } catch (_) {}
  }

  Future<void> _initWebRtc() async {
    if (!kIsWeb) {
      try {
        await WebRTC.initialize();
      } catch (_) {}
    }

    await _fetchIceConfig();

    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    } catch (e) {
      debugPrint('[WebRtcCallScreen] Renderer init warning: $e');
    }

    await _setupLocalMedia();
    if (!_mediaReady.isCompleted) _mediaReady.complete();
    _joinCallRoom();

    if (!widget.isOutgoing) {
      ChatSocketService().sendCallSignal('call_accept', {
        'callId': widget.callId,
        'targetId': widget.targetUserId,
      });
    }

    _connectionWatchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted || _isConnected || _hasEnded) return;
      if (widget.isOutgoing &&
          _remoteParticipantId != null &&
          _peerConnection == null) {
        _mediaReady.future.then((_) async {
          if (!mounted || _hasEnded || _peerConnection != null) return;
          await _createPeerConnection();
          await _sendOffer();
        });
      }
    });
  }

  void _applySpeakerphone() {
    if (kIsWeb) return;
    try {
      Helper.setSpeakerphoneOn(_speakerEnabled);
    } catch (e) {
      debugPrint('[WebRtcCallScreen] Speakerphone toggle notice: $e');
    }
  }

  Future<void> _setupLocalMedia() async {
    if (_localStream != null) return;
    if (_isSettingUpMedia && _setupMediaCompleter != null) {
      await _setupMediaCompleter!.future;
      return;
    }
    _isSettingUpMedia = true;
    _setupMediaCompleter = Completer<void>();

    try {
      if (!kIsWeb) {
        try {
          var micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            await Permission.microphone.request();
          }
        } catch (_) {}

        if (widget.callType == 'video') {
          try {
            var camStatus = await Permission.camera.status;
            if (!camStatus.isGranted) {
              await Permission.camera.request();
            }
          } catch (_) {}
        }
      }

      _applySpeakerphone();

      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': widget.callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 720},
                'height': {'ideal': 1280},
                'frameRate': {'ideal': 30},
              }
            : false,
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      } catch (_) {
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': widget.callType == 'video' ? {'facingMode': 'user'} : false,
          });
        } catch (e) {
          debugPrint('[WebRtcCallScreen] getUserMedia fallback error: $e');
        }
      }

      if (widget.callType == 'video' && _localStream != null) {
        _localRenderer.srcObject = _localStream;
      }

      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          track.enabled = _micEnabled;
        }
        for (final track in _localStream!.getVideoTracks()) {
          track.enabled = _camEnabled;
        }
        _applySpeakerphone();
      }

      if (mounted) setState(() {});
    } finally {
      _isSettingUpMedia = false;
      if (!(_setupMediaCompleter?.isCompleted ?? true)) {
        _setupMediaCompleter?.complete();
      }
    }
  }

  void _joinCallRoom() {
    ChatSocketService().sendCallSignal('call_join', {
      'callId': widget.callId,
      'targetId': widget.targetUserId,
      'conversationId': widget.conversationId,
      'callType': widget.callType,
      'nickname': AuthService().userUsername.isNotEmpty
          ? AuthService().userUsername
          : AuthService().userName,
    });
  }

  void _listenToSignaling() {
    _signalSub = ChatSocketService().onCallSignal.listen((event) async {
      if (!mounted || _hasEnded) return;
      final type = event['type']?.toString() ?? '';
      final callId = event['callId']?.toString() ?? '';
      if (callId != widget.callId) return;

      try {
        switch (type) {
          case 'call_ringing':
            if (mounted && !_isConnected) {
              setState(() => _isRemoteRinging = true);
            }
            break;

          case 'call_accept':
            if (event['senderId'] != null) {
              _remoteParticipantId = event['senderId'].toString();
              _flushLocalCandidates();
            }
            if (widget.isOutgoing) {
              await _mediaReady.future;
              if (!mounted || _hasEnded) return;
              if (_peerConnection == null) {
                await _createPeerConnection();
                await _sendOffer();
              }
            }
            break;

          case 'call_joined_ack':
            final existing = event['existingParticipants'] as List<dynamic>?;
            if (existing != null && existing.isNotEmpty) {
              _remoteParticipantId = existing.first.toString();
              _flushLocalCandidates();
              await _mediaReady.future;
              if (!mounted || _hasEnded) return;
              if (_peerConnection == null && widget.isOutgoing) {
                await _createPeerConnection();
                await _sendOffer();
              }
            }
            break;

          case 'participant_joined':
            final pid = event['participantId']?.toString();
            if (pid != null && pid.isNotEmpty && pid != _myUserId) {
              _remoteParticipantId = pid;
              _flushLocalCandidates();
              await _mediaReady.future;
              if (!mounted || _hasEnded) return;
              if (widget.isOutgoing && _peerConnection == null) {
                await _createPeerConnection();
                await _sendOffer();
              }
            }
            break;

          case 'call_offer':
            if (event['senderId'] != null) {
              _remoteParticipantId = event['senderId'].toString();
              _flushLocalCandidates();
            }
            await _mediaReady.future;
            if (!mounted || _hasEnded) return;
            await _createPeerConnection();

            final offerMap = event['sdp'];
            final offerSdp =
                (offerMap is Map ? offerMap['sdp'] : offerMap)?.toString() ?? '';
            if (offerSdp.isNotEmpty && _peerConnection != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(offerSdp, 'offer'),
              );
              _hasRemoteDescription = true;
              await _sendAnswer();
              await _processQueuedCandidates();
            }
            break;

          case 'call_answer':
            if (_peerConnection != null) {
              if (event['senderId'] != null) {
                _remoteParticipantId = event['senderId'].toString();
                _flushLocalCandidates();
              }
              final answerMap = event['sdp'];
              final answerSdp =
                  (answerMap is Map ? answerMap['sdp'] : answerMap)?.toString() ?? '';
              if (answerSdp.isNotEmpty) {
                await _peerConnection!.setRemoteDescription(
                  RTCSessionDescription(answerSdp, 'answer'),
                );
                _hasRemoteDescription = true;
                await _processQueuedCandidates();
              }
            }
            break;

          case 'ice_candidate':
            final candMap = event['candidate'];
            if (candMap is Map && candMap['candidate'] != null) {
              final cand = RTCIceCandidate(
                candMap['candidate'].toString(),
                candMap['sdpMid']?.toString(),
                candMap['sdpMLineIndex'] is int
                    ? candMap['sdpMLineIndex'] as int
                    : int.tryParse('${candMap['sdpMLineIndex']}'),
              );
              final key = '${cand.candidate}_${cand.sdpMid}_${cand.sdpMLineIndex}';
              if (!_processedCandidateKeys.contains(key)) {
                _processedCandidateKeys.add(key);
                if (_peerConnection != null && _hasRemoteDescription) {
                  try {
                    await _peerConnection!.addCandidate(cand);
                  } catch (_) {}
                } else {
                  _queuedRemoteCandidates.add(cand);
                }
              }
            }
            break;

          case 'media_toggle':
            if (mounted) {
              setState(() {
                if (event['micEnabled'] is bool) {
                  _remoteMicEnabled = event['micEnabled'] as bool;
                }
                if (event['camEnabled'] is bool) {
                  _remoteCamEnabled = event['camEnabled'] as bool;
                }
              });
            }
            break;

          case 'call_busy':
            _finishCall(sendHangup: false, reason: 'busy');
            break;

          case 'call_failed':
            final failReason = event['reason']?.toString() ?? 'unavailable';
            _finishCall(sendHangup: false, reason: failReason);
            break;

          case 'call_ended':
          case 'call_hangup':
            if (event['senderId']?.toString() == _myUserId) return;
            final endReason = event['reason']?.toString() ?? 'ended';
            _finishCall(sendHangup: false, reason: endReason);
            break;
        }
      } catch (e, st) {
        debugPrint('[WebRtcCallScreen] Signaling error for $type: $e\n$st');
      }
    });
  }

  void _flushLocalCandidates() {
    if (_remoteParticipantId == null || _remoteParticipantId!.isEmpty) return;
    for (final payload in _queuedLocalCandidates) {
      payload['targetId'] = _remoteParticipantId;
      ChatSocketService().sendCallSignal('ice_candidate', payload);
    }
    _queuedLocalCandidates.clear();
  }

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null || _isCreatingPeerConnection) return;
    _isCreatingPeerConnection = true;

    try {
      if (_localStream == null) {
        await _setupLocalMedia();
      }
      if (!mounted || _hasEnded || _peerConnection != null) return;

      _peerConnection = await createPeerConnection(_iceConfig);

      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          final payload = <String, dynamic>{
            'callId': widget.callId,
            'targetId': _remoteParticipantId,
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          };
          if (_remoteParticipantId != null && _remoteParticipantId!.isNotEmpty) {
            ChatSocketService().sendCallSignal('ice_candidate', payload);
          } else {
            _queuedLocalCandidates.add(payload);
          }
        }
      };

      _peerConnection!.onTrack = (event) {
        if (!mounted || _hasEnded) return;
        final stream = event.streams.isNotEmpty ? event.streams.first : null;
        if (stream != null && _remoteStream != stream) {
          _remoteStream = stream;
          if (widget.callType == 'video') {
            _remoteRenderer.srcObject = stream;
          }
        }
        _markConnected();
      };

      _peerConnection!.onAddStream = (stream) {
        if (!mounted || _hasEnded) return;
        if (_remoteStream != stream) {
          _remoteStream = stream;
          if (widget.callType == 'video') {
            _remoteRenderer.srcObject = stream;
          }
        }
        _markConnected();
      };

      _peerConnection!.onConnectionState = (state) {
        if (!mounted || _hasEnded) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _markConnected();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _finishCall(sendHangup: true, reason: 'connection_failed');
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        if (!mounted || _hasEnded) return;
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          _markConnected();
        }
      };

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }
    } catch (e) {
      debugPrint('[WebRtcCallScreen] PeerConnection creation error: $e');
    } finally {
      _isCreatingPeerConnection = false;
    }
  }

  void _markConnected() {
    _ringingTimeoutTimer?.cancel();
    _connectionWatchdog?.cancel();
    if (mounted && !_isConnected) {
      setState(() => _isConnected = true);
    }
    _applySpeakerphone();
  }

  Future<void> _sendOffer() async {
    if (_peerConnection == null || _isSendingOffer) return;
    _isSendingOffer = true;
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': widget.callType == 'video',
      });
      await _peerConnection!.setLocalDescription(offer);

      ChatSocketService().sendCallSignal('call_offer', {
        'callId': widget.callId,
        'targetId': _remoteParticipantId,
        'callType': widget.callType,
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
      });
    } catch (e) {
      debugPrint('[WebRtcCallScreen] Offer error: $e');
    } finally {
      _isSendingOffer = false;
    }
  }

  Future<void> _sendAnswer() async {
    if (_peerConnection == null) return;
    try {
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': widget.callType == 'video',
      });
      await _peerConnection!.setLocalDescription(answer);

      ChatSocketService().sendCallSignal('call_answer', {
        'callId': widget.callId,
        'targetId': _remoteParticipantId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
    } catch (e) {
      debugPrint('[WebRtcCallScreen] Answer error: $e');
    }
  }

  Future<void> _processQueuedCandidates() async {
    if (_peerConnection == null) return;
    for (final candidate in _queuedRemoteCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (_) {}
    }
    _queuedRemoteCandidates.clear();
  }

  void _toggleMic() {
    if (_localStream == null) return;
    final audioTrack = _localStream!.getAudioTracks().firstOrNull;
    if (audioTrack == null) return;
    audioTrack.enabled = !audioTrack.enabled;
    setState(() => _micEnabled = audioTrack.enabled);
    ChatSocketService().sendCallSignal('media_toggle', {
      'callId': widget.callId,
      'targetId': _remoteParticipantId,
      'micEnabled': _micEnabled,
      'camEnabled': _camEnabled,
    });
  }

  void _toggleCam() {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack == null) return;
    videoTrack.enabled = !videoTrack.enabled;
    setState(() => _camEnabled = videoTrack.enabled);
    ChatSocketService().sendCallSignal('media_toggle', {
      'callId': widget.callId,
      'targetId': _remoteParticipantId,
      'micEnabled': _micEnabled,
      'camEnabled': _camEnabled,
    });
  }

  void _toggleSpeaker() {
    setState(() => _speakerEnabled = !_speakerEnabled);
    _applySpeakerphone();
  }

  Future<void> _switchCamera() async {
    if (_localStream == null || widget.callType != 'video' || kIsWeb) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      try {
        await Helper.switchCamera(videoTrack);
      } catch (_) {}
    }
  }

  void _finishCall({required bool sendHangup, required String reason}) {
    if (_hasEnded) return;
    _hasEnded = true;
    if (sendHangup) {
      ChatSocketService().sendCallSignal('call_hangup', {
        'callId': widget.callId,
        'targetId': _remoteParticipantId,
        'reason': reason,
      });
    }
    widget.onCallEnded?.call(widget.callType, _secondsElapsed, reason);
    widget.onClose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _connectionWatchdog?.cancel();
    _signalSub?.cancel();
    _pulseController.dispose();

    if (_peerConnection != null) {
      try {
        _peerConnection!.onIceCandidate = null;
        _peerConnection!.onTrack = null;
        _peerConnection!.onAddStream = null;
        _peerConnection!.onConnectionState = null;
        _peerConnection!.onIceConnectionState = null;
      } catch (_) {}
    }

    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (_) {}

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      _localStream?.dispose();
    } catch (_) {}

    try {
      _remoteStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}

    try {
      _peerConnection?.close();
      _peerConnection?.dispose();
    } catch (_) {}

    try {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (_) {}

    super.dispose();
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _statusText() {
    if (_isConnected) return _formatTimer(_secondsElapsed);
    if (!widget.isOutgoing) return 'Connecting...';
    if (_isRemoteRinging) return 'Ringing...';
    return 'Calling...';
  }

  @override
  Widget build(BuildContext context) {
    final bool isVideo = widget.callType == 'video';
    final bool showRemoteVideo =
        isVideo && _isConnected && _remoteStream != null && _remoteCamEnabled;
    final bool showLocalPreview = isVideo && _localStream != null && _camEnabled;

    if (widget.isPipMode) {
      return IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF2B1564), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showRemoteVideo)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else if (!showRemoteVideo && showLocalPreview && !isVideo)
                const SizedBox.shrink()
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UserAvatar(
                      avatarUrl: widget.peerAvatar,
                      displayName: widget.peerName,
                      radius: 22,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        widget.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.onMinimize != null) {
          widget.onMinimize!();
        } else {
          _finishCall(sendHangup: true, reason: 'ended');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Stack(
          children: [
            // Background: Remote Video, Local Video (while calling), or Instagram Dark Gradient
            if (showRemoteVideo)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  key: const ValueKey('hidely_remote_video'),
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else if (isVideo && !_isConnected && showLocalPreview)
              Positioned.fill(
                child: RTCVideoView(
                  _localRenderer,
                  key: const ValueKey('hidely_local_preview_full'),
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1E1145),
                        Color(0xFF0F172A),
                        Color(0xFF090D16),
                      ],
                    ),
                  ),
                ),
              ),

            // Subtle dark scrim over video so icons & text remain crisp
            if (isVideo)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // Draggable Floating Local Video PiP (when remote video is connected)
            if (isVideo && _isConnected && showLocalPreview)
              Positioned(
                right: _localPipRight,
                bottom: _localPipBottom,
                width: 112,
                height: 162,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final size = MediaQuery.of(context).size;
                    setState(() {
                      _localPipRight = (_localPipRight - details.delta.dx)
                          .clamp(12.0, size.width - 124.0);
                      _localPipBottom = (_localPipBottom - details.delta.dy)
                          .clamp(112.0, size.height - 230.0);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(
                      _localRenderer,
                      key: const ValueKey('hidely_local_pip'),
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Main Call Chrome (Top Bar + Center Avatar/Status + Bottom Dock)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: [
                    // Top bar (Minimize + Encrypted badge + Flip Camera)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.onMinimize != null)
                          _topGlassIcon(
                            icon: Icons.keyboard_arrow_down_rounded,
                            onTap: widget.onMinimize!,
                          )
                        else
                          const SizedBox(width: 42),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFF4ADE80),
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isConnected ? _formatTimer(_secondsElapsed) : 'P2P Encrypted',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isVideo)
                          _topGlassIcon(
                            icon: Icons.flip_camera_ios_rounded,
                            onTap: _switchCamera,
                          )
                        else
                          const SizedBox(width: 42),
                      ],
                    ),

                    if (!showRemoteVideo)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isVideo || !_isConnected || !_remoteCamEnabled) ...[
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) {
                                    final scale = _isConnected
                                        ? 1.0
                                        : (1.0 + _pulseController.value * 0.25);
                                    final opacity = _isConnected
                                        ? 0.0
                                        : (1.0 - _pulseController.value);
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (!_isConnected)
                                          Transform.scale(
                                            scale: scale,
                                            child: Container(
                                              width: 138,
                                              height: 138,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF7C3AED)
                                                    .withValues(alpha: opacity * 0.35),
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF7C3AED),
                                                Color(0xFF2563EB),
                                              ],
                                            ),
                                          ),
                                          child: UserAvatar(
                                            avatarUrl: widget.peerAvatar,
                                            displayName: widget.peerName,
                                            radius: 58,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 22),
                              ],
                              Text(
                                widget.peerName,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 8),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                !_remoteCamEnabled && _isConnected && isVideo
                                    ? 'Camera off • ${_statusText()}'
                                    : _statusText(),
                                style: TextStyle(
                                  color: _isConnected
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!_remoteMicEnabled && _isConnected) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mic_off_rounded,
                                          color: Colors.white70, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Muted',
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      if (!_remoteMicEnabled)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic_off_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.peerName} muted microphone',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],

                    // Bottom Frosted Dock (Instagram Call Controls)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151924).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isVideo)
                            _dockControl(
                              icon: _camEnabled
                                  ? Icons.videocam_rounded
                                  : Icons.videocam_off_rounded,
                              active: _camEnabled,
                              onTap: _toggleCam,
                            ),
                          _dockControl(
                            icon: _micEnabled
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            active: _micEnabled,
                            onTap: _toggleMic,
                          ),
                          _dockControl(
                            icon: _speakerEnabled
                                ? Icons.volume_up_rounded
                                : Icons.hearing_rounded,
                            active: _speakerEnabled,
                            highlightColor: const Color(0xFF3B82F6),
                            onTap: _toggleSpeaker,
                          ),
                          GestureDetector(
                            onTap: () => _finishCall(
                              sendHangup: true,
                              reason: _isConnected ? 'ended' : 'cancelled',
                            ),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topGlassIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _dockControl({
    required IconData icon,
    required bool active,
    Color? highlightColor,
    required VoidCallback onTap,
  }) {
    final bgColor = !active
        ? const Color(0xFFEF4444).withValues(alpha: 0.22)
        : (highlightColor?.withValues(alpha: 0.24) ??
            Colors.white.withValues(alpha: 0.12));
    final fgColor = !active
        ? const Color(0xFFFCA5A5)
        : (highlightColor ?? Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: fgColor, size: 23),
      ),
    );
  }
}

