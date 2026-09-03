class BadgeModel {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String category;
  final String icon;
  final String rarity;
  final int tier;
  final int rewardPoints;
  final bool isEarned;
  final String? earnedAt;
  final bool isFeatured;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    required this.icon,
    required this.rarity,
    this.tier = 1,
    this.rewardPoints = 0,
    this.isEarned = false,
    this.earnedAt,
    this.isFeatured = false,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Badge',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      icon: json['icon']?.toString() ?? 'compass',
      rarity: json['rarity']?.toString() ?? 'COMMON',
      tier: json['tier'] is int ? json['tier'] : int.tryParse(json['tier']?.toString() ?? '1') ?? 1,
      rewardPoints: json['reward_points'] is int ? json['reward_points'] : int.tryParse(json['reward_points']?.toString() ?? '0') ?? 0,
      isEarned: json['is_earned'] == true || json['is_earned'] == 1,
      earnedAt: json['earned_at']?.toString(),
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
    );
  }
}

class LeaderboardUser {
  final int rank;
  final int id;
  final String name;
  final String username;
  final String? profilePicture;
  final bool isVerified;
  final int points;
  final int level;
  final String levelName;
  final String rankChange;
  final BadgeModel? featuredBadge;

  const LeaderboardUser({
    required this.rank,
    required this.id,
    required this.name,
    required this.username,
    this.profilePicture,
    this.isVerified = false,
    required this.points,
    required this.level,
    required this.levelName,
    this.rankChange = '—',
    this.featuredBadge,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json, int defaultRank) {
    return LeaderboardUser(
      rank: json['rank'] is int ? json['rank'] : int.tryParse(json['rank']?.toString() ?? '$defaultRank') ?? defaultRank,
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Explorer',
      username: json['username']?.toString() ?? 'user',
      profilePicture: json['profile_picture']?.toString(),
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      points: json['points'] is int ? json['points'] : int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      level: json['level'] is int ? json['level'] : int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      levelName: json['levelName']?.toString() ?? 'New Explorer',
      rankChange: json['rank_change']?.toString() ?? '—',
      featuredBadge: json['featured_badge'] != null && json['featured_badge'] is Map<String, dynamic>
          ? BadgeModel.fromJson(json['featured_badge'])
          : null,
    );
  }
}

class PointTransaction {
  final int id;
  final String eventType;
  final int points;
  final String? referenceType;
  final String? referenceId;
  final String description;
  final String createdAt;

  const PointTransaction({
    required this.id,
    required this.eventType,
    required this.points,
    this.referenceType,
    this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      eventType: json['event_type']?.toString() ?? 'general',
      points: json['points'] is int ? json['points'] : int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      description: json['description']?.toString() ?? 'Points activity',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class UserPointsProfile {
  final int userId;
  final String name;
  final String username;
  final String? profilePicture;
  final int totalPoints;
  final int level;
  final String levelName;
  final int minXp;
  final int nextLevelMinXp;
  final int rank;
  final BadgeModel? featuredBadge;
  final List<BadgeModel> badges;

  const UserPointsProfile({
    required this.userId,
    required this.name,
    required this.username,
    this.profilePicture,
    required this.totalPoints,
    required this.level,
    required this.levelName,
    required this.minXp,
    required this.nextLevelMinXp,
    required this.rank,
    this.featuredBadge,
    this.badges = const [],
  });

  factory UserPointsProfile.fromJson(Map<String, dynamic> json) {
    final bList = (json['badges'] as List?)
            ?.map((e) => BadgeModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return UserPointsProfile(
      userId: json['userId'] is int ? json['userId'] : int.tryParse(json['userId']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Explorer',
      username: json['username']?.toString() ?? 'user',
      profilePicture: json['profile_picture']?.toString(),
      totalPoints: json['totalPoints'] is int ? json['totalPoints'] : int.tryParse(json['totalPoints']?.toString() ?? '0') ?? 0,
      level: json['level'] is int ? json['level'] : int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      levelName: json['levelName']?.toString() ?? 'New Explorer',
      minXp: json['minXp'] is int ? json['minXp'] : int.tryParse(json['minXp']?.toString() ?? '0') ?? 0,
      nextLevelMinXp: json['nextLevelMinXp'] is int ? json['nextLevelMinXp'] : int.tryParse(json['nextLevelMinXp']?.toString() ?? '200') ?? 200,
      rank: json['rank'] is int ? json['rank'] : int.tryParse(json['rank']?.toString() ?? '1') ?? 1,
      featuredBadge: json['featuredBadge'] != null && json['featuredBadge'] is Map<String, dynamic>
          ? BadgeModel.fromJson(json['featuredBadge'])
          : null,
      badges: bList,
    );
  }
}
