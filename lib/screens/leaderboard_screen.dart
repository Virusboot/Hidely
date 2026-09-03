import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/models/gamification_models.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'user_profile_screen.dart';
import 'points_history_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _selectedPeriod = 'all_time';
  List<LeaderboardUser> _users = [];
  LeaderboardUser? _currentUserRank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final periods = ['weekly', 'monthly', 'all_time'];
        setState(() {
          _selectedPeriod = periods[_tabController.index];
          _isLoading = true;
        });
        _loadLeaderboardData();
      }
    });
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboardData() async {
    final result = await ApiService().getLeaderboard(period: _selectedPeriod);
    if (mounted) {
      if (result.success) {
        final rawList = result.data?['leaderboard'] as List? ?? [];
        final parsedUsers = rawList.asMap().entries.map((entry) {
          return LeaderboardUser.fromJson(entry.value as Map<String, dynamic>, entry.key + 1);
        }).toList();

        final currentUserIdStr = AuthService().userId;
        LeaderboardUser? myRank;
        if (currentUserIdStr != null) {
          final myId = int.tryParse(currentUserIdStr);
          if (myId != null) {
            myRank = parsedUsers.firstWhere(
              (u) => u.id == myId,
              orElse: () => LeaderboardUser(
                rank: parsedUsers.length + 1,
                id: myId,
                name: AuthService().userName ?? 'You',
                username: AuthService().userUsername ?? 'me',
                profilePicture: AuthService().userProfilePicture,
                points: 0,
                level: 1,
                levelName: 'New Explorer',
              ),
            );
          }
        }

        setState(() {
          _users = parsedUsers;
          _currentUserRank = myRank;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top1 = _users.isNotEmpty ? _users[0] : null;
    final top2 = _users.length > 1 ? _users[1] : null;
    final top3 = _users.length > 2 ? _users[2] : null;
    final restUsers = _users.length > 3 ? _users.sublist(3) : <LeaderboardUser>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff1C0D5A),
        appBar: AppBar(
          backgroundColor: const Color(0xff1C0D5A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Leaderboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              tooltip: "Points Activity",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsHistoryScreen()));
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xffFFB800),
            indicatorWeight: 3,
            labelColor: const Color(0xffFFB800),
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: "Weekly"),
              Tab(text: "Monthly"),
              Tab(text: "All Time"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xffFFB800)))
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadLeaderboardData,
                    color: const Color(0xff2B1564),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // 1. Top 3 Podium Section
                          if (_users.isNotEmpty) _buildTopPodium(top1, top2, top3),
                          const SizedBox(height: 24),

                          // 2. Ranked Users List Container
                          Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height * 0.5,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xffF8FAFC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 90),
                            child: restUsers.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text(
                                        "No other explorers ranked yet.",
                                        style: TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: restUsers.length,
                                    separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xffF1F5F9)),
                                    itemBuilder: (context, idx) {
                                      final user = restUsers[idx];
                                      return _buildUserTile(user);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Current User Rank Card
                  if (_currentUserRank != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildStickyMyRankCard(_currentUserRank!),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopPodium(LeaderboardUser? top1, LeaderboardUser? top2, LeaderboardUser? top3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Left)
          if (top2 != null) Expanded(child: _buildPodiumSlot(top2, 2, 130, const Color(0xffC0C0C0))),
          // 1st Place (Center - Highest)
          if (top1 != null) Expanded(child: _buildPodiumSlot(top1, 1, 160, const Color(0xffFFD700))),
          // 3rd Place (Right)
          if (top3 != null) Expanded(child: _buildPodiumSlot(top3, 3, 110, const Color(0xffCD7F32))),
        ],
      ),
    );
  }

  Widget _buildPodiumSlot(LeaderboardUser user, int rank, double height, Color crownColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen(isFromLeaderboard: true)),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown/Medal Badge
          Icon(
            rank == 1 ? Icons.workspace_premium_rounded : Icons.military_tech_rounded,
            color: crownColor,
            size: rank == 1 ? 32 : 26,
          ),
          const SizedBox(height: 4),

          // Avatar Box
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(rank == 1 ? 3 : 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: crownColor, width: rank == 1 ? 3 : 2),
                  boxShadow: [
                    BoxShadow(color: crownColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
                  ],
                ),
                child: UserAvatar(
                  avatarUrl: user.profilePicture,
                  displayName: user.name,
                  radius: rank == 1 ? 34 : 28,
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: crownColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "#$rank",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),

          // Points
          Text(
            "${user.points} pts",
            style: TextStyle(color: crownColor, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(LeaderboardUser user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen(isFromLeaderboard: true)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 32,
              child: Text(
                "#${user.rank}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xff1C0D5A)),
              ),
            ),
            const SizedBox(width: 8),

            // Avatar
            UserAvatar(avatarUrl: user.profilePicture, displayName: user.name, radius: 22),
            const SizedBox(width: 12),

            // Name & Level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xff1C0D5A)),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 15, color: Color(0xff3B82F6)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xff2B1564).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Lvl ${user.level} · ${user.levelName}",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff2B1564)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Points & Rank Movement
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${user.points} pts",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xff2B1564)),
                ),
                const SizedBox(height: 2),
                Text(
                  user.rankChange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: user.rankChange.startsWith('↑') ? const Color(0xff10B981) : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyMyRankCard(LeaderboardUser myRank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff2B1564),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xffFFB800),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "#${myRank.rank}",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
            ),
          ),
          const SizedBox(width: 12),
          UserAvatar(avatarUrl: myRank.profilePicture, displayName: myRank.name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Your Current Rank",
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  "${myRank.points} Points · Lvl ${myRank.level}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
        ],
      ),
    );
  }
}