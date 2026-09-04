import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidely_new/screens/outgoing_call_screen.dart';

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

/// Chat Item Model (Group Trips + Personal 1-on-1 DMs)
class ChatItem {
  final String id;
  final String? targetUserId;
  final String name;
  final String avatar;
  String lastMessage;
  String time;
  final int unreadCount;
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
  final String id;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String time;
  final bool isMe;
  final String? isHost;
  final String? attachmentType; // 'itinerary_card', 'poll', 'image', 'voice', null
  final Map<String, dynamic>? attachmentData;
  bool hasHeartReaction;

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
    this.hasHeartReaction = false,
  });
}

class GroupChatScreen extends StatefulWidget {
  static final ValueNotifier<bool> isChatRoomOpen = ValueNotifier<bool>(false);
  static dynamic activeState;
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  ChatItem? _activeChat;
  String _selectedFilter = 'All'; // 'All', 'Groups', 'Direct', 'Official'
  final Set<String> _readChatIds = {};

  final Map<String, bool> _onlineStatusMap = {};
  List<dynamic> _searchResultsUsers = [];
  bool _isSearchingUsers = false;
  StreamSubscription? _presenceSub;
  StreamSubscription? _globalMsgSub;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    GroupChatScreen.activeState = this;
    _initChatService();
    _searchController.addListener(_onSearchChanged);
  }

  void _initChatService() {
    final token = AuthService().token;
    if (token != null && token.isNotEmpty) {
      ChatSocketService().connect(token);
    }
    _loadConversations();

    _presenceSub = ChatSocketService().onPresenceUpdate.listen((data) {
      final userIdStr = data['userId']?.toString();
      final status = data['status']?.toString();
      if (userIdStr != null) {
        final bool isOnline = status == 'online';
        if (mounted) {
          setState(() {
            _onlineStatusMap[userIdStr] = isOnline;
            for (int i = 0; i < _allChats.length; i++) {
              if (_allChats[i].targetUserId == userIdStr || _allChats[i].id == userIdStr) {
                _allChats[i].isOnline = isOnline;
              }
            }
          });
        }
      }
    });

    _globalMsgSub = ChatSocketService().onNewMessage.listen((_) {
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    final res = await ApiService().getChatConversations(token: token);
    if (res.success && res.data != null && res.data!['conversations'] != null) {
      final List rawConvs = res.data!['conversations'];
      final currentUserId = AuthService().userId;

      final List<ChatItem> loadedChats = [];
      for (var conv in rawConvs) {
        final convId = conv['id'].toString();
        final isGroup = conv['type'] == 'GROUP';
        final participants = conv['participants'] as List? ?? [];

        Map<String, dynamic>? otherParticipant;
        if (!isGroup && participants.isNotEmpty) {
          for (var p in participants) {
            final pId = p['id']?.toString();
            if (pId != null && pId != currentUserId.toString()) {
              otherParticipant = Map<String, dynamic>.from(p);
              break;
            }
          }
          otherParticipant ??= Map<String, dynamic>.from(participants.first);
        }

        final targetId = otherParticipant?['id']?.toString();
        final name = isGroup
            ? (conv['name'] ?? 'Group Trip')
            : (otherParticipant?['name'] ?? otherParticipant?['username'] ?? 'User');
        final avatar = isGroup
            ? 'assets/images/user1.jpg'
            : (otherParticipant?['profile_picture'] ?? 'assets/images/user1.jpg');

        final bool isOnline = targetId != null
            ? (_onlineStatusMap[targetId] ?? (otherParticipant?['is_online'] == true))
            : false;

        final lastMsgObj = conv['last_message'];
        final lastMsgText = lastMsgObj != null ? (lastMsgObj['text'] ?? 'Sent an attachment') : 'No messages yet';
        final rawTime = lastMsgObj != null ? lastMsgObj['created_at']?.toString() : conv['updated_at']?.toString();
        final formattedTime = rawTime != null && rawTime.length >= 16 ? rawTime.substring(11, 16) : '';

        loadedChats.add(ChatItem(
          id: convId,
          targetUserId: targetId,
          name: name,
          avatar: avatar,
          lastMessage: lastMsgText,
          time: formattedTime,
          unreadCount: conv['unread_count'] ?? 0,
          isGroup: isGroup,
          isOnline: isOnline,
        ));
      }

      if (mounted) {
        setState(() {
          _allChats.clear();
          _allChats.addAll(loadedChats);
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
      final res = await ApiService().searchUsers(query: query);
      if (mounted) {
        setState(() {
          _isSearchingUsers = false;
          if (res.success && res.data != null && res.data!['users'] != null) {
            _searchResultsUsers = res.data!['users'];
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

  void openDirectChat(ChatItem chat) {
    clearSearch();
    final exists = _allChats.any((c) => c.id == chat.id);
    if (!exists) {
      setState(() {
        _allChats.insert(0, chat);
      });
    } else {
      final existingChatIndex = _allChats.indexWhere((c) => c.id == chat.id);
      if (existingChatIndex > 0) {
        final existingChat = _allChats.removeAt(existingChatIndex);
        setState(() {
          _allChats.insert(0, existingChat);
        });
      }
    }
    _openChat(_allChats.firstWhere((c) => c.id == chat.id));
  }

  void _openChat(ChatItem chat) {
    clearSearch();
    setState(() {
      _readChatIds.add(chat.id);
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
    if (_readChatIds.contains(chat.id)) return false;
    return chat.unreadCount > 0;
  }

  // Real-time Chat List Stream (Clean & Production Ready)
  static final List<ChatItem> _allChats = [];

  @override
  void dispose() {
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
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
              TextField(
                controller: userSearchCtrl,
                onChanged: (val) async {
                  if (val.trim().length >= 2) {
                    setModalState(() => isLoading = true);
                    final res = await ApiService().searchUsers(query: val.trim());
                    setModalState(() {
                      isLoading = false;
                      if (res.success && res.data != null && res.data!['users'] != null) {
                        usersList = res.data!['users'];
                      }
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search username or name...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xff1C0D5A)),
                  filled: true,
                  fillColor: const Color(0xffF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(u['profile_picture'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80'),
                                ),
                                title: Text(u['name'] ?? u['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('@${u['username'] ?? ''}'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final token = AuthService().token;
                                  if (token != null) {
                                    final res = await ApiService().getOrCreateDirectChat(token: token, targetUserId: u['id']);
                                    if (res.success && res.data != null && res.data!['conversationId'] != null) {
                                      final convId = res.data!['conversationId'].toString();
                                      final newDirectChat = ChatItem(
                                        id: convId,
                                        name: u['name'] ?? u['username'] ?? 'User',
                                        avatar: u['profile_picture'] ?? 'assets/images/user1.jpg',
                                        lastMessage: 'Tap to send a message...',
                                        time: 'Just now',
                                        unreadCount: 0,
                                        isGroup: false,
                                      );
                                      openDirectChat(newDirectChat);
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
        titleSpacing: 16,
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
            final matchesQuery = t.name.toLowerCase().contains(query) ||
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
        height: 48,
        width: double.infinity,
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
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search messages, groups, or travelers...',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xff1C0D5A), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Colors.black38, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
      final username = u['username']?.toString().toLowerCase();

      final alreadyInChats = _allChats.any((chat) {
        if (chat.targetUserId != null && uId != null && chat.targetUserId == uId) {
          return true;
        }
        if (name != null && name.isNotEmpty && chat.name.toLowerCase() == name) {
          return true;
        }
        if (username != null && username.isNotEmpty && chat.name.toLowerCase() == username) {
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

            return ListTile(
              leading: Stack(
                children: [
                  UserAvatar(
                    avatarUrl: u['profile_picture'],
                    displayName: u['name'] ?? u['username'] ?? 'User',
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
                u['name'] ?? u['username'] ?? 'User',
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
                if (token != null) {
                  final res = await ApiService().getOrCreateDirectChat(token: token, targetUserId: u['id']);
                  if (res.success && res.data != null && res.data!['conversationId'] != null) {
                    final convId = res.data!['conversationId'].toString();
                    final newDirectChat = ChatItem(
                      id: convId,
                      targetUserId: u['id']?.toString(),
                      name: u['name'] ?? u['username'] ?? 'User',
                      avatar: u['profile_picture'] ?? 'assets/images/user1.jpg',
                      lastMessage: 'Tap to send a message...',
                      time: 'Just now',
                      unreadCount: 0,
                      isGroup: false,
                      isOnline: isOnline,
                    );
                    openDirectChat(newDirectChat);
                  }
                }
              },
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

    return ListView.builder(
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
                    ClipOval(
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.network(
                          chat.avatar,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                        ),
                      ),
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
                              '${chat.lastMessage}  •  ${chat.time}',
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
  late List<ChatMessage> _messages;
  bool _isRecording = false;
  bool _isLoadingMessages = true;
  String? _playingVoiceMsgId;

  static final Map<String, List<ChatMessage>> _messagesHistory = {};


  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _presenceSub;
  bool _isOtherUserTyping = false;
  late bool _isTargetOnline;

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
  }

  void _loadRealMessages() async {
    final token = AuthService().token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoadingMessages = false);
      return;
    }

    ChatSocketService().connect(token);

    final int? convId = int.tryParse(widget.chat.id);
    if (convId != null) {
      ChatSocketService().joinConversation(convId);

      final res = await ApiService().getChatMessages(token: token, conversationId: convId);
      if (res.success && res.data != null && res.data!['messages'] != null) {
        final List rawMsgs = res.data!['messages'];
        final currentUserId = AuthService().userId;

        final loadedMsgs = rawMsgs.map((m) {
          final senderId = m['sender_id'];
          final isMe = (senderId != null && senderId.toString() == currentUserId.toString());
          return ChatMessage(
            id: m['id'].toString(),
            senderName: isMe ? 'You' : (m['sender_name'] ?? 'User'),
            senderAvatar: m['sender_profile_picture'] ?? 'assets/images/user1.jpg',
            text: m['text'] ?? '',
            time: m['created_at'] != null && m['created_at'].toString().length >= 16 ? m['created_at'].toString().substring(11, 16) : 'Just now',
            isMe: isMe,
            attachmentType: m['type'] != 'text' ? m['type'] : null,
            attachmentData: m['attachments'] != null && (m['attachments'] as List).isNotEmpty
                ? {'url': m['attachments'][0]['url']}
                : (m['shared_entity_type'] != null
                    ? {'type': m['shared_entity_type'], 'id': m['shared_entity_id']}
                    : null),
          );
        }).toList();

        _messagesHistory[widget.chat.id] = loadedMsgs;

        if (mounted) {
          setState(() {
            _messages = loadedMsgs;
            _isLoadingMessages = false;
          });
        }

        ApiService().markChatConversationAsRead(token: token, conversationId: convId);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMessages = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  void _setupSocketListeners() {
    _msgSub = ChatSocketService().onNewMessage.listen((data) {
      final int? convId = int.tryParse(widget.chat.id);
      if (data['conversation_id'] == convId) {
        final senderId = data['sender_id'];
        final currentUserId = AuthService().userId;
        final isMe = (senderId != null && senderId.toString() == currentUserId.toString());

        if (!isMe) {
          setState(() {
            _messages.add(
              ChatMessage(
                id: data['id'].toString(),
                senderName: data['sender_name'] ?? 'User',
                senderAvatar: data['sender_profile_picture'] ?? 'assets/images/user1.jpg',
                text: data['text'] ?? '',
                time: 'Just now',
                isMe: false,
                attachmentType: data['type'] != 'text' ? data['type'] : null,
                attachmentData: data['attachments'] != null && (data['attachments'] as List).isNotEmpty
                    ? {'url': data['attachments'][0]['url']}
                    : null,
              ),
            );
          });

          if (convId != null) {
            final token = AuthService().token;
            if (token != null) {
              ApiService().markChatConversationAsRead(token: token, conversationId: convId);
            }
          }
        }
      }
    });

    _typingSub = ChatSocketService().onTypingStatus.listen((data) {
      final int? convId = int.tryParse(widget.chat.id);
      if (data['conversationId'] == convId) {
        setState(() {
          _isOtherUserTyping = data['isTyping'] ?? false;
        });
      }
    });

    _presenceSub = ChatSocketService().onPresenceUpdate.listen((data) {
      final userIdStr = data['userId']?.toString();
      final status = data['status']?.toString();
      if (userIdStr != null &&
          (userIdStr == widget.chat.targetUserId || userIdStr == widget.chat.id)) {
        final bool isOnline = status == 'online';
        if (mounted) {
          setState(() {
            _isTargetOnline = isOnline;
            widget.chat.isOnline = isOnline;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    final int? convId = int.tryParse(widget.chat.id);
    if (convId != null) {
      ChatSocketService().leaveConversation(convId);
    }
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    final now = TimeOfDay.now();
    final timeStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add(
        ChatMessage(
          id: tempId,
          senderName: 'You',
          senderAvatar: AuthService().userProfilePicture.isNotEmpty ? AuthService().userProfilePicture : 'assets/images/user1.jpg',
          text: text,
          time: timeStr,
          isMe: true,
        ),
      );
      widget.chat.lastMessage = 'You: $text';
      widget.chat.time = timeStr;
    });

    HapticFeedback.lightImpact();

    final int? convId = int.tryParse(widget.chat.id);
    final token = AuthService().token;

    if (convId != null && token != null && token.isNotEmpty) {
      ChatSocketService().stopTyping(convId);
      await ApiService().sendChatMessage(
        token: token,
        conversationId: convId,
        type: 'text',
        text: text,
      );
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

  void _showCallingDialog(bool isVideo) {
    final callText = isVideo ? '📹 Started a video call' : '📞 Started a voice call';
    final now = TimeOfDay.now();
    final timeStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: 'You',
          senderAvatar: AuthService().userProfilePicture.isNotEmpty ? AuthService().userProfilePicture : 'assets/images/user1.jpg',
          text: callText,
          time: timeStr,
          isMe: true,
        ),
      );
      widget.chat.lastMessage = 'You: $callText';
      widget.chat.time = timeStr;
    });

    final int? convId = int.tryParse(widget.chat.id);
    final token = AuthService().token;
    if (convId != null && token != null && token.isNotEmpty) {
      ApiService().sendChatMessage(
        token: token,
        conversationId: convId,
        type: 'text',
        text: callText,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutgoingCallScreen(
          callerName: widget.chat.name,
          callerAvatar: widget.chat.avatar,
          callID: widget.chat.id,
          isVideo: isVideo,
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        final now = TimeOfDay.now();
        final timeStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();

        final localMsg = ChatMessage(
          id: tempId,
          senderName: AuthService().userName.isNotEmpty ? AuthService().userName : 'You',
          senderAvatar: AuthService().userProfilePicture.isNotEmpty ? AuthService().userProfilePicture : 'assets/images/user1.jpg',
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

        HapticFeedback.lightImpact();

        final int? convId = int.tryParse(widget.chat.id);
        final token = AuthService().token;
        if (convId != null && token != null && token.isNotEmpty) {
          final res = await ApiService().sendChatMessage(
            token: token,
            conversationId: convId,
            type: 'image',
            text: 'Sent an image 🏞️',
            mediaFile: File(pickedFile.path),
          );
          if (res.success && res.data != null && res.data!['message'] != null) {
            final serverMsg = res.data!['message'];
            final attachments = serverMsg['attachments'] as List? ?? [];
            if (attachments.isNotEmpty && mounted) {
              setState(() {
                localMsg.attachmentData?['imageUrl'] = attachments[0]['url'];
                localMsg.attachmentData?['url'] = attachments[0]['url'];
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _sendVoiceNote() async {
    final now = TimeOfDay.now();
    final timeStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final localMsg = ChatMessage(
      id: tempId,
      senderName: AuthService().userName.isNotEmpty ? AuthService().userName : 'You',
      senderAvatar: AuthService().userProfilePicture.isNotEmpty ? AuthService().userProfilePicture : 'assets/images/user1.jpg',
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

    HapticFeedback.lightImpact();

    final int? convId = int.tryParse(widget.chat.id);
    final token = AuthService().token;
    if (convId != null && token != null && token.isNotEmpty) {
      await ApiService().sendChatMessage(
        token: token,
        conversationId: convId,
        type: 'voice',
        text: 'Voice note (0:05)',
      );
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
                child: localPath != null && localPath.isNotEmpty && File(localPath).existsSync()
                    ? Image.file(File(localPath), fit: BoxFit.contain)
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

  void _toggleHeartReaction(ChatMessage msg) {
    setState(() {
      msg.hasHeartReaction = !(msg.hasHeartReaction);
    });
    HapticFeedback.mediumImpact();
  }

  void _showMessageOptionsSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                      _toggleHeartReaction(msg);
                      Navigator.pop(ctx);
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
                onTap: () => Navigator.pop(ctx),
              ),
            ],
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
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xff1C0D5A)),
          onPressed: widget.onBack,
        ),
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: Image.network(
                  widget.chat.avatar,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (ctx, err, stack) => Container(
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.person, color: Colors.grey, size: 18),
                  ),
                ),
              ),
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  widget.chat.avatar,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (ctx, err, stack) => Icon(
                                    widget.chat.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                    size: 40,
                                    color: widget.chat.themeColor,
                                  ),
                                ),
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
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
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
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _msgController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontFamily: 'PublicSans', fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: _isRecording ? 'Recording voice note...' : 'Message...',
                            hintStyle: TextStyle(color: _isRecording ? Colors.red : Colors.black38, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_msgController.text.trim().isNotEmpty)
                      GestureDetector(
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

    if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
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

  Widget _buildMessageBubble(ChatMessage msg) {
    return GestureDetector(
      onDoubleTap: () => _toggleHeartReaction(msg),
      onLongPress: () => _showMessageOptionsSheet(msg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (msg.isMe)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                    _buildImageAttachment(msg),
                    _buildVoiceAttachment(msg, isMe: true),
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
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Image.network(
                          msg.senderAvatar,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, color: Colors.grey, size: 16),
                          ),
                        ),
                      ),
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
                            _buildImageAttachment(msg),
                            _buildVoiceAttachment(msg, isMe: false),
                            const SizedBox(height: 4),
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
                child: const Text('❤️', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
