import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  socket_io.Socket? _socket;
  bool _isConnected = false;
  String? _activeToken;
  final Set<int> _joinedConversations = <int>{};
  int? currentActiveConversationId;
  bool get isConnected => _isConnected;

  @visibleForTesting
  bool skipSocketConnectForTest = false;

  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTypingStatus => _typingController.stream;

  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageReaction => _reactionController.stream;

  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageRead => _readController.stream;

  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceUpdate => _presenceController.stream;

  // WebRTC Call Signaling Streams (Unified stream with 'type' + dedicated streams)
  final _callSignalController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onCallSignal => _callSignalController.stream;

  void _forwardCallEvent(String type, dynamic data) {
    final map = data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    map['type'] = type;
    _callSignalController.add(map);
  }

  void connect(String token) {
    if (token.trim().isEmpty || skipSocketConnectForTest) return;

    if (_socket != null) {
      if (_activeToken == token) {
        if (!_socket!.connected) {
          _socket!.connect();
        }
        return;
      }
      // Account / token changed: cleanly tear down old authenticated socket
      disconnect();
    }

    _activeToken = token;
    final String serverUrl = ApiService().baseUrl;

    _socket = socket_io.io(
      serverUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[ChatSocketService] Connected to Socket.IO server.');
      _isConnected = true;
      for (final convId in _joinedConversations) {
        _socket?.emit('join_conversation', {'conversationId': convId});
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[ChatSocketService] Disconnected from Socket.IO server.');
      _isConnected = false;
    });

    _socket!.on('new_message', (data) {
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (map != null) {
        _newMessageController.add(map);
        final convId = int.tryParse(map['conversation_id']?.toString() ?? '');
        if (convId != null && convId != currentActiveConversationId) {
          NotificationPollingService().showChatSocketNotification(map);
        }
      }
    });

    _socket!.on('typing_status', (data) {
      if (data is Map) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message_reaction', (data) {
      if (data is Map) {
        _reactionController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message_read', (data) {
      if (data is Map) {
        _readController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('presence_update', (data) {
      if (data is Map) {
        _presenceController.add(Map<String, dynamic>.from(data));
      }
    });

    const callEvents = [
      'call_invite',
      'call_ringing',
      'call_accept',
      'call_joined_ack',
      'participant_joined',
      'call_offer',
      'call_answer',
      'ice_candidate',
      'media_toggle',
      'call_ended',
      'call_busy',
      'call_failed',
    ];
    for (final evt in callEvents) {
      _socket!.on(evt, (data) => _forwardCallEvent(evt, data));
    }
  }

  void joinConversation(int conversationId) {
    _joinedConversations.add(conversationId);
    if (_socket != null && _socket!.connected) {
      _socket?.emit('join_conversation', {'conversationId': conversationId});
    }
  }

  void leaveConversation(int conversationId) {
    _joinedConversations.remove(conversationId);
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
  }

  void startTyping(int conversationId) {
    _socket?.emit('typing_start', {'conversationId': conversationId});
  }

  void stopTyping(int conversationId) {
    _socket?.emit('typing_stop', {'conversationId': conversationId});
  }

  void sendCallSignal(String eventName, Map<String, dynamic> payload) {
    if (skipSocketConnectForTest) return;
    _socket?.emit(eventName, payload);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _activeToken = null;
    _isConnected = false;
    _joinedConversations.clear();
  }

  @visibleForTesting
  void emitNewMessageForTest(Map<String, dynamic> data) {
    _newMessageController.add(data);
  }

  @visibleForTesting
  void emitTypingStatusForTest(Map<String, dynamic> data) {
    _typingController.add(data);
  }

  @visibleForTesting
  void emitReactionForTest(Map<String, dynamic> data) {
    _reactionController.add(data);
  }

  @visibleForTesting
  void emitReadForTest(Map<String, dynamic> data) {
    _readController.add(data);
  }

  @visibleForTesting
  void emitPresenceForTest(Map<String, dynamic> data) {
    _presenceController.add(data);
  }

  @visibleForTesting
  void emitCallSignalForTest(String type, Map<String, dynamic> data) {
    _forwardCallEvent(type, data);
  }
}
