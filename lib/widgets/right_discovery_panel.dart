import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidely_new/screens/leaderboard_screen.dart';
import 'package:hidely_new/screens/explore_screen.dart';

class RightDiscoveryPanel extends ConsumerWidget {
  const RightDiscoveryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Featured Spots Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff2B1564), Color(0xff9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff9333EA).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.explore, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'FEATURED DISCOVERY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rohtang Pass & Himalayan Valleys',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Discover snow-capped Himalayan adventure routes and hidden stays.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff2B1564),
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Explore Hidden Spots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Trending Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spot Categories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xff0F172A),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()));
                },
                child: const Text('See All', style: TextStyle(fontSize: 12, color: Color(0xff9333EA))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCategoryTile(context, icon: '🌊', title: 'Waterfalls', subtitle: 'Jog Falls, Athirappilly'),
          _buildCategoryTile(context, icon: '🌄', title: 'Sunset Spots', subtitle: 'High altitude viewpoints'),
          _buildCategoryTile(context, icon: '🏰', title: 'Forts & Heritage', subtitle: 'Historical hidden ruins'),
          _buildCategoryTile(context, icon: '🌲', title: 'Nature Treks', subtitle: 'Scenic forest trails'),

          const SizedBox(height: 24),
          const Divider(color: Color(0xffF1F5F9)),
          const SizedBox(height: 16),

          // Section 3: Leaderboard Snippet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Explorers',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xff0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xff64748B)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCreatorTile(name: 'Hidely Picks', username: '@hidely_picks', points: '12,800 pts', badge: '👑'),
          _buildCreatorTile(name: 'Aura Queen', username: '@aura_queen', points: '9,450 pts', badge: '🥇'),
          _buildCreatorTile(name: 'Marcus Vance', username: '@marcus_vance', points: '8,200 pts', badge: '🥈'),

          const SizedBox(height: 30),
          // Footer
          const Text(
            '© 2026 Hidely Platform • Terms & Privacy',
            style: TextStyle(fontSize: 11, color: Color(0xff94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, {required String icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1E293B))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xff64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorTile({required String name, required String username, required String points, required String badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xffE2DCF7),
            child: Text(badge, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff0F172A))),
                Text(username, style: const TextStyle(fontSize: 11, color: Color(0xff64748B))),
              ],
            ),
          ),
          Text(points, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xff9333EA))),
        ],
      ),
    );
  }
}
