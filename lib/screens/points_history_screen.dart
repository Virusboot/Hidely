import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/models/gamification_models.dart';
import 'package:hidely_new/services/api_service.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<PointTransaction> _history = [];
  UserPointsProfile? _profile;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex && !_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch both history & user gamification profile
    final historyRes = await ApiService().getPointHistory();
    final profileRes = await ApiService().getUserGamificationProfile();

    if (mounted) {
      List<PointTransaction> fetchedHistory = [];
      if (historyRes.success && historyRes.data != null) {
        fetchedHistory = (historyRes.data?['history'] as List?)
                ?.map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      }

      UserPointsProfile? fetchedProfile;
      if (profileRes.success && profileRes.data != null) {
        try {
          fetchedProfile = UserPointsProfile.fromJson(profileRes.data!);
        } catch (_) {}
      }

      setState(() {
        _history = fetchedHistory;
        _profile = fetchedProfile;
        _isLoading = false;
      });
    }
  }

  Color _getEventColor(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower.contains('hidden_place') || lower.contains('verified') || lower.contains('place')) {
      return const Color(0xff10B981);
    }
    if (lower.contains('camera') || lower.contains('post') || lower.contains('high_accuracy')) {
      return const Color(0xff3B82F6);
    }
    if (lower.contains('level') || lower.contains('badge') || lower.contains('milestone')) {
      return const Color(0xff8B5CF6);
    }
    if (lower.contains('check') || lower.contains('daily') || lower.contains('streak')) {
      return const Color(0xffEF4444);
    }
    return const Color(0xffF59E0B);
  }

  IconData _getEventIcon(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower.contains('hidden_place') || lower.contains('place')) return Icons.place_rounded;
    if (lower.contains('camera') || lower.contains('post')) return Icons.camera_alt_rounded;
    if (lower.contains('accuracy') || lower.contains('verified')) return Icons.gps_fixed_rounded;
    if (lower.contains('level') || lower.contains('badge')) return Icons.emoji_events_rounded;
    if (lower.contains('check') || lower.contains('daily') || lower.contains('streak')) return Icons.local_fire_department_rounded;
    return Icons.stars_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff1C0D5A),
        body: SafeArea(
          bottom: false,
          child: Column(
          children: [
            // --- 1. MODERN TOP APP BAR WITH CUSTOM BACK BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          errorBuilder: (_, __, ___) => const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "Points Activity",
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xffF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xffF59E0B).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xffFBBF24), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "${_profile?.totalPoints ?? 0} pts",
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            color: Color(0xffFBBF24),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. SUMMARY PROFILE BANNER CARD ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff2E1A7D), Color(0xff4323A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xffF59E0B), Color(0xffFBBF24)],
                        ),
                        boxShadow: [
                          BoxShadow(color: const Color(0xffF59E0B).withOpacity(0.4), blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?.levelName ?? "Explorer Level",
                            style: const TextStyle(
                              fontFamily: 'PublicSans',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Level ${_profile?.level ?? 1} • Rank #${_profile?.rank ?? 1}",
                            style: TextStyle(
                              fontFamily: 'PublicSans',
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${_profile?.totalPoints ?? 0}",
                          style: const TextStyle(
                            fontFamily: 'PublicSans',
                            color: Color(0xffFBBF24),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          "Total Points",
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- 3. SMOOTH SLIDING SEGMENTED TAB SWITCHER ---
            _buildSmoothSegmentedTabBar(),

            const SizedBox(height: 12),

            // --- 4. MAIN CURVED BODY SHEET ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xffF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xff1C0D5A), strokeWidth: 2.5))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // TAB 1: ACTIVITY LOG
                            _buildActivityLogTab(),

                            // TAB 2: HOW POINTS WORK (EARN GUIDE)
                            _buildHowPointsWorkTab(),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // --- TAB 1: ACTIVITY LOG ---
  Widget _buildActivityLogTab() {
    if (_history.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xff1C0D5A).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, size: 32, color: Color(0xff1C0D5A)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "No Point Transactions Yet",
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1C0D5A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "You haven't earned points yet. Explore hidden places and post moments using camera to earn points!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'PublicSans', fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xffF59E0B), size: 20),
                SizedBox(width: 6),
                Text(
                  "Ways to earn your first points:",
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xff1C0D5A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRuleCard(
              title: "Share Camera Post",
              points: "+50 pts",
              subtitle: "Capture and upload a post via in-app camera",
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xff3B82F6),
            ),
            const SizedBox(height: 10),
            _buildRuleCard(
              title: "Discover Hidden Place",
              points: "+100 pts",
              subtitle: "Check-in or add a new hidden gem",
              icon: Icons.place_rounded,
              iconColor: const Color(0xff10B981),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tx = _history[index];
        final eventColor = _getEventColor(tx.eventType);
        final iconData = _getEventIcon(tx.eventType);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: eventColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: eventColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1C0D5A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tx.createdAt.length > 10 ? tx.createdAt.substring(0, 10) : tx.createdAt,
                      style: TextStyle(fontFamily: 'PublicSans', fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffBBF7D0)),
                ),
                child: Text(
                  "+${tx.points} pts",
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff166534),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: HOW POINTS WORK (BREAKDOWN & RULES) ---
  Widget _buildHowPointsWorkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xff2563EB), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Earn points by exploring spots and sharing moments. Points boost your Leaderboard Rank & unlock exclusive explorer Badges!",
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12.5,
                    color: Color(0xff1E40AF),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Points Action Breakdown",
          style: TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xff1C0D5A),
          ),
        ),
        const SizedBox(height: 12),

        // Action 1: Camera Post
        _buildRuleCard(
          title: "Share Camera Post",
          points: "+50 pts",
          subtitle: "Take & upload real-time photos/videos using the camera",
          icon: Icons.camera_alt_rounded,
          iconColor: const Color(0xff3B82F6),
        ),
        const SizedBox(height: 10),

        // Action 2: Hidden Place
        _buildRuleCard(
          title: "Explore Hidden Spot",
          points: "+100 pts",
          subtitle: "Discover, visit, and check-in at a verified hidden place",
          icon: Icons.place_rounded,
          iconColor: const Color(0xff10B981),
        ),
        const SizedBox(height: 10),

        // Action 3: Accuracy Verification
        _buildRuleCard(
          title: "GPS Spot Verification",
          points: "+25 pts",
          subtitle: "High accuracy GPS check-in & location verification",
          icon: Icons.gps_fixed_rounded,
          iconColor: const Color(0xffF59E0B),
        ),
        const SizedBox(height: 10),

        // Action 4: Daily Check-In
        _buildRuleCard(
          title: "Daily App Check-In",
          points: "+10 pts",
          subtitle: "Open Hidely and explore posts daily",
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xffEF4444),
        ),
        const SizedBox(height: 10),

        // Action 5: Level Milestone
        _buildRuleCard(
          title: "Level Up Milestone",
          points: "+200 pts",
          subtitle: "Reach new Explorer Levels & rank milestones",
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xff8B5CF6),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRuleCard({
    required String title,
    required String points,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1C0D5A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xffFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffFDE68A)),
            ),
            child: Text(
              points,
              style: const TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xffB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmoothSegmentedTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double tabWidth = (constraints.maxWidth - 6) / 2;
            return Stack(
              children: [
                // Smooth Sliding White Pill Background
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  alignment: _selectedTabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: tabWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Text Labels
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _selectedTabIndex = 0);
                          _tabController.animateTo(0);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 13,
                              fontWeight: _selectedTabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                              color: _selectedTabIndex == 0 ? const Color(0xff1C0D5A) : Colors.white70,
                            ),
                            child: const Text("Activity Log"),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _selectedTabIndex = 1);
                          _tabController.animateTo(1);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'PublicSans',
                              fontSize: 13,
                              fontWeight: _selectedTabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                              color: _selectedTabIndex == 1 ? const Color(0xff1C0D5A) : Colors.white70,
                            ),
                            child: const Text("How Points Work"),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
