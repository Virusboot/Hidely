import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:hidely_new/services/api_service.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  socket_io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

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

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

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
    });

    _socket!.onDisconnect((_) {
      debugPrint('[ChatSocketService] Disconnected from Socket.IO server.');
      _isConnected = false;
    });

    _socket!.on('new_message', (data) {
      if (data is Map<String, dynamic>) {
        _newMessageController.add(data);
      } else if (data is Map) {
        _newMessageController.add(Map<String, dynamic>.from(data));
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
  }

  void joinConversation(int conversationId) {
    _socket?.emit('join_conversation', {'conversationId': conversationId});
  }

  void leaveConversation(int conversationId) {
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
  }

  void startTyping(int conversationId) {
    _socket?.emit('typing_start', {'conversationId': conversationId});
  }

  void stopTyping(int conversationId) {
    _socket?.emit('typing_stop', {'conversationId': conversationId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
