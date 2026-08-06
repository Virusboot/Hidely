import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/widgets/empty_state.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String username;
  final int initialTab; // 0 for Followers, 1 for Following
  final bool isMe;

  const FollowListScreen({
    super.key,
    required this.username,
    required this.initialTab,
    required this.isMe,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  List<dynamic> _filteredFollowers = [];
  List<dynamic> _filteredFollowing = [];
  
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  String _searchQuery = "";
  final Map<String, bool> _followingStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      setState(() {
        _searchController.clear();
        _searchQuery = "";
        _applySearch();
      });
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applySearch();
      });
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final token = AuthService().token ?? '';
    
    // 1. Load Following (real data if available, or leaderboard fallback)
    if (widget.isMe) {
      final res = await ApiService().getFollowing(token: token);
      if (res.success) {
        final list = res.data?['following'] as List? ?? [];
        setState(() {
          _following = list;
          _filteredFollowing = list;
          _isLoadingFollowing = false;
          for (var user in list) {
            final uName = user['username']?.toString() ?? '';
            if (uName.isNotEmpty) {
              _followingStatus[uName] = true;
            }
          }
        });
      } else {
        _loadLeaderboardFallback(isFollowingList: true);
      }
    } else {
      _loadLeaderboardFallback(isFollowingList: true);
    }

    // 2. Load Followers (leaderboard fallback since no dedicated followers endpoint exists)
    _loadLeaderboardFallback(isFollowingList: false);
  }

  Future<void> _loadLeaderboardFallback({required bool isFollowingList}) async {
    final res = await ApiService().getLeaderboard();
    if (res.success && mounted) {
      final list = res.data?['rankings'] as List? ?? [];
      final filteredList = list.where((user) {
        final uName = user['username']?.toString() ?? '';
        return uName.isNotEmpty && uName != widget.username;
      }).toList();

      setState(() {
        if (isFollowingList) {
          _following = filteredList;
          _filteredFollowing = filteredList;
          _isLoadingFollowing = false;
          for (var user in filteredList) {
            final uName = user['username']?.toString() ?? '';
            if (uName.isNotEmpty && _followingStatus[uName] == null) {
              _followingStatus[uName] = false;
            }
          }
        } else {
          _followers = filteredList;
          _filteredFollowers = filteredList;
          _isLoadingFollowers = false;
          for (var user in filteredList) {
            final uName = user['username']?.toString() ?? '';
            if (uName.isNotEmpty && _followingStatus[uName] == null) {
              _followingStatus[uName] = false;
            }
          }
        }
      });

      _updateFollowStatuses(filteredList);
    } else {
      setState(() {
        if (isFollowingList) {
          _isLoadingFollowing = false;
        } else {
          _isLoadingFollowers = false;
        }
      });
    }
  }

  void _updateFollowStatuses(List<dynamic> users) {
    final token = AuthService().token;
    if (token == null || token.isEmpty) return;

    for (var user in users) {
      final uName = user['username']?.toString() ?? '';
      if (uName.isEmpty || uName == AuthService().userUsername || _followingStatus[uName] == true) continue;

      ApiService().getCreatorProfile(username: uName, token: token).then((res) {
        if (res.success && mounted) {
          final creator = res.data?['creator'];
          if (creator != null) {
            setState(() {
              _followingStatus[uName] = creator['is_following'] ?? false;
            });
          }
        }
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredFollowers = _followers;
      _filteredFollowing = _following;
      return;
    }

    if (_tabController.index == 0) {
      _filteredFollowers = _followers.where((u) {
        final uName = (u['username'] ?? '').toString().toLowerCase();
        final name = (u['name'] ?? '').toString().toLowerCase();
        return uName.contains(_searchQuery) || name.contains(_searchQuery);
      }).toList();
    } else {
      _filteredFollowing = _following.where((u) {
        final uName = (u['username'] ?? '').toString().toLowerCase();
        final name = (u['name'] ?? '').toString().toLowerCase();
        return uName.contains(_searchQuery) || name.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _toggleFollow(String username, dynamic userId) async {
    if (AuthService().isGuest) return;
    final token = AuthService().token ?? '';

    final result = await ApiService().toggleFollowCreator(token: token, creatorId: userId.toString());
    if (result.success && mounted) {
      setState(() {
        _followingStatus[username] = result.data?['is_following'] ?? !(_followingStatus[username] ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // --- 1. PREMIUM HEADER ROW ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff1C0D5A).withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/back_icon.png',
                              color: const Color(0xff1C0D5A),
                              width: 18.0,
                              height: 18.0,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "@${widget.username}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                // --- 2. GORGEOUS PILL-SHAPED TAB BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xff1C0D5A).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      dividerHeight: 0.0,
                      indicator: BoxDecoration(
                        color: const Color(0xff2B1564), // Solid purple capsule
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff2B1564).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xff1C0D5A).withOpacity(0.6),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: -0.2),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      tabs: [
                        Tab(
                          child: Container(
                            alignment: Alignment.center,
                            child: Text("${_followers.length} Followers"),
                          ),
                        ),
                        Tab(
                          child: Container(
                            alignment: Alignment.center,
                            child: Text("${_following.length} Following"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- 3. PREMIUM SEARCH BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff1C0D5A).withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: "Search creators...",
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 13.5),
                        prefixIcon: Icon(Icons.search, color: Color(0xff2B1564), size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                // --- 4. LIST CONTENT ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(isFollowingTab: false),
                      _buildUserList(isFollowingTab: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList({required bool isFollowingTab}) {
    final isLoading = isFollowingTab ? _isLoadingFollowing : _isLoadingFollowers;
    final list = isFollowingTab ? _filteredFollowing : _filteredFollowers;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xff2B1564),
          strokeWidth: 3,
        ),
      );
    }

    if (list.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.supervised_user_circle_outlined,
        title: _searchQuery.isEmpty ? "No Users Found" : "No Results Found",
        description: _searchQuery.isEmpty 
            ? "There are no users in this list yet." 
            : "We couldn't find any matches for '$_searchQuery'",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 20.0),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final user = list[index];
        final uName = user['username']?.toString() ?? '';
        final name = user['name']?.toString() ?? uName;
        final avatar = user['profile_picture']?.toString();
        final userId = user['id'];
        final isMe = uName == AuthService().userUsername;
        final isFollowing = _followingStatus[uName] ?? false;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff1C0D5A).withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            children: [
              // Avatar with custom frame
              GestureDetector(
                onTap: () => _navigateToProfile(uName, avatar, name),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFollowing ? const Color(0xffE2DCF7) : const Color(0xff2B1564).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: UserAvatar(
                    avatarUrl: avatar,
                    displayName: name,
                    radius: 23,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // User Details
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToProfile(uName, avatar, name),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff1C0D5A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: TextStyle(fontSize: 11.5, color: const Color(0xff1C0D5A).withOpacity(0.5), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Action Button
              if (!isMe)
                SizedBox(
                  height: 32,
                  width: 90,
                  child: OutlinedButton(
                    onPressed: () => _toggleFollow(uName, userId),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isFollowing ? const Color(0xffE2DCF7) : const Color(0xff2B1564),
                      side: BorderSide(color: isFollowing ? const Color(0xff2B1564).withOpacity(0.1) : Colors.transparent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Capsule button
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      isFollowing ? "Following" : "Follow",
                      style: TextStyle(
                        color: isFollowing ? const Color(0xff2B1564) : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToProfile(String username, String? avatar, String displayName) {
    if (username == AuthService().userUsername) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatorProfileScreen(
            username: username,
            avatarPath: avatar != null && avatar.isNotEmpty
                ? (avatar.startsWith('http') ? avatar : '${ApiService().baseUrl}/$avatar')
                : "assets/images/nomad_nate_avatar.png",
            rank: "Gold",
          ),
        ),
      );
    }
  }
}
