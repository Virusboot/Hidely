import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'creator_profile_screen.dart';
import 'user_profile_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    final result = await ApiService().getLeaderboard();
    if (mounted) {
      if (result.success) {
        setState(() {
          _users = result.data?['leaderboard'] as List? ?? [];
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffE6F4FE), Color(0xffFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    // 1. Custom Premium Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff432C81), width: 20.0, height: 20.0)),
                            ),
                          ),
                          const Text(
                            "Leaderboard",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1C0D5A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          // Filter button on the right
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Filters updated to Global ranking."),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: Color(0xff432C81),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Podium and Rankings List
                    Expanded(
                      child: _users.isEmpty
                          ? const Center(child: Text("No rankings found."))
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                // Podium section (top 3)
                                _buildPodiumSection(),

                                const SizedBox(height: 32),

                                // Discovery Rankings list
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Text(
                                    "DISCOVERY RANKINGS",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff718096),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: _buildRankItemsList(),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    ),);
  }


  Widget _buildPodiumSection() {
    final dynamic rank1User = _users.isNotEmpty ? _users[0] : null;
    final dynamic rank2User = _users.length > 1 ? _users[1] : null;
    final dynamic rank3User = _users.length > 2 ? _users[2] : null;

    return SizedBox(
      height: 220,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 (left)
          if (rank2User != null)
            _buildPodiumItem(
              name: rank2User['username'] ?? rank2User['name'] ?? '',
              points: rank2User['points'] ?? 0,
              rankType: "Gold",
              rank: "2",
              imageUrl: rank2User['profile_picture'] ?? '',
              height: 120,
              isCurrentUser: rank2User['id']?.toString() == AuthService().userId || rank2User['username'] == AuthService().userUsername,
            )
          else
            const SizedBox(width: 90),
          const SizedBox(width: 16),
          // Rank 1 (center)
          if (rank1User != null)
            _buildPodiumItem(
              name: rank1User['username'] ?? rank1User['name'] ?? '',
              points: rank1User['points'] ?? 0,
              rankType: "Diamonds",
              rank: "1",
              imageUrl: rank1User['profile_picture'] ?? '',
              height: 150,
              isFirst: true,
              isCurrentUser: rank1User['id']?.toString() == AuthService().userId || rank1User['username'] == AuthService().userUsername,
            )
          else
            const SizedBox(width: 90),
          const SizedBox(width: 16),
          // Rank 3 (right)
          if (rank3User != null)
            _buildPodiumItem(
              name: rank3User['username'] ?? rank3User['name'] ?? '',
              points: rank3User['points'] ?? 0,
              rankType: "Silver",
              rank: "3",
              imageUrl: rank3User['profile_picture'] ?? '',
              height: 120,
              isCurrentUser: rank3User['id']?.toString() == AuthService().userId || rank3User['username'] == AuthService().userUsername,
            )
          else
            const SizedBox(width: 90),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required String name,
    required int points,
    required String rankType,
    required String rank,
    required String imageUrl,
    required double height,
    bool isFirst = false,
    bool isCurrentUser = false,
  }) {
    final double avatarRadius = isFirst ? 40.0 : 30.0;
    final double avatarBottom = isFirst ? 32.0 : 0.0;

    return GestureDetector(
      onTap: () {
        if (isCurrentUser) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserProfileScreen(isFromLeaderboard: true),
            ),
          ).then((_) => _loadLeaderboardData());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatorProfileScreen(
                username: name,
                avatarPath: imageUrl,
                rank: rankType,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 160.0,
            width: 90,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                if (isFirst)
                  Positioned(
                    top: 0,
                    child: Column(
                      children: [
                        Container(
                          width: 26,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xff432C81),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          child: const Icon(
                            Icons.military_tech,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Positioned(
                    bottom: avatarBottom + 20.0,
                    child: Container(
                      width: 26,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xff432C81),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: avatarBottom,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xff432C81),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: _buildAvatar(imageUrl, avatarRadius, isHighlighted: isCurrentUser),
                        ),
                      ),
                      if (isFirst)
                        Positioned(
                          bottom: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xff432C81),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              "RANK 1",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: -8,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xffE2DCF7),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xff432C81), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                rank,
                                style: const TextStyle(
                                  color: Color(0xff432C81),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isCurrentUser ? "You" : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xff1C0D5A),
              fontSize: isFirst ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "$points XP",
            style: TextStyle(
              color: isFirst ? const Color(0xff432C81) : Colors.black45,
              fontSize: isFirst ? 13 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRankItemsList() {
    final List<Widget> listItems = [];
    if (_users.length <= 3) return listItems;

    for (int i = 3; i < _users.length; i++) {
      final user = _users[i];
      final isCurrentUser = user['id']?.toString() == AuthService().userId || user['username'] == AuthService().userUsername;
      listItems.add(
        _buildRankItem(
          rank: "${i + 1}",
          name: isCurrentUser ? "You (Explorer)" : (user['username'] ?? user['name'] ?? ''),
          level: "Level ${((user['points'] ?? 0) / 450).floor() + 1} Discovery",
          xp: "${user['points'] ?? 0} XP",
          imageUrl: user['profile_picture'] ?? '',
          isHighlighted: isCurrentUser,
          isRising: i == 3,
        ),
      );
    }
    return listItems;
  }

  Widget _buildRankItem({
    required String rank,
    required String name,
    required String level,
    required String xp,
    required String imageUrl,
    bool isHighlighted = false,
    bool isRising = false,
  }) {
    final textColor = isHighlighted ? Colors.white : const Color(0xff1C0D5A);
    final subTextColor = isHighlighted ? Colors.white.withOpacity(0.7) : Colors.black45;

    return GestureDetector(
      onTap: () {
        if (isHighlighted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserProfileScreen(isFromLeaderboard: true),
            ),
          ).then((_) => _loadLeaderboardData());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatorProfileScreen(
                username: name.replaceAll(" (Explorer)", ""),
                avatarPath: imageUrl,
                rank: (int.tryParse(rank) ?? 0) == 1 
                    ? "Diamonds" 
                    : ((int.tryParse(rank) ?? 0) == 2 
                        ? "Gold" 
                        : ((int.tryParse(rank) ?? 0) == 3 
                            ? "Silver" 
                            : "Explorer")),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xff432C81) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: const Color(0xff432C81).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                rank,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighlighted ? Colors.white : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: _buildAvatar(imageUrl, 22, isHighlighted: isHighlighted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  xp,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : const Color(0xff432C81),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRising)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "RISING",
                      style: TextStyle(
                        color: Color(0xffB25E00),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String imagePath, double radius, {bool isHighlighted = false}) {
    final bool isNetwork = imagePath.startsWith("http") || imagePath.startsWith("uploads");
    final bool hasImage = imagePath.isNotEmpty;

    String resolvedUrl = imagePath;
    if (imagePath.startsWith('http')) {
      if (imagePath.contains('localhost') || imagePath.contains('127.0.0.1')) {
        try {
          final uri = Uri.parse(imagePath);
          final baseUri = Uri.parse(ApiService().baseUrl);
          resolvedUrl = uri.replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
          ).toString();
        } catch (_) {}
      }
    } else {
      resolvedUrl = '${ApiService().baseUrl}/${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}';
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: isHighlighted ? const Color(0xff432C81) : const Color(0xffCBD5E1),
      backgroundImage: !hasImage
          ? null
          : (isNetwork
              ? NetworkImage(resolvedUrl)
              : AssetImage(imagePath) as ImageProvider),
      child: !hasImage
          ? Icon(Icons.account_circle, color: isHighlighted ? Colors.white : Colors.white70, size: radius * 1.2)
          : null,
    );
  }
}