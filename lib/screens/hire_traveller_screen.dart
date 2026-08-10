import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'creator_profile_screen.dart';

class HireTravellerScreen extends StatefulWidget {
  const HireTravellerScreen({super.key});

  @override
  State<HireTravellerScreen> createState() => _HireTravellerScreenState();
}

class _HireTravellerScreenState extends State<HireTravellerScreen> {
  String _selectedCity = 'All Cities';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _cities = [
    'All Cities',
    'Manali',
    'Rishikesh',
    'Goa',
    'Jaipur',
    'Leh Ladakh',
    'Gokarna',
    'Shimla',
    'Kerala',
  ];

  final List<Map<String, dynamic>> _allTravellers = [
    {
      'id': '1',
      'name': 'Aarav Sharma',
      'city': 'Manali',
      'avatar': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
      'role': 'High Altitude Trek Guide & Drone Specialist',
      'rating': 4.9,
      'reviewsCount': 52,
      'pricePerDay': 1500,
      'experienceYears': 5,
      'languages': ['Hindi', 'English', 'Pahari'],
      'isVerified': true,
      'badge': 'Master Explorer',
      'bio': 'Born & raised in Solang Valley. Led over 120+ successful treks to Hampta Pass, Bhrigu Lake, and Beas Kund. Drone photography expert.',
      'specialties': ['Trekking', 'Camp Bonfire', 'Photography', 'Hidden Trails'],
      'available': true,
    },
    {
      'id': '2',
      'name': 'Riya Verma',
      'city': 'Rishikesh',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      'role': 'River Rafting Instructor & Yoga Host',
      'rating': 4.8,
      'reviewsCount': 41,
      'pricePerDay': 1200,
      'experienceYears': 4,
      'languages': ['Hindi', 'English'],
      'isVerified': true,
      'badge': 'Pro Guide',
      'bio': 'Certified white-water rafting captain & morning yoga practitioner at Ganga Ghats. Know all secret waterfalls around Tapovan.',
      'specialties': ['Rafting', 'Cliff Jumping', 'Ganga Aarti', 'Cafe Hopping'],
      'available': true,
    },
    {
      'id': '3',
      'name': 'Vikram D’Souza',
      'city': 'Goa',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      'role': 'Beach Shack & Secret Island Host',
      'rating': 4.95,
      'reviewsCount': 68,
      'pricePerDay': 1800,
      'experienceYears': 6,
      'languages': ['English', 'Hindi', 'Konkani'],
      'isVerified': true,
      'badge': 'Beach Specialist',
      'bio': 'South & North Goa local legend. Expert in private boat trips, hidden cliff sunset points, and secret seafood shacks.',
      'specialties': ['Water Sports', 'Sunset Kayaking', 'Seafood Trail', 'Scooter Tours'],
      'available': true,
    },
    {
      'id': '4',
      'name': 'Kaviraj Singh Rathore',
      'city': 'Jaipur',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
      'role': 'Heritage Fort Historian & Thali Host',
      'rating': 4.85,
      'reviewsCount': 36,
      'pricePerDay': 1400,
      'experienceYears': 7,
      'languages': ['Hindi', 'English', 'Rajasthani'],
      'isVerified': true,
      'badge': 'Heritage Guide',
      'bio': 'Passionate storyteller of Amer Fort, Nahargarh secret tunnels, and authentic Rajasthani food bazaars.',
      'specialties': ['Fort Architecture', 'Bazaar Walking', 'Authentic Dining', 'Night Views'],
      'available': true,
    },
    {
      'id': '5',
      'name': 'Stanzin Norbu',
      'city': 'Leh Ladakh',
      'avatar': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      'role': 'High Pass Biker & Monastery Guide',
      'rating': 5.0,
      'reviewsCount': 74,
      'pricePerDay': 2200,
      'experienceYears': 8,
      'languages': ['English', 'Hindi', 'Ladakhi'],
      'isVerified': true,
      'badge': 'Himalayan Veteran',
      'bio': 'Royal Enfield expedition leader across Khardung La & Pangong Tso. Stargazing host at Nubra Valley Sand Dunes.',
      'specialties': ['Motorbike Expeditions', 'Monastery Culture', 'Homestay Booking', 'Stargazing'],
      'available': true,
    },
    {
      'id': '6',
      'name': 'Ananya Patel',
      'city': 'Gokarna',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
      'role': 'Coastal Beach Trekker & Solo Travel Host',
      'rating': 4.75,
      'reviewsCount': 29,
      'pricePerDay': 1100,
      'experienceYears': 3,
      'languages': ['English', 'Hindi', 'Kannada'],
      'isVerified': true,
      'badge': 'Coastal Explorer',
      'bio': '5-Beach Trek specialist (Kuddle, Om, Half Moon, Paradise, Belekan). Passionate about eco-travel and quiet sunset spots.',
      'specialties': ['Coastal Trekking', 'Beach Camping', 'Cafe Culture', 'Solo Safety'],
      'available': true,
    },
    {
      'id': '7',
      'name': 'Rohit Thakur',
      'city': 'Shimla',
      'avatar': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=400&q=80',
      'role': 'Apple Orchard & Heritage Walk Host',
      'rating': 4.88,
      'reviewsCount': 45,
      'pricePerDay': 1300,
      'experienceYears': 5,
      'languages': ['Hindi', 'English', 'Pahari'],
      'isVerified': true,
      'badge': 'Local Host',
      'bio': 'Kotgarh apple orchard owner & Jakhu hill expert. Guides peaceful pine forest walks away from overcrowded Mall Road.',
      'specialties': ['Forest Walks', 'Orchard Stay', 'Colonial History', 'Local Dhaba'],
      'available': true,
    },
    {
      'id': '8',
      'name': 'Meera Menon',
      'city': 'Kerala',
      'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
      'role': 'Backwater Houseboat & Spice Trail Guide',
      'rating': 4.92,
      'reviewsCount': 63,
      'pricePerDay': 1600,
      'experienceYears': 6,
      'languages': ['English', 'Hindi', 'Malayalam'],
      'isVerified': true,
      'badge': 'Nature Explorer',
      'bio': 'Alleppey native specializing in serene village canoe rides, Munnar tea plantation walks, and authentic Sadya feast.',
      'specialties': ['Backwater Canoe', 'Tea Gardens', 'Ayurveda Trail', 'Local Cuisine'],
      'available': true,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTravellerDetailModal(Map<String, dynamic> traveller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final List<String> specialties = List<String>.from(traveller['specialties'] ?? []);
        final List<String> languages = List<String>.from(traveller['languages'] ?? []);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Top Drag Handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Modal Profile Header Card (Clickable to open Creator Profile!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatorProfileScreen(
                                username: traveller['name'],
                                avatarPath: traveller['avatar'],
                                rank: traveller['badge'],
                                bio: traveller['bio'],
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF1C0D5A), Color(0xFF6D28D9)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: UserAvatar(
                                    avatarUrl: traveller['avatar'],
                                    displayName: traveller['name'],
                                    radius: 28,
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        traveller['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1C0D5A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (traveller['isVerified'] == true) ...[
                                        const SizedBox(width: 5),
                                        const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 18),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          traveller['city'],
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF5FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFE9D5FF)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.workspace_premium_rounded, color: Color(0xFF9333EA), size: 13),
                                            const SizedBox(width: 3),
                                            Text(
                                              traveller['badge'],
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),

              // Scrollable Content Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    // 3 Clean Theme Metric Cards Side-by-Side
                    Row(
                      children: [
                        // Rating Stat Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.star_rounded, color: Color(0xFF1C0D5A), size: 16),
                                    SizedBox(width: 3),
                                    Text(
                                      '4.9',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${traveller['reviewsCount']} Reviews',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Experience Stat Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${traveller['experienceYears']}+ Yrs',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Experience',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Price Rate Stat Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '₹${traveller['pricePerDay']}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Per Day',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // About Local Guide Card
                    const Text(
                      'About Local Guide',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        traveller['bio'],
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.55),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Specialties
                    const Text(
                      'Specialties & Expertise',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialties.map((spec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            spec,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1C0D5A)),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Languages Spoken
                    const Text(
                      'Languages Spoken',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: languages.map((lang) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            lang,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1C0D5A), fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Verified Trust Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Verified Explorer • 100% Direct Local Experience',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Bottom Floating Action Bar with SafeArea padding fix (Full Width Book Button!)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hiring request sent to ${traveller['name']}!'),
                              backgroundColor: const Color(0xFF1C0D5A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.handshake_rounded, color: Colors.white, size: 18),
                        label: Text(
                          'Book Guide • ₹${traveller['pricePerDay']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C0D5A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor: const Color(0xFF1C0D5A).withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final filteredTravellers = _allTravellers.where((t) {
      final matchesCity = (_selectedCity == 'All Cities') || (t['city'] == _selectedCity);
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          (t['name'] as String).toLowerCase().contains(query) ||
          (t['city'] as String).toLowerCase().contains(query) ||
          (t['role'] as String).toLowerCase().contains(query);
      return matchesCity && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffE0F2FE),
              Color(0xffFDF7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Bar (Simple, Clean & Corrected Back Arrow!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xff1C0D5A),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "Hire a Traveller",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1C0D5A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 38), // Balance header width
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E1B4B)),
                          decoration: const InputDecoration(
                            hintText: 'Search city, guide or skill...',
                            hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Horizontal City Filter Chips Bar
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _cities.length,
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final isSelected = city == _selectedCity;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCity = city),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1C0D5A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1C0D5A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                city == 'All Cities' ? Icons.travel_explore_rounded : Icons.location_on_rounded,
                                size: 13,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                city,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Travellers Cards List (Ultra Clean Layout!)
              Expanded(
                child: filteredTravellers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.explore_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'No guides found for "$_selectedCity"',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                        itemCount: filteredTravellers.length,
                        itemBuilder: (context, index) {
                          final t = filteredTravellers[index];
                          final List<String> specialties = List<String>.from(t['specialties'] ?? []);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.025),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showTravellerDetailModal(t),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header: Avatar + Name + Price
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => CreatorProfileScreen(
                                                      username: t['name'],
                                                      avatarPath: t['avatar'],
                                                      rank: t['badge'],
                                                      bio: t['bio'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Row(
                                                children: [
                                                  Stack(
                                                    children: [
                                                       UserAvatar(
                                                         avatarUrl: t['avatar'],
                                                         displayName: t['name'],
                                                         radius: 23,
                                                       ),
                                                      Positioned(
                                                        right: 0,
                                                        bottom: 0,
                                                        child: Container(
                                                          width: 11,
                                                          height: 11,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF10B981),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: Colors.white, width: 2),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                t['name'],
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(
                                                                  fontSize: 15.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Color(0xFF1E1B4B),
                                                                ),
                                                              ),
                                                            ),
                                                            if (t['isVerified'] == true) ...[
                                                              const SizedBox(width: 4),
                                                              const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 15),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 1),
                                                        Text(
                                                          t['role'],
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Clean Price Tag
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '₹${t['pricePerDay']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ),
                                                const Text(
                                                  '/day',
                                                  style: TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      // Clean Meta Line: Rating • City • Experience
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${t['rating']} (${t['reviewsCount']})',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                          ),
                                          const Icon(Icons.location_on_rounded, color: Color(0xFF475569), size: 13),
                                          const SizedBox(width: 2),
                                          Text(
                                            t['city'],
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                          ),
                                          Text(
                                            '${t['experienceYears']} yrs exp',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),

                                      // Specialty Chips
                                      if (specialties.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: specialties.take(3).map((spec) {
                                              return Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Text(
                                                  spec,
                                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 12),

                                      // Full Width Primary CTA: View Profile & Hire
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _showTravellerDetailModal(t),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1C0D5A),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text(
                                            'View Profile & Hire',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
