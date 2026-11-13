import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/services/call_manager.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:image_picker/image_picker.dart';

/// Trip Itinerary Details Model for Groups
class TripItineraryData {
  final String dates;
  final List<String> placesToVisit;
  final String howToReach;
  final String stayInfo;
  final String budgetEst;

  const TripItineraryData({
    required this.dates,
    required this.placesToVisit,
    required this.howToReach,
    required this.stayInfo,
    required this.budgetEst,
  });
}

String _formatChatTime(dynamic raw) {
  if (raw == null) return '';
  final str = raw.toString().trim();
  if (str.isEmpty) return '';
  final parsed = DateTime.tryParse(str);
  if (parsed != null) {
    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $period';
  }
  return str.length >= 16 ? str.substring(11, 16) : str;
}

String _normalizeChatAvatar(dynamic raw) {
  final str = (raw ?? '').toString().trim();
  if (str.isEmpty ||
      str == 'assets/images/user1.jpg' ||
      str == 'assets/icons/Profile.png') {
    return '';
  }
  return str;
}

String _cleanHandle(String? raw) {
  return (raw ?? '').trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
}

/// Chat Item Model (Group Trips + Personal 1-on-1 DMs)
class ChatItem {
  final String id;
  final String? targetUserId;
  final String? targetUsername;
  final String name;
  final String avatar;
  String lastMessage;
  String time;
  int unreadCount;
  final bool isGroup;
  final bool isOfficial;
  bool isOnline;
  final String? destination;
  final int? memberCount;
  final String? status;
  final Color themeColor;
  final List<String>? memberAvatars;
  final TripItineraryData? itinerary;

  ChatItem({
    required this.id,
    this.targetUserId,
    this.targetUsername,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    this.isOfficial = false,
    this.isOnline = false,
    this.destination,
    this.memberCount,
    this.status,
    this.themeColor = const Color(0xff5B3EC8),
    this.memberAvatars,
    this.itinerary,
  });
}

/// Chat Message Model
class ChatMessage {
  String id;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String time;
  final bool isMe;
  final String? isHost;
  final String? attachmentType; // 'itinerary_card', 'poll', 'image', 'voice', null
  final Map<String, dynamic>? attachmentData;
  final String? replyToSender;
  final String? replyToText;
  bool hasHeartReaction;
  String reactionEmoji;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.time,
    required this.isMe,
    this.isHost,
    this.attachmentType,
    this.attachmentData,
    this.replyToSender,
    this.replyToText,
    this.hasHeartReaction = false,
    this.reactionEmoji = '❤️',
  });
}

class GroupChatScreen extends StatefulWidget {
  static final ValueNotifier<bool> isChatRoomOpen = ValueNotifier<bool>(false);
  static dynamic activeState;
  static ChatItem? pendingOpenChat;

  static void clearSessionCache() {
    _GroupChatScreenState._allChats.clear();
    _ChatRoomViewState._messagesHistory.clear();
    _GroupChatScreenState._cacheOwnerUserId = null;
    pendingOpenChat = null;
    isChatRoomOpen.value = false;
  }

  static void openOrQueueDirectChat(ChatItem chat) {
    final state = activeState;
    if (state != null) {
      state.openDirectChat(chat);
    } else {
      pendingOpenChat = chat;
    }
  }

  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  ChatItem? _activeChat;
  String _selectedFilter = 'All'; // 'All', 'Groups', 'Direct', 'Official'

  final Map<String, bool> _onlineStatusMap = {};
  List<dynamic> _searchResultsUsers = [];
  bool _isSearchingUsers = false;
  StreamSubscription? _presenceSub;
  StreamSubscription? _globalMsgSub;
  Timer? _searchDebounce;
  Set<String> _knownBlockedUsers = <String>{};
  int _conversationsLoadSeq = 0;
  final Set<String> _seenInboxSocketMsgIds = <String>{};

  static String? _cacheOwnerUserId;

  @override
  void initState() {
    super.initState();
    GroupChatScreen.activeState = this;
    _ensureCacheMatchesCurrentUser();
    _knownBlockedUsers = Set<String>.from(AuthService().blockedUsersNotifier.value);
    AuthService().blockedUsersNotifier.addListener(_onBlockedUsersChanged);
    AuthService().sessionEpochNotifier.addListener(_onSessionChanged);
    _initChatService();
    _searchController.addListener(_onSearchChanged);

    final pending = GroupChatScreen.pendingOpenChat;
    if (pending != null) {
      GroupChatScreen.pendingOpenChat = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openDirectChat(pending);
      });
    }
  }

  void _ensureCacheMatchesCurrentUser() {
    final currentUserId = AuthService().userId;
    if (_cacheOwnerUserId != null && _cacheOwnerUserId != currentUserId) {
      _allChats.clear();
      _ChatRoomViewState._messagesHistory.clear();
      _onlineStatusMap.clear();
      _seenInboxSocketMsgIds.clear();
      _activeChat = null;
      GroupChatScreen.isChatRoomOpen.value = false;
    }
    _cacheOwnerUserId = currentUserId;
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _ensureCacheMatchesCurrentUser();
    setState(() {
      _searchResultsUsers = [];
    });
    _initChatService();
  }

  void _onBlockedUsersChanged() {
    if (!mounted) return;
    final nextBlocked = AuthService().blockedUsersNotifier.value;
    final bool unblockedSomeone = _knownBlockedUsers.difference(nextBlocked).isNotEmpty;
    _knownBlockedUsers = Set<String>.from(nextBlocked);

    if (_activeChat != null &&
        !_activeChat!.isGroup &&
        (AuthService().isUserBlockedSync(_activeChat!.targetUsername) ||
            AuthService().isUserBlockedSync(_activeChat!.name))) {
      _closeChat();
    } else {
      setState(() {
        _searchResultsUsers = _searchResultsUsers
            .where((u) => !AuthService().isUserBlockedSync(u is Map ? u['username']?.toString() : null))
            .toList();
      });
    }
    if (unblockedSomeone) {
      _loadConversations();
    }
  }

  void _initChatService() {
    final token = AuthService().token;
    if (token != null && token.isNotEmpty) {
      ChatSocketService().connect(token);
    }
    _loadConversations();

    _presenceSub ??= ChatSocketService().onPresenceUpdate.listen((data) {
      final userIdStr = data['userId']?.toString();
      final status = data['status']?.toString();
      if (userIdStr != null) {
        final bool isOnline = status == 'online';
        if (mounted) {
          setState(() {
            _onlineStatusMap[userIdStr] = isOnline;
            for (int i = 0; i < _allChats.length; i++) {
              if (!_allChats[i].isGroup && _allChats[i].targetUserId == userIdStr) {
                _allChats[i].isOnline = isOnline;
              }
            }
          });
        }
      }
    });

    _globalMsgSub ??= ChatSocketService().onNewMessage.listen((data) {
      final convIdStr = data['conversation_id']?.toString();
      final msgIdStr = data['id']?.toString();
      if (convIdStr == null || convIdStr.isEmpty) {
        _loadConversations();
        return;
      }
      if (msgIdStr != null && _seenInboxSocketMsgIds.contains(msgIdStr)) {
        return;
      }
      if (msgIdStr != null) {
        _seenInboxSocketMsgIds.add(msgIdStr);
      }

      final currentUserId = AuthService().userId;
      final isMe = data['sender_id']?.toString() == currentUserId;
      final rawText = (data['text'] ?? '').toString().trim();
      final preview = rawText.isNotEmpty
          ? (isMe ? 'You: $rawText' : rawText)
          : (data['type'] == 'image'
              ? (isMe ? 'You: Sent an image' : 'Sent an image')
              : (isMe ? 'You: Sent an attachment' : 'Sent an attachment'));
      final timeStr = _formatChatTime(data['created_at']) .isNotEmpty
          ? _formatChatTime(data['created_at'])
          : 'Just now';

      final existingIdx = _allChats.indexWhere((c) => c.id == convIdStr);
      if (existingIdx != -1) {
        if (mounted) {
          setState(() {
            final item = _allChats.removeAt(existingIdx);
            item.lastMessage = preview;
            item.time = timeStr;
            if (!isMe && _activeChat?.id != convIdStr) {
              item.unreadCount += 1;
            }
            _allChats.insert(0, item);
          });
        }
      } else {
        _loadConversations();
      }
    });
  }

  bool _isSameDirectPeer(ChatItem a, ChatItem b) {
    if (a.isGroup || b.isGroup) return false;
    if (a.id == b.id) return true;
    final aId = a.targetUserId?.trim();
    final bId = b.targetUserId?.trim();
    if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty && aId == bId) {
      return true;
    }
    final aHandle = _cleanHandle(a.targetUsername);
    final bHandle = _cleanHandle(b.targetUsername);
    if (aHandle.isNotEmpty && bHandle.isNotEmpty && aHandle == bHandle) {
      return true;
    }
    return false;
  }

  Future<void> _loadConversations() async {
    _ensureCacheMatchesCurrentUser();
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    final int loadSeq = ++_conversationsLoadSeq;
    final res = await ApiService().getChatConversations(token: token);
    if (!mounted || loadSeq != _conversationsLoadSeq) return;

    if (res.success && res.data != null && res.data!['conversations'] != null) {
      final List rawConvs = res.data!['conversations'];
      final currentUserId = AuthService().userId;

      final List<ChatItem> loadedChats = [];
      final Map<String, int> directPeerIndexById = {};
      final Map<String, int> directPeerIndexByHandle = {};
      final Set<String> seenConvIds = {};

      for (var conv in rawConvs) {
        if (conv is! Map) continue;
        final convId = conv['id'].toString();
        if (seenConvIds.contains(convId)) continue;
        seenConvIds.add(convId);

        final isGroup = conv['type'] == 'GROUP';
        final participants = conv['participants'] as List? ?? [];

        Map<String, dynamic>? otherParticipant;
        if (!isGroup && participants.isNotEmpty) {
          for (var p in participants) {
            if (p is! Map) continue;
            final pId = p['id']?.toString();
            if (pId != null && pId != currentUserId.toString()) {
              otherParticipant = Map<String, dynamic>.from(p);
              break;
            }
          }
          otherParticipant ??= conv['target_user'] is Map
              ? Map<String, dynamic>.from(conv['target_user'])
              : (participants.first is Map ? Map<String, dynamic>.from(participants.first) : null);
        } else if (!isGroup && conv['target_user'] is Map) {
          otherParticipant = Map<String, dynamic>.from(conv['target_user']);
        }

        // Skip orphaned DIRECT rows with no valid remote participant
        if (!isGroup && otherParticipant == null) {
          continue;
        }

        final targetId = otherParticipant?['id']?.toString();
        final targetUsername = otherParticipant?['username']?.toString();
        if (!isGroup && targetId == currentUserId.toString()) {
          continue;
        }

        final name = isGroup
            ? (conv['name']?.toString() ?? 'Group Trip')
            : ((otherParticipant?['name']?.toString().trim().isNotEmpty == true)
                ? otherParticipant!['name'].toString().trim()
                : (targetUsername ?? 'User'));
        final avatar = isGroup
            ? ''
            : _normalizeChatAvatar(otherParticipant?['profile_picture']);

        final bool isOnline = targetId != null
            ? (_onlineStatusMap[targetId] ?? (otherParticipant?['is_online'] == true))
            : false;

        final lastMsgObj = conv['last_message'];
        String lastMsgText = 'No messages yet';
        if (lastMsgObj is Map) {
          final isSentByMe = lastMsgObj['sender_id']?.toString() == currentUserId.toString();
          final rawTxt = (lastMsgObj['text'] ?? '').toString().trim();
          final baseTxt = rawTxt.isNotEmpty
              ? rawTxt
              : (lastMsgObj['type'] == 'image'
                  ? 'Sent an image'
                  : 'Sent an attachment');
          lastMsgText = isSentByMe && !baseTxt.startsWith('You: ')
              ? 'You: $baseTxt'
              : baseTxt;
        }

        final rawTime = lastMsgObj is Map
            ? lastMsgObj['created_at']?.toString()
            : conv['updated_at']?.toString();
        final formattedTime = _formatChatTime(rawTime);
        final int unread = _activeChat?.id == convId
            ? 0
            : (conv['unread_count'] is int
                ? conv['unread_count'] as int
                : int.tryParse('${conv['unread_count'] ?? 0}') ?? 0);

        final item = ChatItem(
          id: convId,
          targetUserId: targetId,
          targetUsername: targetUsername,
          name: name,
          avatar: avatar,
          lastMessage: lastMsgText,
          time: formattedTime,
          unreadCount: unread,
          isGroup: isGroup,
          isOnline: isOnline,
        );

        // Deduplicate multiple DIRECT conversations for the exact same peer profile
        if (!isGroup) {
          final peerHandle = _cleanHandle(targetUsername);
          int? dupIdx;
          if (targetId != null && targetId.isNotEmpty) {
            dupIdx = directPeerIndexById[targetId];
          }
          if (dupIdx == null && peerHandle.isNotEmpty) {
            dupIdx = directPeerIndexByHandle[peerHandle];
          }
          if (dupIdx != null) {
            final existing = loadedChats[dupIdx];
            final bool existingHasMsgs = existing.lastMessage != 'No messages yet';
            final bool newHasMsgs = item.lastMessage != 'No messages yet';
            final int totalUnread = existing.unreadCount + item.unreadCount;
            if (!existingHasMsgs && newHasMsgs) {
              item.unreadCount = totalUnread;
              loadedChats[dupIdx] = item;
            } else {
              existing.unreadCount = totalUnread;
            }
            continue;
          }
          if (targetId != null && targetId.isNotEmpty) {
            directPeerIndexById[targetId] = loadedChats.length;
          }
          if (peerHandle.isNotEmpty) {
            directPeerIndexByHandle[peerHandle] = loadedChats.length;
          }
        }

        loadedChats.add(item);
      }

      if (mounted) {
        setState(() {
          _allChats.clear();
          _allChats.addAll(loadedChats);
          if (_activeChat != null) {
            final idx = _allChats.indexWhere((c) => c.id == _activeChat!.id);
            if (idx != -1) {
              _activeChat = _allChats[idx];
            }
          }
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _searchResultsUsers = [];
          _isSearchingUsers = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearchingUsers = true);
      final res = await ApiService().searchUsers(query: query, token: AuthService().token);
      if (mounted) {
        final currentId = AuthService().userId;
        setState(() {
          _isSearchingUsers = false;
          if (res.success && res.data != null && res.data!['users'] != null) {
            _searchResultsUsers = (res.data!['users'] as List)
                .where((u) {
                  if (u is! Map) return false;
                  if (u['id']?.toString() == currentId) return false;
                  return !AuthService().isUserBlockedSync(u['username']?.toString());
                })
                .toList();
          } else {
            _searchResultsUsers = [];
          }
        });
      }
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    if (_searchController.text.isNotEmpty || _searchResultsUsers.isNotEmpty) {
      _searchController.clear();
      if (mounted) {
        setState(() {
          _searchResultsUsers = [];
          _isSearchingUsers = false;
        });
      }
    }
  }

  Future<void> openDirectChat(ChatItem chat) async {
    if (!chat.isGroup &&
        (AuthService().isUserBlockedSync(chat.targetUsername) ||
            AuthService().isUserBlockedSync(chat.name))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unblock this user to send a message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    clearSearch();

    // Remove any leftover synthetic placeholder rows ('dm_...') for this peer user
    _allChats.removeWhere((c) => c.id.startsWith('dm_') && _isSameDirectPeer(c, chat) && c.id != chat.id);

    int existingIdx = _allChats.indexWhere((c) => _isSameDirectPeer(c, chat) || c.id == chat.id);
    if (existingIdx == -1 && int.tryParse(chat.id) == null && chat.targetUserId != null) {
      // Unresolved placeholder ID passed; resolve real conversation ID from backend
      final token = AuthService().token;
      final tId = int.tryParse(chat.targetUserId!);
      if (token != null && tId != null) {
        final res = await ApiService().getOrCreateDirectChat(token: token, targetUserId: tId);
        if (!mounted) return;
        if (res.success && res.data != null && res.data!['conversationId'] != null) {
          chat = ChatItem(
            id: res.data!['conversationId'].toString(),
            targetUserId: chat.targetUserId,
            targetUsername: chat.targetUsername,
            name: chat.name,
            avatar: _normalizeChatAvatar(chat.avatar),
            lastMessage: chat.lastMessage,
            time: chat.time,
            unreadCount: 0,
            isGroup: false,
            isOnline: chat.isOnline,
          );
          existingIdx = _allChats.indexWhere((c) => _isSameDirectPeer(c, chat) || c.id == chat.id);
        }
      }
    }

    if (existingIdx != -1) {
      final existingChat = _allChats.removeAt(existingIdx);
      existingChat.unreadCount = 0;
      setState(() {
        _allChats.insert(0, existingChat);
      });
      _openChat(existingChat);
    } else {
      final normalizedChat = ChatItem(
        id: chat.id,
        targetUserId: chat.targetUserId,
        targetUsername: chat.targetUsername,
        name: chat.name,
        avatar: _normalizeChatAvatar(chat.avatar),
        lastMessage: chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages yet',
        time: chat.time,
        unreadCount: 0,
        isGroup: chat.isGroup,
        isOfficial: chat.isOfficial,
        isOnline: chat.isOnline,
        destination: chat.destination,
        memberCount: chat.memberCount,
        status: chat.status,
        themeColor: chat.themeColor,
        memberAvatars: chat.memberAvatars,
        itinerary: chat.itinerary,
      );
      setState(() {
        _allChats.insert(0, normalizedChat);
      });
      _openChat(normalizedChat);
    }
  }

  void _openChat(ChatItem chat) {
    clearSearch();
    setState(() {
      chat.unreadCount = 0;
      _activeChat = chat;
      GroupChatScreen.isChatRoomOpen.value = true;
    });
  }

  void _closeChat() {
    clearSearch();
    setState(() {
      _activeChat = null;
      GroupChatScreen.isChatRoomOpen.value = false;
    });
  }

  bool _isUnread(ChatItem chat) {
    return chat.unreadCount > 0;
  }

  // Real-time Chat List Stream (Clean & Production Ready)
  static final List<ChatItem> _allChats = [];

  @override
  void dispose() {
    AuthService().blockedUsersNotifier.removeListener(_onBlockedUsersChanged);
    AuthService().sessionEpochNotifier.removeListener(_onSessionChanged);
    if (GroupChatScreen.activeState == this) {
      GroupChatScreen.activeState = null;
    }
    _presenceSub?.cancel();
    _globalMsgSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showNewMessageUserSearchSheet() {
    final TextEditingController userSearchCtrl = TextEditingController();
    List usersList = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _createNewGroupTripDialog();
                        },
                        icon: const Icon(Icons.group_add_rounded, size: 18, color: Color(0xff2563EB)),
                        label: const Text('New Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff2563EB))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xff1C0D5A)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('chat_new_msg_search_pill'),
                constraints: const BoxConstraints(minHeight: 46),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  key: const Key('chat_new_msg_search_input'),
                  controller: userSearchCtrl,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    color: Color(0xff1C0D5A),
                    height: 1.25,
                  ),
                  onChanged: (val) async {
                    final q = val.trim();
                    if (q.length < 2) {
                      setModalState(() {
                        isLoading = false;
                        usersList = [];
                      });
                      return;
                    }
                    setModalState(() => isLoading = true);
                    final res = await ApiService().searchUsers(
                      query: q,
                      token: AuthService().token,
                    );
                    final currentId = AuthService().userId;
                    setModalState(() {
                      isLoading = false;
                      if (res.success && res.data != null && res.data!['users'] != null) {
                        usersList = (res.data!['users'] as List)
                            .where((u) {
                              if (u is! Map) return false;
                              if (u['id']?.toString() == currentId) return false;
                              return !AuthService().isUserBlockedSync(u['username']?.toString());
                            })
                            .toList();
                      } else {
                        usersList = [];
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search username or name...',
                    hintStyle: TextStyle(
                      fontFamily: 'PublicSans',
                      color: Colors.black45,
                      fontSize: 14,
                      height: 1.25,
                    ),
                    prefixIcon: Icon(Icons.search, color: Color(0xff1C0D5A), size: 20),
                    prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 46),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : usersList.isEmpty
                        ? const Center(child: Text('Search for a traveler to start messaging', style: TextStyle(color: Colors.black45)))
                        : ListView.builder(
                            itemCount: usersList.length,
                            itemBuilder: (ctx, idx) {
                              final u = usersList[idx];
                              final displayName = (u['name']?.toString().trim().isNotEmpty == true)
                                  ? u['name'].toString().trim()
                                  : (u['username']?.toString() ?? 'User');
                              final avatarUrl = _normalizeChatAvatar(u['profile_picture']);
                              return ListTile(
                                leading: UserAvatar(
                                  avatarUrl: avatarUrl,
                                  displayName: displayName,
                                  radius: 20,
                                ),
                                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('@${u['username'] ?? ''}'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final token = AuthService().token;
                                  final tId = int.tryParse('${u['id']}');
                                  if (token != null && tId != null) {
                                    final res = await ApiService().getOrCreateDirectChat(token: token, targetUserId: tId);
                                    if (!mounted) return;
                                    if (res.success && res.data != null && res.data!['conversationId'] != null) {
                                      final convId = res.data!['conversationId'].toString();
                                      final newDirectChat = ChatItem(
                                        id: convId,
                                        targetUserId: u['id']?.toString(),
                                        targetUsername: u['username']?.toString(),
                                        name: displayName,
                                        avatar: avatarUrl,
                                        lastMessage: 'No messages yet',
                                        time: '',
                                        unreadCount: 0,
                                        isGroup: false,
                                      );
                                      openDirectChat(newDirectChat);
                                    } else if (res.message.isNotEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    String localFilter = _selectedFilter;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(() => localFilter = 'All'),
                          child: const Text("Reset", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xff1C0D5A), size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Category", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip('All', 'All', localFilter, (val) => setModalState(() => localFilter = val)),
                      const SizedBox(width: 8),
                      _buildFilterChip('Groups', 'Groups', localFilter, (val) => setModalState(() => localFilter = val)),
                      const SizedBox(width: 8),
                      _buildFilterChip('Direct', 'Direct DMs', localFilter, (val) => setModalState(() => localFilter = val)),
                      const SizedBox(width: 8),
                      _buildFilterChip('Official', 'Official', localFilter, (val) => setModalState(() => localFilter = val)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2B1564),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedFilter = localFilter;
                      });
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String currentFilter, ValueChanged<String> onTap) {
    final bool isSelected = currentFilter == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff2B1564) : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xff1C0D5A).withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _createNewGroupTripDialog() {
    final titleController = TextEditingController();
    final destController = TextEditingController();
    final datesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Create New Group", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Color(0xff1C0D5A), size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Group Name", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 14, color: Color(0xff1C0D5A)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Nainital Explorer Squad 🏞️',
                    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xffF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Destination", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                const SizedBox(height: 8),
                TextField(
                  controller: destController,
                  style: const TextStyle(fontSize: 14, color: Color(0xff1C0D5A)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Nainital, Uttarakhand',
                    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xffF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Travel Dates", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
                const SizedBox(height: 8),
                TextField(
                  controller: datesController,
                  style: const TextStyle(fontSize: 14, color: Color(0xff1C0D5A)),
                  decoration: InputDecoration(
                    hintText: 'e.g. 15 Oct - 18 Oct',
                    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xffF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        setState(() {
                          _allChats.insert(
                            0,
                            ChatItem(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: titleController.text.trim(),
                              avatar:
                                  'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=300&q=80',
                              lastMessage: 'You created this group trip squad!',
                              time: 'Just now',
                              unreadCount: 0,
                              isGroup: true,
                              destination: destController.text.trim().isNotEmpty
                                  ? destController.text.trim()
                                  : 'Explore Destination',
                              memberCount: 1,
                              status: 'Planning',
                              themeColor: const Color(0xff5B3EC8),
                              memberAvatars: [
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
                              ],
                              itinerary: TripItineraryData(
                                dates: datesController.text.trim().isNotEmpty
                                    ? datesController.text.trim()
                                    : 'To be decided',
                                placesToVisit: ['Main Lake & View Points', 'Local Markets'],
                                howToReach: 'Volvo Bus / Shared Taxi / Car Pool',
                                stayInfo: 'Resort / Homestay (Voting in chat)',
                                budgetEst: 'Shared budget',
                              ),
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                        HapticFeedback.lightImpact();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2B1564),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text("Create Group", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeChat != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _closeChat();
        },
        child: _ChatRoomView(
          chat: _activeChat!,
          onBack: _closeChat,
        ),
      );
    }

    final query = _searchController.text.toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xffF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: Navigator.canPop(context) ? 0 : 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 22.0, height: 22.0),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          AuthService().userUsername.isNotEmpty
              ? AuthService().userUsername
              : 'harsh_bhardwaj',
          style: const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xff1C0D5A),
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: _selectedFilter != 'All' ? const Color(0xff2563EB) : const Color(0xff1C0D5A),
              size: 24,
            ),
            tooltip: 'Filter Messages',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Image.asset('assets/icons/edit.png', width: 24, height: 24, color: const Color(0xff1C0D5A)),
            tooltip: 'New Message / Squad',
            onPressed: _showNewMessageUserSearchSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffE0F2FE),
              Color(0xffFFFFFF),
            ],
          ),
        ),
        child: _buildChatListSection(
          items: _allChats.where((t) {
            if (!t.isGroup &&
                (AuthService().isUserBlockedSync(t.targetUsername) ||
                    AuthService().isUserBlockedSync(t.name))) {
              return false;
            }
            final matchesQuery = query.isEmpty ||
                t.name.toLowerCase().contains(query) ||
                (t.targetUsername ?? '').toLowerCase().contains(query) ||
                (t.destination ?? '').toLowerCase().contains(query) ||
                t.lastMessage.toLowerCase().contains(query);

            if (!matchesQuery) return false;

            if (_selectedFilter == 'Groups') return t.isGroup;
            if (_selectedFilter == 'Direct') return !t.isGroup;
            if (_selectedFilter == 'Official') return t.isOfficial;
            return true;
          }).toList(),
          emptyMessage: _selectedFilter == 'All'
              ? 'No Messages Found'
              : 'No $_selectedFilter Messages Found',
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        key: const Key('chat_search_pill'),
        constraints: const BoxConstraints(minHeight: 48),
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          key: const Key('chat_search_input'),
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 14,
            color: Colors.black87,
            height: 1.25,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search messages, groups, or travelers...',
            hintStyle: const TextStyle(
              fontFamily: 'PublicSans',
              color: Colors.black38,
              fontSize: 14,
              height: 1.25,
            ),
            prefixIcon: const Icon(Icons.search, color: Color(0xff1C0D5A), size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Colors.black38, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsUsersSection() {
    if (_searchController.text.trim().length < 2) return const SizedBox.shrink();
    if (_isSearchingUsers) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff2B1564))),
      );
    }
    if (_searchResultsUsers.isEmpty) return const SizedBox.shrink();

    final filteredUsers = _searchResultsUsers.where((u) {
      final uId = u['id']?.toString();
      final name = u['name']?.toString().toLowerCase();
      final username = _cleanHandle(u['username']?.toString());

      if (AuthService().isUserBlockedSync(username)) {
        return false;
      }

      final alreadyInChats = _allChats.any((chat) {
        if (chat.targetUserId != null && uId != null && chat.targetUserId == uId) {
          return true;
        }
        if (username.isNotEmpty && _cleanHandle(chat.targetUsername) == username) {
          return true;
        }
        if (name != null && name.isNotEmpty && chat.name.toLowerCase() == name) {
          return true;
        }
        if (username.isNotEmpty && chat.name.toLowerCase() == username) {
          return true;
        }
        return false;
      });
      return !alreadyInChats;
    }).toList();

    if (filteredUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Travelers & Profiles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xff1C0D5A),
              fontFamily: 'PublicSans',
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredUsers.length,
          itemBuilder: (ctx, idx) {
            final u = filteredUsers[idx];
            final String uId = u['id']?.toString() ?? '';
            final bool isOnline = _onlineStatusMap[uId] == true;
            final String displayName = (u['name']?.toString().trim().isNotEmpty == true)
                ? u['name'].toString().trim()
                : (u['username']?.toString() ?? 'User');
            final String avatarUrl = _normalizeChatAvatar(u['profile_picture']);

            return Material(
              type: MaterialType.transparency,
              child: ListTile(
              leading: Stack(
                children: [
                  UserAvatar(
                    avatarUrl: avatarUrl,
                    displayName: displayName,
                    radius: 20,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xff22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff1C0D5A)),
              ),
              subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff2563EB)),
                ),
              ),
              onTap: () async {
                final token = AuthService().token;
                final targetIntId = int.tryParse('${u['id']}');
                if (token != null && targetIntId != null) {
                  final res = await ApiService().getOrCreateDirectChat(token: token, targetUserId: targetIntId);
                  if (!mounted) return;
                  if (res.success && res.data != null && res.data!['conversationId'] != null) {
                    final convId = res.data!['conversationId'].toString();
                    final newDirectChat = ChatItem(
                      id: convId,
                      targetUserId: u['id']?.toString(),
                      targetUsername: u['username']?.toString(),
                      name: displayName,
                      avatar: avatarUrl,
                      lastMessage: 'No messages yet',
                      time: '',
                      unreadCount: 0,
                      isGroup: false,
                      isOnline: isOnline,
                    );
                    openDirectChat(newDirectChat);
                  } else if (res.message.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            );
          },
        ),
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildChatListSection({required List<ChatItem> items, required String emptyMessage}) {
    if (items.isEmpty) {
      return Column(
        children: [
          _buildSearchAndFilterBar(),
          _buildSearchResultsUsersSection(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xff1C0D5A).withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        size: 44,
                        color: Color(0xff1C0D5A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Messages Yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1C0D5A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: const Color(0xff2B1564),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _buildSearchAndFilterBar(),
                _buildSearchResultsUsersSection(),
              ],
            );
          }
          final chat = items[index - 1];
          final bool hasUnread = _isUnread(chat);

          return GestureDetector(
            onTap: () => _openChat(chat),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  // Avatar with online status dot
                  Stack(
                    children: [
                      UserAvatar(
                        avatarUrl: _normalizeChatAvatar(chat.avatar),
                        displayName: chat.name,
                        radius: 26,
                      ),
                      if (chat.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xff16A34A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Chat Info & Message Preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat.name,
                                style: TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 15,
                                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                  color: const Color(0xff1C0D5A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.isOfficial) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, color: Color(0xff2563EB), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.time.isNotEmpty
                                    ? '${chat.lastMessage}  •  ${chat.time}'
                                    : chat.lastMessage,
                                style: TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 13,
                                  color: hasUnread
                                      ? const Color(0xff1C0D5A)
                                      : Colors.black54,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      key: Key('chat_unread_dot_${chat.id}'),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: chat.themeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Chat Room View (Group Trip Chat or Direct 1-on-1 DM)
class _ChatRoomView extends StatefulWidget {
  final ChatItem chat;
  final VoidCallback onBack;

  const _ChatRoomView({required this.chat, required this.onBack});

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isRecording = false;
  bool _isLoadingMessages = true;
  String? _playingVoiceMsgId;
  ChatMessage? _replyingTo;

  static final Map<String, List<ChatMessage>> _messagesHistory = {};

  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _reactionSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _readSub;
  Timer? _typingIdleTimer;
  Timer? _remoteTypingTimeoutTimer;
  bool _isSendingTyping = false;
  bool _isOtherUserTyping = false;
  late bool _isTargetOnline;
  int _peerLastReadMsgId = 0;

  @override
  void initState() {
    super.initState();
    _isTargetOnline = widget.chat.isOnline;
    if (!_messagesHistory.containsKey(widget.chat.id)) {
      _messagesHistory[widget.chat.id] = [];
    }
    _messages = _messagesHistory[widget.chat.id]!;
    _isLoadingMessages = _messages.isEmpty;
    _loadRealMessages();
    _setupSocketListeners();
    if (_messages.isNotEmpty) {
      _scrollToBottom(animated: false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    });
  }

  Future<void> _loadRealMessages() async {
    final token = AuthService().token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingMessages = false);
      return;
    }

    ChatSocketService().connect(token);

    final int? convId = int.tryParse(widget.chat.id);
    if (convId != null) {
      ChatSocketService().currentActiveConversationId = convId;
      ChatSocketService().joinConversation(convId);

      final res = await ApiService().getChatMessages(token: token, conversationId: convId);
      if (!mounted) return;

      if (res.success && res.data != null && res.data!['messages'] != null) {
        final List rawMsgs = res.data!['messages'];
        final currentUserId = AuthService().userId;

        final loadedMsgs = rawMsgs.map((m) {
          final senderId = m['sender_id'];
          final isMe = senderId != null && senderId.toString() == currentUserId;
          final reactions = m['reactions'] as List?;
          final hasReaction = reactions != null && reactions.isNotEmpty;
          final firstEmoji = (hasReaction && reactions.first is Map)
              ? (reactions.first['emoji']?.toString() ?? '❤️')
              : '❤️';
          final replyObj = m['reply_to_message'] is Map
              ? Map<String, dynamic>.from(m['reply_to_message'])
              : null;
          final formattedTime = _formatChatTime(m['created_at']);

          return ChatMessage(
            id: m['id'].toString(),
            senderName: isMe ? 'You' : (m['sender_name']?.toString() ?? 'User'),
            senderAvatar: _normalizeChatAvatar(m['sender_profile_picture']),
            text: (m['text'] ?? '').toString(),
            time: formattedTime.isNotEmpty ? formattedTime : 'Just now',
            isMe: isMe,
            attachmentType: m['type'] != null && m['type'] != 'text' ? m['type'].toString() : null,
            attachmentData: m['attachments'] is List && (m['attachments'] as List).isNotEmpty
                ? {'url': m['attachments'][0]['url']}
                : (m['shared_entity_type'] != null
                    ? {'type': m['shared_entity_type'], 'id': m['shared_entity_id']}
                    : null),
            replyToSender: replyObj?['sender_name']?.toString(),
            replyToText: replyObj?['text']?.toString(),
            hasHeartReaction: hasReaction,
            reactionEmoji: firstEmoji.isNotEmpty ? firstEmoji : '❤️',
          );
        }).toList();

        _messagesHistory[widget.chat.id] = loadedMsgs;

        setState(() {
          _messages = loadedMsgs;
          widget.chat.unreadCount = 0;
          if (loadedMsgs.isNotEmpty) {
            final latest = loadedMsgs.last;
            final latestText = latest.text.trim();
            if (latestText.isNotEmpty) {
              widget.chat.lastMessage = latest.isMe ? 'You: $latestText' : latestText;
            }
            if (latest.time.isNotEmpty) {
              widget.chat.time = latest.time;
            }
          }
          _isLoadingMessages = false;
        });

        _scrollToBottom(animated: false);
        ApiService().markChatConversationAsRead(token: token, conversationId: convId);
      } else {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    } else {
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }

  void _setupSocketListeners() {
    _msgSub = ChatSocketService().onNewMessage.listen((data) {
      if (!mounted) return;
      final String? msgConvId = data['conversation_id']?.toString();
      if (msgConvId != widget.chat.id) return;

      final String incomingId = data['id']?.toString() ?? '';
      if (incomingId.isNotEmpty && _messages.any((m) => m.id == incomingId)) {
        return;
      }

      final senderId = data['sender_id']?.toString();
      final currentUserId = AuthService().userId;
      final isMe = senderId != null && senderId == currentUserId;
      final incomingText = (data['text'] ?? '').toString();

      if (isMe) {
        final tempIdx = _messages.lastIndexWhere(
          (m) => m.isMe && m.id.startsWith('temp_') && m.text.trim() == incomingText.trim(),
        );
        if (tempIdx != -1) {
          if (incomingId.isNotEmpty) {
            setState(() {
              _messages[tempIdx].id = incomingId;
            });
          }
          return;
        }
      }

      final replyObj = data['reply_to_message'] is Map
          ? Map<String, dynamic>.from(data['reply_to_message'])
          : null;
      final formattedTime = _formatChatTime(data['created_at']);
      final timeStr = formattedTime.isNotEmpty ? formattedTime : 'Just now';

      final msgObj = ChatMessage(
        id: incomingId.isNotEmpty ? incomingId : 'sock_${DateTime.now().microsecondsSinceEpoch}',
        senderName: isMe ? 'You' : (data['sender_name']?.toString() ?? 'User'),
        senderAvatar: _normalizeChatAvatar(data['sender_profile_picture']),
        text: incomingText,
        time: timeStr,
        isMe: isMe,
        attachmentType: data['type'] != null && data['type'] != 'text' ? data['type'].toString() : null,
        attachmentData: data['attachments'] is List && (data['attachments'] as List).isNotEmpty
            ? {'url': data['attachments'][0]['url']}
            : null,
        replyToSender: replyObj?['sender_name']?.toString(),
        replyToText: replyObj?['text']?.toString(),
      );

      setState(() {
        if (!isMe) {
          _isOtherUserTyping = false;
          _remoteTypingTimeoutTimer?.cancel();
        }
        if (incomingId.isEmpty || !_messages.any((m) => m.id == incomingId)) {
          _messages.add(msgObj);
        }
        final trimmed = incomingText.trim();
        widget.chat.lastMessage = trimmed.isNotEmpty
            ? (isMe ? 'You: $trimmed' : trimmed)
            : (isMe ? 'You: Sent an attachment' : 'Sent an attachment');
        widget.chat.time = timeStr;
        widget.chat.unreadCount = 0;
      });
      _scrollToBottom();

      final int? convId = int.tryParse(widget.chat.id);
      if (!isMe && convId != null) {
        final token = AuthService().token;
        if (token != null && token.isNotEmpty) {
          ApiService().markChatConversationAsRead(token: token, conversationId: convId);
        }
      }
    });

    _typingSub = ChatSocketService().onTypingStatus.listen((data) {
      if (!mounted) return;
      final evtConvId = (data['conversationId'] ?? data['conversation_id'])?.toString();
      if (evtConvId != widget.chat.id) return;
      if (data['userId']?.toString() == AuthService().userId) return;

      final bool isTyping = data['isTyping'] == true;
      _remoteTypingTimeoutTimer?.cancel();
      if (isTyping) {
        _remoteTypingTimeoutTimer = Timer(const Duration(seconds: 4), () {
          if (mounted && _isOtherUserTyping) {
            setState(() => _isOtherUserTyping = false);
          }
        });
      }
      setState(() {
        _isOtherUserTyping = isTyping;
      });
    });

    _reactionSub = ChatSocketService().onMessageReaction.listen((data) {
      if (!mounted) return;
      final evtConvId = (data['conversationId'] ?? data['conversation_id'])?.toString();
      if (evtConvId != null && evtConvId != widget.chat.id) return;
      final msgId = (data['messageId'] ?? data['message_id'])?.toString();
      if (msgId == null || msgId.isEmpty) return;

      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        setState(() {
          _messages[idx].hasHeartReaction = data['active'] == true;
          final emoji = data['emoji']?.toString();
          if (emoji != null && emoji.isNotEmpty) {
            _messages[idx].reactionEmoji = emoji;
          }
        });
      }
    });

    _presenceSub = ChatSocketService().onPresenceUpdate.listen((data) {
      final userIdStr = data['userId']?.toString();
      final status = data['status']?.toString();
      if (userIdStr != null &&
          !widget.chat.isGroup &&
          widget.chat.targetUserId == userIdStr) {
        final bool isOnline = status == 'online';
        if (mounted) {
          setState(() {
            _isTargetOnline = isOnline;
            widget.chat.isOnline = isOnline;
          });
        }
      }
    });

    _readSub = ChatSocketService().onMessageRead.listen((data) {
      if (!mounted) return;
      final evtConvId = (data['conversationId'] ?? data['conversation_id'])?.toString();
      if (evtConvId != widget.chat.id) return;
      if (data['userId']?.toString() == AuthService().userId) return;
      final rawReadId = data['lastReadMessageId'] ?? data['last_read_message_id'];
      final parsedId = rawReadId is int ? rawReadId : int.tryParse('$rawReadId') ?? 0;
      if (parsedId > _peerLastReadMsgId) {
        setState(() => _peerLastReadMsgId = parsedId);
      }
    });
  }

  void _onMessageInputChanged(String val) {
    setState(() {});
    final int? convId = int.tryParse(widget.chat.id);
    if (convId == null) return;

    final hasText = val.trim().isNotEmpty;
    if (hasText) {
      if (!_isSendingTyping) {
        _isSendingTyping = true;
        ChatSocketService().startTyping(convId);
      }
      _typingIdleTimer?.cancel();
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        if (_isSendingTyping) {
          _isSendingTyping = false;
          ChatSocketService().stopTyping(convId);
        }
      });
    } else if (_isSendingTyping) {
      _typingIdleTimer?.cancel();
      _isSendingTyping = false;
      ChatSocketService().stopTyping(convId);
    }
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    _remoteTypingTimeoutTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _reactionSub?.cancel();
    _presenceSub?.cancel();
    _readSub?.cancel();
    final int? convId = int.tryParse(widget.chat.id);
    if (convId != null) {
      if (_isSendingTyping) {
        ChatSocketService().stopTyping(convId);
      }
      if (ChatSocketService().currentActiveConversationId == convId) {
        ChatSocketService().currentActiveConversationId = null;
      }
      ChatSocketService().leaveConversation(convId);
    }
    _scrollController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final replyTarget = _replyingTo;
    final int? replyToMsgId = replyTarget != null ? int.tryParse(replyTarget.id) : null;

    _msgController.clear();
    _typingIdleTimer?.cancel();
    final timeStr = _formatChatTime(DateTime.now().toIso8601String());
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    final localMsg = ChatMessage(
      id: tempId,
      senderName: 'You',
      senderAvatar: _normalizeChatAvatar(AuthService().userProfilePicture),
      text: text,
      time: timeStr,
      isMe: true,
      replyToSender: replyTarget?.senderName,
      replyToText: replyTarget?.text,
    );

    setState(() {
      _messages.add(localMsg);
      _replyingTo = null;
      widget.chat.lastMessage = 'You: $text';
      widget.chat.time = timeStr;
    });
    _scrollToBottom();

    HapticFeedback.lightImpact();

    final int? convId = int.tryParse(widget.chat.id);
    final token = AuthService().token;

    if (convId != null && token != null && token.isNotEmpty) {
      if (_isSendingTyping) {
        _isSendingTyping = false;
        ChatSocketService().stopTyping(convId);
      }
      final res = await ApiService().sendChatMessage(
        token: token,
        conversationId: convId,
        type: 'text',
        text: text,
        replyToMessageId: replyToMsgId,
      );
      if (!mounted) return;
      if (res.success && res.data != null && res.data!['message'] is Map) {
        final serverId = res.data!['message']['id']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          setState(() {
            final alreadyExists = _messages.any((m) => m.id == serverId && !identical(m, localMsg));
            if (alreadyExists) {
              _messages.remove(localMsg);
            } else {
              localMsg.id = serverId;
            }
          });
        }
      } else if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Failed to send message.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showItineraryModal() {
    final itin = widget.chat.itinerary;
    if (itin == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xffE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.chat.themeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment_rounded, color: widget.chat.themeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chat.name,
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff1C0D5A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Trip Schedule, Spots & Transport Roadmap',
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: widget.chat.themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. KAB H (Travel Dates & Schedule)
              _buildItineraryRow(
                icon: Icons.calendar_today_rounded,
                color: const Color(0xff7C3AED),
                title: '📅 KAB H (Travel Schedule & Dates)',
                desc: itin.dates,
              ),

              // 2. KHA KHA JAEGE (Key Tourist Spots)
              _buildItineraryRow(
                icon: Icons.map_rounded,
                color: const Color(0xff16A34A),
                title: '📍 KHA KHA JAEGE (Key Attractions)',
                desc: itin.placesToVisit.join('\n'),
              ),

              // 3. KESE JAEGE (Transport & Logistics)
              _buildItineraryRow(
                icon: Icons.directions_bus_rounded,
                color: const Color(0xff2563EB),
                title: '🚌 KESE JAEGE (Mode of Transport)',
                desc: itin.howToReach,
              ),

              // 4. STAY & BUDGET
              _buildItineraryRow(
                icon: Icons.hotel_rounded,
                color: const Color(0xffD97706),
                title: '🏨 STAY & BUDGET ESTIMATE',
                desc: '${itin.stayInfo}\nEstimated Budget: ${itin.budgetEst}',
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text('Got it! Back to Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.chat.themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItineraryRow({required IconData icon, required Color color, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12.5,
                    color: Color(0xff334155),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCallingDialog(bool isVideo) async {
    if (widget.chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice and video calls are supported in 1-on-1 direct chats.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String targetId = (widget.chat.targetUserId ?? '').trim();
    final int? convId = int.tryParse(widget.chat.id);
    if (targetId.isEmpty && convId != null) {
      final token = AuthService().token;
      if (token != null && token.isNotEmpty) {
        final convRes = await ApiService().getChatConversations(token: token);
        if (convRes.success && convRes.data?['conversations'] is List) {
          for (final conv in convRes.data!['conversations'] as List) {
            if (conv is Map && conv['id']?.toString() == widget.chat.id) {
              final target = conv['target_user'];
              if (target is Map && target['id'] != null) {
                targetId = target['id'].toString();
                break;
              }
            }
          }
        }
      }
    }

    if (!mounted) return;
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start call right now. Please reopen the chat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await CallManager().startCall(
      context: context,
      targetUserId: targetId,
      peerName: widget.chat.name,
      peerUsername: widget.chat.targetUsername ?? '',
      peerAvatar: _normalizeChatAvatar(widget.chat.avatar),
      conversationId: convId,
      callType: isVideo ? 'video' : 'audio',
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        final timeStr = _formatChatTime(DateTime.now().toIso8601String());
        final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

        final localMsg = ChatMessage(
          id: tempId,
          senderName: AuthService().userName.isNotEmpty ? AuthService().userName : 'You',
          senderAvatar: _normalizeChatAvatar(AuthService().userProfilePicture),
          text: 'Sent an image 🏞️',
          time: timeStr,
          isMe: true,
          attachmentType: 'image',
          attachmentData: {
            'imageFile': pickedFile.path,
          },
        );

        setState(() {
          _messages.add(localMsg);
          widget.chat.lastMessage = 'You: Sent an image 🏞️';
          widget.chat.time = timeStr;
        });
        _scrollToBottom();

        HapticFeedback.lightImpact();

        final int? convId = int.tryParse(widget.chat.id);
        final token = AuthService().token;
        if (convId != null && token != null && token.isNotEmpty) {
          final res = await ApiService().sendChatMessage(
            token: token,
            conversationId: convId,
            type: 'image',
            text: 'Sent an image 🏞️',
            mediaFile: kIsWeb ? null : File(pickedFile.path),
          );
          if (!mounted) return;
          if (res.success && res.data != null && res.data!['message'] is Map) {
            final serverMsg = res.data!['message'];
            final serverId = serverMsg['id']?.toString();
            final attachments = serverMsg['attachments'] as List? ?? [];
            setState(() {
              if (serverId != null && serverId.isNotEmpty) {
                localMsg.id = serverId;
              }
              if (attachments.isNotEmpty) {
                localMsg.attachmentData?['imageUrl'] = attachments[0]['url'];
                localMsg.attachmentData?['url'] = attachments[0]['url'];
              }
            });
          } else if (!res.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message.isNotEmpty ? res.message : 'Failed to send image.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _sendVoiceNote() async {
    final timeStr = _formatChatTime(DateTime.now().toIso8601String());
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    final localMsg = ChatMessage(
      id: tempId,
      senderName: AuthService().userName.isNotEmpty ? AuthService().userName : 'You',
      senderAvatar: _normalizeChatAvatar(AuthService().userProfilePicture),
      text: 'Voice note (0:05)',
      time: timeStr,
      isMe: true,
      attachmentType: 'voice',
    );

    setState(() {
      _messages.add(localMsg);
      widget.chat.lastMessage = 'You: 🎤 Voice note (0:05)';
      widget.chat.time = timeStr;
    });
    _scrollToBottom();

    HapticFeedback.lightImpact();

    final int? convId = int.tryParse(widget.chat.id);
    final token = AuthService().token;
    if (convId != null && token != null && token.isNotEmpty) {
      final res = await ApiService().sendChatMessage(
        token: token,
        conversationId: convId,
        type: 'voice',
        text: 'Voice note (0:05)',
      );
      if (mounted && res.success && res.data != null && res.data!['message'] is Map) {
        final serverId = res.data!['message']['id']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          setState(() => localMsg.id = serverId);
        }
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String? imageUrl, String? localPath) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.92),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: !kIsWeb && localPath != null && localPath.isNotEmpty && File(localPath).existsSync()
                    ? Image.file(File(localPath), fit: BoxFit.contain)
                    : (kIsWeb && localPath != null && localPath.isNotEmpty)
                        ? Image.network(localPath, fit: BoxFit.contain)
                        : imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Center(
                              child: Text('Image unavailable', style: TextStyle(color: Colors.white70)),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAttachment(ChatMessage msg, {required bool isMe}) {
    if (msg.attachmentType != 'voice' && msg.attachmentType != 'audio') {
      return const SizedBox.shrink();
    }
    final isPlaying = _playingVoiceMsgId == msg.id;
    final color = isMe ? Colors.white : const Color(0xff2B1564);
    final trackColor = isMe ? Colors.white.withOpacity(0.3) : const Color(0xffCBD5E1);
    final activeTrackColor = isMe ? Colors.white : const Color(0xff2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.12) : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_playingVoiceMsgId == msg.id) {
                  _playingVoiceMsgId = null;
                } else {
                  _playingVoiceMsgId = msg.id;
                }
              });
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe ? Colors.white24 : const Color(0xff2B1564).withOpacity(0.1),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: color,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(12, (index) {
                  final height = 6.0 + ((index * 7) % 14);
                  final isActive = isPlaying && (index <= 6);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: isActive ? activeTrackColor : trackColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 3),
              Text(
                isPlaying ? 'Playing...' : '0:05',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'PublicSans',
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHeartReaction(ChatMessage msg, {String emoji = '❤️'}) async {
    setState(() {
      msg.hasHeartReaction = !(msg.hasHeartReaction);
      msg.reactionEmoji = emoji;
    });
    HapticFeedback.mediumImpact();

    final int? msgId = int.tryParse(msg.id);
    final token = AuthService().token;
    if (msgId != null && token != null && token.isNotEmpty) {
      await ApiService().toggleChatMessageReaction(
        token: token,
        messageId: msgId,
        emoji: emoji,
      );
    }
  }

  void _showMessageOptionsSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['❤️', '👍', '🔥', '😮', '👏', '😂'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleHeartReaction(msg, emoji: emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xff1C0D5A)),
                  title: const Text('Copy Message Text', style: TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.w600)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Color(0xff1C0D5A)),
                  title: const Text('Reply to Message', style: TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          key: const Key('chat_room_back_btn'),
          icon: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 22.0, height: 22.0),
          onPressed: widget.onBack,
        ),
        title: Row(
          children: [
            UserAvatar(
              avatarUrl: _normalizeChatAvatar(widget.chat.avatar),
              displayName: widget.chat.name,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.chat.name,
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1C0D5A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.chat.isOfficial) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Color(0xff2563EB), size: 15),
                      ],
                    ],
                  ),
                  Text(
                    _isOtherUserTyping
                        ? 'typing... 💬'
                        : widget.chat.isGroup
                            ? '${widget.chat.memberCount ?? 1} Travelers • ${widget.chat.destination ?? ''}'
                            : (_isTargetOnline || widget.chat.isOnline)
                                ? 'Active Now 🟢'
                                : 'Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isOtherUserTyping ? const Color(0xff2563EB) : widget.chat.themeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Color(0xff1C0D5A), size: 22),
            onPressed: () => _showCallingDialog(false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xff1C0D5A), size: 24),
            onPressed: () => _showCallingDialog(true),
          ),
          if (widget.chat.isGroup && widget.chat.itinerary != null)
            IconButton(
              icon: Icon(Icons.assignment_outlined, color: widget.chat.themeColor, size: 22),
              onPressed: _showItineraryModal,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages List
          Expanded(
            child: _isLoadingMessages && _messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xff2B1564),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.chat.themeColor.withOpacity(0.08),
                                border: Border.all(color: widget.chat.themeColor.withOpacity(0.2), width: 2),
                              ),
                              alignment: Alignment.center,
                              child: UserAvatar(
                                avatarUrl: _normalizeChatAvatar(widget.chat.avatar),
                                displayName: widget.chat.name,
                                radius: 38,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.chat.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'PublicSans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1C0D5A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.chat.isGroup
                                  ? 'Group Trip Squad • ${widget.chat.memberCount ?? 1} Members'
                                  : 'You\'re connected on Hidely',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'PublicSans',
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.chat.themeColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.waving_hand_rounded, color: Colors.amber.shade700, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Say hi to start the conversation!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'PublicSans',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff1C0D5A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isLastOutgoing = msg.isMe && index == _messages.lastIndexWhere((m) => m.isMe);
                      final msgNumericId = int.tryParse(msg.id) ?? 0;
                      final showSeen = isLastOutgoing &&
                          !widget.chat.isGroup &&
                          _peerLastReadMsgId > 0 &&
                          msgNumericId > 0 &&
                          msgNumericId <= _peerLastReadMsgId;
                      return _buildMessageBubble(msg, showSeen: showSeen);
                    },
                  ),
          ),

          // Pinned Trip Details Banner at Bottom (Group Chats)
          if (widget.chat.isGroup && widget.chat.itinerary != null)
            GestureDetector(
              onTap: _showItineraryModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.chat.themeColor.withOpacity(0.08),
                  border: Border(
                    top: BorderSide(color: widget.chat.themeColor.withOpacity(0.2)),
                    bottom: BorderSide(color: widget.chat.themeColor.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded, color: widget.chat.themeColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PINNED: Trip Schedule (Kab H), Spots (Kha Kha Jaege) & Transport (Kese Jaege)',
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: widget.chat.themeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: widget.chat.themeColor, size: 12),
                  ],
                ),
              ),
            ),

          if (_replyingTo != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Color(0xff5B3EC8), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Replying to ${_replyingTo!.senderName}',
                            style: const TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff2B1564),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyingTo!.text,
                            style: const TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            ),

          // Chat Input Bar (Instagram DM Style - Solid White Bottom Margin)
          Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xff2B1564), size: 23),
                      onPressed: () => _pickAndSendImage(ImageSource.camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Color(0xff2B1564), size: 22),
                      onPressed: () => _pickAndSendImage(ImageSource.gallery),
                    ),
                    if (widget.chat.isGroup && widget.chat.itinerary != null)
                      IconButton(
                        icon: Icon(Icons.assignment_outlined, color: widget.chat.themeColor, size: 22),
                        tooltip: 'Attach Trip Details',
                        onPressed: _showItineraryModal,
                      ),
                    Expanded(
                      child: Container(
                        key: const Key('chat_composer_pill'),
                        constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          key: const Key('chat_message_input'),
                          controller: _msgController,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: _onMessageInputChanged,
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 14,
                            height: 1.25,
                            color: Color(0xff1C0D5A),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _isRecording ? 'Recording voice note...' : 'Message...',
                            hintStyle: TextStyle(
                              fontFamily: 'PublicSans',
                              color: _isRecording ? Colors.red : Colors.black45,
                              fontSize: 14,
                              height: 1.25,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_msgController.text.trim().isNotEmpty)
                      GestureDetector(
                        key: const Key('chat_send_button'),
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: const Text(
                            'Send',
                            style: TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff2563EB),
                            ),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            setState(() => _isRecording = false);
                            _sendVoiceNote();
                          } else {
                            setState(() => _isRecording = true);
                          }
                        },
                        onLongPressStart: (_) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isRecording = true;
                          });
                        },
                        onLongPressEnd: (_) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isRecording = false;
                          });
                          _sendVoiceNote();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red.withOpacity(0.12) : Colors.transparent,
                          ),
                          child: Icon(
                            _isRecording ? Icons.send_rounded : Icons.mic_none_outlined,
                            color: _isRecording ? Colors.red : const Color(0xff2B1564),
                            size: 23,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  }

  Widget _buildImageAttachment(ChatMessage msg) {
    if (msg.attachmentType != 'image') return const SizedBox.shrink();

    final data = msg.attachmentData;
    final String? localPath = data?['imageFile'];
    String? imageUrl = data?['imageUrl'] ?? data?['url'] ?? data?['image_url'];

    if (imageUrl != null && !imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      imageUrl = imageUrl.startsWith('/')
          ? '${ApiService().baseUrl}$imageUrl'
          : '${ApiService().baseUrl}/$imageUrl';
    }

    if (!kIsWeb && localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(context, null, localPath),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(localPath),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (kIsWeb && localPath != null && localPath.isNotEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      imageUrl = localPath;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(context, imageUrl, null),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_rounded, color: Colors.grey, size: 22),
                    SizedBox(width: 6),
                    Text('Image unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildReplyQuote(ChatMessage msg, {required bool isMe}) {
    if (msg.replyToText == null || msg.replyToText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.14) : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : const Color(0xff5B3EC8),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.replyToSender != null && msg.replyToSender!.trim().isNotEmpty)
            Text(
              msg.replyToSender!,
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white.withOpacity(0.9) : const Color(0xff2B1564),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            msg.replyToText!,
            style: TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 11.5,
              color: isMe ? Colors.white70 : Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  bool _isCallLogMessage(ChatMessage msg) {
    if (msg.attachmentType == 'call_log') return true;
    final t = msg.text.trim();
    return (t.startsWith('📞') || t.startsWith('📹')) &&
        t.toLowerCase().contains('call');
  }

  Widget _buildCallLogPill(ChatMessage msg, {required bool isMe}) {
    final bool isVideo = msg.text.contains('📹') ||
        msg.text.toLowerCase().contains('video');
    final bool isMissed = msg.text.toLowerCase().contains('missed') ||
        msg.text.toLowerCase().contains('declined') ||
        msg.text.toLowerCase().contains('busy');
    final cleanLabel =
        msg.text.replaceFirst(RegExp(r'^(?:📞|📹)\s*', unicode: true), '').trim();

    return GestureDetector(
      onTap: widget.chat.isGroup ? null : () => _showCallingDialog(isVideo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMissed
                    ? const Color(0xffEF4444).withValues(alpha: isMe ? 0.28 : 0.14)
                    : (isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xff2B1564).withValues(alpha: 0.1)),
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                size: 18,
                color: isMissed
                    ? (isMe ? const Color(0xffFCA5A5) : const Color(0xffDC2626))
                    : (isMe ? Colors.white : const Color(0xff2B1564)),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cleanLabel,
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : const Color(0xff1C0D5A),
                    ),
                  ),
                  if (!widget.chat.isGroup)
                    Text(
                      'Tap to call back',
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 11,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, {bool showSeen = false}) {
    final bool isCallLog = _isCallLogMessage(msg);
    final bool hideRedundantImageLabel = msg.attachmentType == 'image' &&
        (msg.text.trim() == 'Sent an image 🏞️' || msg.text.trim() == 'Sent an image');

    return GestureDetector(
      onDoubleTap: () => _toggleHeartReaction(msg),
      onLongPress: () => _showMessageOptionsSheet(msg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (msg.isMe)
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: showSeen ? 4 : 12),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: const BoxDecoration(
                      color: Color(0xff2B1564),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildReplyQuote(msg, isMe: true),
                        _buildImageAttachment(msg),
                        _buildVoiceAttachment(msg, isMe: true),
                        if (isCallLog)
                          _buildCallLogPill(msg, isMe: true)
                        else if (!hideRedundantImageLabel)
                          Text(
                            msg.text,
                            style: const TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          msg.time,
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showSeen)
                    const Padding(
                      padding: EdgeInsets.only(right: 4, bottom: 10),
                      child: Text(
                        'Seen',
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      avatarUrl: _normalizeChatAvatar(msg.senderAvatar),
                      displayName: msg.senderName,
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 290),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(color: const Color(0xffE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    msg.senderName,
                                    style: const TextStyle(
                                      fontFamily: 'PublicSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff1C0D5A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (msg.isHost != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff2563EB).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      msg.isHost!,
                                      style: const TextStyle(
                                        fontFamily: 'PublicSans',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildReplyQuote(msg, isMe: false),
                            _buildImageAttachment(msg),
                            _buildVoiceAttachment(msg, isMe: false),
                            const SizedBox(height: 4),
                            if (isCallLog)
                              _buildCallLogPill(msg, isMe: false)
                            else if (!hideRedundantImageLabel)
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 13,
                                  color: Color(0xff334155),
                                ),
                              ),
                            if (msg.attachmentType == 'itinerary_card' && widget.chat.itinerary != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: widget.chat.themeColor.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.verified_rounded, color: widget.chat.themeColor, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'TRIP DETAILS: ${widget.chat.name}',
                                            style: TextStyle(
                                              fontFamily: 'PublicSans',
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: widget.chat.themeColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('📅 Dates: ${widget.chat.itinerary!.dates}',
                                        style: const TextStyle(fontFamily: 'PublicSans', fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 3),
                                    Text('🚌 Transport: ${widget.chat.itinerary!.howToReach}',
                                        style: const TextStyle(fontFamily: 'PublicSans', fontSize: 11, color: Colors.black87)),
                                    const SizedBox(height: 3),
                                    Text('📍 Spots: ${widget.chat.itinerary!.placesToVisit.take(2).join(", ")}...',
                                        style: const TextStyle(fontFamily: 'PublicSans', fontSize: 11, color: Colors.black87)),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 34,
                                      child: OutlinedButton(
                                        onPressed: _showItineraryModal,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: widget.chat.themeColor),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Text(
                                          'View Full Trip Roadmap',
                                          style: TextStyle(
                                            fontFamily: 'PublicSans',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: widget.chat.themeColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              msg.time,
                              style: const TextStyle(
                                fontFamily: 'PublicSans',
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (msg.hasHeartReaction)
            Positioned(
              right: msg.isMe ? 8 : null,
              left: msg.isMe ? null : 44,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4),
                  ],
                ),
                child: Text(msg.reactionEmoji, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
