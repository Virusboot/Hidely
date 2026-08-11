import 'package:flutter/material.dart';

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final int requiredCount;
  final int currentCount;
  final bool isUnlocked;
  final int points;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.requiredCount,
    required this.currentCount,
    required this.isUnlocked,
    required this.points,
  });

  static List<BadgeModel> getBadgesForUser({
    required int postCount,
    List<dynamic>? posts,
  }) {
    int mountainCount = 0;
    int waterfallCount = 0;
    int heritageCount = 0;
    int totalLikes = 0;

    if (posts != null) {
      for (final p in posts) {
        final category = (p['category'] ?? p['type'] ?? '').toString().toLowerCase();
        final caption = (p['caption'] ?? p['title'] ?? '').toString().toLowerCase();
        final likes = p['likes'] is int ? (p['likes'] as int) : 0;
        totalLikes += likes;

        if (category.contains('mountain') || category.contains('hill') || caption.contains('mountain') || caption.contains('peak') || caption.contains('hill')) {
          mountainCount++;
        }
        if (category.contains('waterfall') || category.contains('river') || caption.contains('waterfall') || caption.contains('falls')) {
          waterfallCount++;
        }
        if (category.contains('fort') || category.contains('heritage') || category.contains('temple') || caption.contains('fort') || caption.contains('palace')) {
          heritageCount++;
        }
      }
    }

    return [
      BadgeModel(
        id: 'hidden_gem_hunter',
        title: 'Hidden Gem Hunter 🥇',
        description: 'Post 10 or more secret unexplored spots across the country.',
        icon: Icons.workspace_premium_rounded,
        primaryColor: const Color(0xffD97706),
        backgroundColor: const Color(0xffFEF3C7),
        requiredCount: 10,
        currentCount: postCount,
        isUnlocked: postCount >= 10,
        points: 500,
      ),
      BadgeModel(
        id: 'mountain_nomad',
        title: 'Mountain Nomad 🌄',
        description: 'Explore and post 5 or more mountain or hill station locations.',
        icon: Icons.terrain_rounded,
        primaryColor: const Color(0xff059669),
        backgroundColor: const Color(0xffD1FAE5),
        requiredCount: 5,
        currentCount: mountainCount > 0 ? mountainCount : (postCount >= 5 ? 5 : postCount),
        isUnlocked: mountainCount >= 5 || postCount >= 5,
        points: 300,
      ),
      BadgeModel(
        id: 'waterfall_explorer',
        title: 'Waterfall Explorer 🌊',
        description: 'Discover and share 3 or more secret waterfall spots.',
        icon: Icons.water_drop_rounded,
        primaryColor: const Color(0xff0284C7),
        backgroundColor: const Color(0xffE0F2FE),
        requiredCount: 3,
        currentCount: waterfallCount > 0 ? waterfallCount : (postCount >= 3 ? 3 : postCount),
        isUnlocked: waterfallCount >= 3 || postCount >= 3,
        points: 200,
      ),
      BadgeModel(
        id: 'heritage_trailblazer',
        title: 'Heritage Trailblazer 🏰',
        description: 'Visit and post 3 or more historic forts or cultural heritage sites.',
        icon: Icons.fort_rounded,
        primaryColor: const Color(0xff7C3AED),
        backgroundColor: const Color(0xffF3E8FF),
        requiredCount: 3,
        currentCount: heritageCount > 0 ? heritageCount : (postCount >= 2 ? 2 : postCount),
        isUnlocked: heritageCount >= 3 || postCount >= 3,
        points: 200,
      ),
      BadgeModel(
        id: 'unexplored_pioneer',
        title: 'Unexplored Pioneer 🗺️',
        description: 'Share your very first hidden spot with the community.',
        icon: Icons.explore_rounded,
        primaryColor: const Color(0xff2563EB),
        backgroundColor: const Color(0xffDBEAFE),
        requiredCount: 1,
        currentCount: postCount > 0 ? 1 : 0,
        isUnlocked: postCount >= 1,
        points: 100,
      ),
      BadgeModel(
        id: 'community_star',
        title: 'Community Star 🌟',
        description: 'Receive 50 or more total likes on your discovered places.',
        icon: Icons.stars_rounded,
        primaryColor: const Color(0xffDB2777),
        backgroundColor: const Color(0xffFCE7F3),
        requiredCount: 50,
        currentCount: totalLikes,
        isUnlocked: totalLikes >= 50 || postCount >= 8,
        points: 400,
      ),
    ];
  }
}

class ExplorerBadge extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;

  const ExplorerBadge({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
  });

  factory ExplorerBadge.fromPostCount(int postCount) {
    if (postCount >= 10) {
      return const ExplorerBadge(
        title: 'Hidden Gem Hunter 🥇',
        icon: Icons.workspace_premium_rounded,
        primaryColor: Color(0xffD97706),
        backgroundColor: Color(0xffFEF3C7),
      );
    } else if (postCount >= 5) {
      return const ExplorerBadge(
        title: 'Mountain Nomad 🌄',
        icon: Icons.terrain_rounded,
        primaryColor: Color(0xff059669),
        backgroundColor: Color(0xffD1FAE5),
      );
    } else if (postCount >= 1) {
      return const ExplorerBadge(
        title: 'Unexplored Pioneer 🗺️',
        icon: Icons.explore_rounded,
        primaryColor: Color(0xff2563EB),
        backgroundColor: Color(0xffDBEAFE),
      );
    }
    return const ExplorerBadge(
      title: 'Novice Wanderer',
      icon: Icons.map_rounded,
      primaryColor: Color(0xff6B7280),
      backgroundColor: Color(0xffF3F4F6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              color: primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'PublicSans',
            ),
          ),
        ],
      ),
    );
  }
}

class ExplorerBadgesRibbon extends StatelessWidget {
  final int postCount;
  final List<dynamic>? posts;

  const ExplorerBadgesRibbon({
    super.key,
    required this.postCount,
    this.posts,
  });

  void _showBadgeDetails(BuildContext context, BadgeModel badge) {
    final double progress = (badge.currentCount / badge.requiredCount).clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: badge.isUnlocked ? badge.backgroundColor : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: badge.isUnlocked ? badge.primaryColor : Colors.grey.shade300,
                  width: 3,
                ),
              ),
              child: Icon(
                badge.isUnlocked ? badge.icon : Icons.lock_rounded,
                size: 36,
                color: badge.isUnlocked ? badge.primaryColor : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              badge.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff1C0D5A),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badge.isUnlocked ? const Color(0xffECFDF5) : const Color(0xffFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge.isUnlocked ? 'Unlocked 🎉 (+${badge.points} XP)' : 'Locked 🔒',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badge.isUnlocked ? const Color(0xff059669) : const Color(0xffDC2626),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xB3000000),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    Text(
                      '${badge.currentCount.clamp(0, badge.requiredCount)} / ${badge.requiredCount}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(badge.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2B1564),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Awesome', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = BadgeModel.getBadgesForUser(postCount: postCount, posts: posts);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: badges.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final b = badges[index];
          return GestureDetector(
            onTap: () => _showBadgeDetails(context, b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: b.isUnlocked ? b.backgroundColor : const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: b.isUnlocked ? b.primaryColor.withOpacity(0.4) : Colors.black12,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    b.isUnlocked ? b.icon : Icons.lock_rounded,
                    size: 14,
                    color: b.isUnlocked ? b.primaryColor : Colors.black45,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    b.title,
                    style: TextStyle(
                      color: b.isUnlocked ? b.primaryColor : Colors.black54,
                      fontSize: 11,
                      fontWeight: b.isUnlocked ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
