import 'package:flutter/material.dart';

class ItineraryPlannerSheet extends StatelessWidget {
  final String locationName;

  const ItineraryPlannerSheet({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff5B3EC8).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xff5B3EC8), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '1-Day Itinerary • $locationName',
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff1C0D5A),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimelineSlot(
            time: '08:30 AM',
            title: 'Morning Exploration & Sunrise View',
            desc: 'Arrive early at $locationName to catch soft lighting and minimal crowd.',
            icon: Icons.wb_twilight_rounded,
            color: const Color(0xffF57C00),
          ),
          _buildTimelineSlot(
            time: '01:00 PM',
            title: 'Local Heritage Lunch & Relaxation',
            desc: 'Enjoy authentic regional cuisine at top-rated nearby heritage dining.',
            icon: Icons.restaurant_rounded,
            color: const Color(0xff0288D1),
          ),
          _buildTimelineSlot(
            time: '04:30 PM',
            title: 'Secret Spot Sunset & Photography',
            desc: 'Head to the panoramic viewpoint for sunset vistas and travel captures.',
            icon: Icons.photo_camera_rounded,
            color: const Color(0xff7C3AED),
            isLast: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Itinerary saved for $locationName!'),
                    backgroundColor: const Color(0xff2B1564),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 18),
              label: const Text('Save Itinerary to Trip List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2B1564),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSlot({
    required String time,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff1C0D5A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
