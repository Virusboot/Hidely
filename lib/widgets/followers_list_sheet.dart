import 'package:flutter/material.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class FollowersListSheet extends StatefulWidget {
  final String username;
  final String initialTab; // 'followers' or 'following'

  const FollowersListSheet({
    super.key,
    required this.username,
    this.initialTab = 'followers',
  });

  @override
  State<FollowersListSheet> createState() => _FollowersListSheetState();
}

class _FollowersListSheetState extends State<FollowersListSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'following' ? 1 : 0,
    );
    _fetchUsersList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsersList() async {
    setState(() => _isLoading = true);
    final token = AuthService().token ?? '';

    final followersRes = await ApiService().getFollowers(token: token, username: widget.username);
    final followingRes = await ApiService().getFollowing(token: token, username: widget.username);

    if (mounted) {
      setState(() {
        _followers = followersRes.success ? (followersRes.data?['followers'] as List? ?? []) : [];
        _following = followingRes.success ? (followingRes.data?['following'] as List? ?? []) : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(dynamic user) async {
    final token = AuthService().token;
    if (token == null) return;

    final userId = user['id']?.toString() ?? user['username']?.toString() ?? '';
    final bool currentFollow = user['is_following'] == true || user['is_following'] == 1;

    // Optimistic UI update
    setState(() {
      user['is_following'] = !currentFollow;
    });

    final res = await ApiService().toggleFollowCreator(token: token, creatorId: userId);
    if (!res.success && mounted) {
      // Revert if failed
      setState(() {
        user['is_following'] = currentFollow;
      });
    }
  }

  List<dynamic> _getFilteredList(List<dynamic> list) {
    if (_searchFilter.trim().isEmpty) return list;
    final query = _searchFilter.toLowerCase().trim();
    return list.where((u) {
      final uname = u['username']?.toString().toLowerCase() ?? '';
      final name = u['name']?.toString().toLowerCase() ?? '';
      return uname.contains(query) || name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Bar Switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(21),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xff1C0D5A),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xff1C0D5A),
                labelStyle: const TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.bold, fontSize: 13.5),
                unselectedLabelStyle: const TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.w600, fontSize: 13.5),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: "Followers (${_followers.length})"),
                  Tab(text: "Following (${_following.length})"),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchFilter = val);
                  },
                  decoration: const InputDecoration(
                    hintText: "Search accounts...",
                    hintStyle: TextStyle(fontFamily: 'PublicSans', color: Colors.black38, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: Color(0xff1C0D5A), size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontFamily: 'PublicSans', fontSize: 13.5, color: Colors.black87),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Users List View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xff1C0D5A), strokeWidth: 2.5))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUserListView(_getFilteredList(_followers), isFollowersTab: true),
                        _buildUserListView(_getFilteredList(_following), isFollowersTab: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListView(List<dynamic> users, {required bool isFollowersTab}) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              isFollowersTab ? "No Followers Yet" : "Not Following Anyone Yet",
              style: const TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xff1C0D5A),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final u = users[index];
        final uname = u['username']?.toString() ?? 'user';
        final name = u['name']?.toString() ?? uname;
        final avatar = u['profile_picture']?.toString() ?? '';
        final bool isVerified = u['is_verified'] == true || u['is_verified'] == 1;
        final bool isFollowing = u['is_following'] == true || u['is_following'] == 1;
        final bool isSelf = uname.toLowerCase() == AuthService().userUsername.toLowerCase();

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatorProfileScreen(username: uname)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                // Rainbow Gradient Ring Avatar
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xff833AB4), Color(0xffFD1D1D), Color(0xffF56040)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: UserAvatar(
                      avatarUrl: avatar,
                      displayName: uname,
                      radius: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              uname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PublicSans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1C0D5A),
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xff3897F0),
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 12.5,
                          color: Colors.black.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSelf)
                  GestureDetector(
                    onTap: () => _toggleFollow(u),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: isFollowing ? const Color(0xffE2E8F0) : const Color(0xff1C0D5A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isFollowing ? "Following" : "Follow",
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          color: isFollowing ? const Color(0xff1C0D5A) : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
