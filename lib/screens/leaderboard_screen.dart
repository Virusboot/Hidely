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

        final myId = int.tryParse(AuthService().userId);
        LeaderboardUser? myRank;
        if (myId != null) {
          myRank = parsedUsers.firstWhere(
            (u) => u.id == myId,
            orElse: () => LeaderboardUser(
              rank: parsedUsers.length + 1,
              id: myId,
              name: AuthService().userName,
              username: AuthService().userUsername,
              profilePicture: AuthService().userProfilePicture,
              points: 0,
              level: 1,
              levelName: 'New Explorer',
            ),
          );
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xff1C0D5A),
                Color(0xff2B1564),
                Color(0xff1E1B4B),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // --- 1. HERO TOP HEADER ROW ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/back_icon.png',
                                  color: Colors.white,
                                  width: 16.0,
                                  height: 16.0,
                                ),
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              "Leaderboard",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                fontFamily: 'PublicSans',
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsHistoryScreen()));
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.history_rounded,
                                  color: Colors.white,
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 2. FLOATING HERO SEGMENTED TAB BAR ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            _buildHeroSegmentedTab('Weekly', 0),
                            _buildHeroSegmentedTab('Monthly', 1),
                            _buildHeroSegmentedTab('All Time', 2),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // --- 3. UNIFIED 3D PODIUM STAGE ---
                    if (_users.isNotEmpty) _buildUnified3DPodium(top1, top2, top3),

                    const SizedBox(height: 12),

                    // --- 4. CURVED WHITE BODY FOR REST OF RANKINGS ---
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xffF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xff2563EB), strokeWidth: 2.5))
                              : RefreshIndicator(
                                  onRefresh: _loadLeaderboardData,
                                  color: const Color(0xff2563EB),
                                  child: restUsers.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "No other explorers ranked yet.",
                                            style: TextStyle(color: Colors.black45, fontSize: 14, fontFamily: 'PublicSans'),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 95),
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: restUsers.length,
                                          itemBuilder: (context, idx) {
                                            final user = restUsers[idx];
                                            return _buildUserTile(user);
                                          },
                                        ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                // --- 5. STICKY BOTTOM CURRENT USER RANK CARD ---
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
        ),
      ),
    );
  }

  Widget _buildHeroSegmentedTab(String label, int index) {
    final bool isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xff1C0D5A) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnified3DPodium(LeaderboardUser? top1, LeaderboardUser? top2, LeaderboardUser? top3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 235,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place (Left - Silver)
            if (top2 != null)
              Expanded(
                child: _buildPodiumColumn(
                  user: top2,
                  rank: 2,
                  pedestalHeight: 76,
                  auraColor: const Color(0xffCBD5E1),
                  badgeEmoji: '🥈',
                  pedestalGradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff475569), Color(0xff1E293B)],
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // 1st Place (Center - Gold)
            if (top1 != null)
              Expanded(
                child: _buildPodiumColumn(
                  user: top1,
                  rank: 1,
                  pedestalHeight: 100,
                  auraColor: const Color(0xffF59E0B),
                  badgeEmoji: '👑',
                  isFirst: true,
                  pedestalGradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xffD97706), Color(0xffB45309)],
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // 3rd Place (Right - Bronze)
            if (top3 != null)
              Expanded(
                child: _buildPodiumColumn(
                  user: top3,
                  rank: 3,
                  pedestalHeight: 64,
                  auraColor: const Color(0xffD97706),
                  badgeEmoji: '🥉',
                  pedestalGradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff78350F), Color(0xff451A03)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumColumn({
    required LeaderboardUser user,
    required int rank,
    required double pedestalHeight,
    required Color auraColor,
    required String badgeEmoji,
    required LinearGradient pedestalGradient,
    bool isFirst = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen(isFromLeaderboard: true)),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Emoji Crown/Badge
          Text(badgeEmoji, style: TextStyle(fontSize: isFirst ? 26 : 20)),
          const SizedBox(height: 2),

          // Avatar Box with Aura Ring
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(isFirst ? 3.5 : 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isFirst
                        ? [const Color(0xffF59E0B), const Color(0xffFBBF24)]
                        : [auraColor, auraColor.withOpacity(0.6)],
                  ),
                  boxShadow: [
                    BoxShadow(color: auraColor.withOpacity(0.5), blurRadius: isFirst ? 16 : 8, spreadRadius: isFirst ? 2 : 1),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: UserAvatar(
                    avatarUrl: user.profilePicture,
                    displayName: user.name,
                    radius: isFirst ? 34 : 26,
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isFirst ? const Color(0xffF59E0B) : auraColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    "#$rank",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3D Pedestal Stand
          Container(
            height: pedestalHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              gradient: pedestalGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PublicSans',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${user.points} pts",
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          color: isFirst ? const Color(0xffFBBF24) : Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
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

  Widget _buildUserTile(LeaderboardUser user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserProfileScreen(isFromLeaderboard: true)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // Rank Badge
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "#${user.rank}",
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff1C0D5A),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              UserAvatar(avatarUrl: user.profilePicture, displayName: user.name, radius: 21),
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
                            style: const TextStyle(
                              fontFamily: 'PublicSans',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xff1C0D5A),
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 15, color: Color(0xff2563EB)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Lvl ${user.level} · ${user.levelName}",
                        style: const TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff2563EB),
                        ),
                      ),
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
                    style: const TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff1C0D5A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.rankChange,
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: user.rankChange.startsWith('↑') ? const Color(0xff10B981) : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyMyRankCard(LeaderboardUser myRank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2B1564), Color(0xff1C0D5A)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2B1564).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xffF59E0B),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: const Color(0xffF59E0B).withOpacity(0.4), blurRadius: 6),
              ],
            ),
            child: Text(
              "#${myRank.rank}",
              style: const TextStyle(
                fontFamily: 'PublicSans',
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white,
              ),
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
                  style: TextStyle(fontFamily: 'PublicSans', color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  "${myRank.points} Points · Lvl ${myRank.level}",
                  style: const TextStyle(fontFamily: 'PublicSans', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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