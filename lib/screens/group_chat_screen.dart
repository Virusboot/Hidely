import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/empty_state.dart';

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
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;
  final bool isOfficial;
  final bool isOnline;
  final String? destination;
  final int? memberCount;
  final String? status;
  final Color themeColor;
  final List<String>? memberAvatars;
  final TripItineraryData? itinerary;

  const ChatItem({
    required this.id,
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

  @override
  void initState() {
    super.initState();
    GroupChatScreen.activeState = this;
  }

  void openDirectChat(ChatItem chat) {
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
    setState(() {
      _readChatIds.add(chat.id);
      _activeChat = chat;
      GroupChatScreen.isChatRoomOpen.value = true;
    });
  }

  void _closeChat() {
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
  final List<ChatItem> _allChats = [];

  @override
  void dispose() {
    if (GroupChatScreen.activeState == this) {
      GroupChatScreen.activeState = null;
    }
    _searchController.dispose();
    super.dispose();
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
        onPopInvoked: (didPop) {
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
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
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff1C0D5A), size: 20),
          ],
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
            tooltip: 'Create Group Trip Squad',
            onPressed: _createNewGroupTripDialog,
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
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, top: 6.0, bottom: 8.0),
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

  Widget _buildChatListSection({required List<ChatItem> items, required String emptyMessage}) {
    if (items.isEmpty) {
      return Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: Center(
              child: EmptyStateWidget(
                icon: Icons.send_rounded,
                title: 'No Messages Yet',
                description: emptyMessage,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSearchAndFilterBar();
        }
        final chat = items[index - 1];
        final bool hasUnread = _isUnread(chat);

        return GestureDetector(
          onTap: () => _openChat(chat),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                // Avatar with online status dot
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: NetworkImage(chat.avatar),
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
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: 'You',
          senderAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
          text: text,
          time: 'Just now',
          isMe: true,
        ),
      );
      _msgController.clear();
    });
    HapticFeedback.lightImpact();
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
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(widget.chat.avatar),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.chat.name,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff1C0D5A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isVideo ? 'Starting Video Call... 📹' : 'Ringing... 📞',
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.red[600],
                      child: IconButton(
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendPhotoAttachment() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: 'You',
          senderAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
          text: 'Shared a photo from Nainital lake view 🏞️',
          time: 'Just now',
          isMe: true,
          attachmentType: 'image',
          attachmentData: {
            'imageUrl': 'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=600&q=80',
          },
        ),
      );
    });
    HapticFeedback.lightImpact();
  }

  void _sendVoiceNote() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: 'You',
          senderAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
          text: 'Voice note (0:14)',
          time: 'Just now',
          isMe: true,
          attachmentType: 'voice',
        ),
      );
    });
    HapticFeedback.lightImpact();
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
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.chat.avatar),
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
                    widget.chat.isGroup
                        ? '${widget.chat.memberCount ?? 1} Travelers • ${widget.chat.destination ?? ''}'
                        : widget.chat.isOnline
                            ? 'Active Now 🟢'
                            : 'Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.chat.themeColor,
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
            child: ListView.builder(
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
                      onPressed: _sendPhotoAttachment,
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Color(0xff2B1564), size: 22),
                      onPressed: _sendPhotoAttachment,
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
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      IconButton(
                        icon: const Icon(Icons.mic_none_outlined, color: Color(0xff2B1564), size: 23),
                        onPressed: _sendVoiceNote,
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
                    if (msg.attachmentType == 'image' && msg.attachmentData?['imageUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          msg.attachmentData!['imageUrl'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (msg.attachmentType == 'voice') ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 6),
                          Container(
                            width: 100,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('0:14', style: TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
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
                        fontSize: 10,
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
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(msg.senderAvatar),
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
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
                                fontSize: 10,
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
