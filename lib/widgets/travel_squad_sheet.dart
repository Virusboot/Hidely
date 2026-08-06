import 'package:flutter/material.dart';

class TravelSquadSheet extends StatefulWidget {
  final String locationName;

  const TravelSquadSheet({super.key, required this.locationName});

  @override
  State<TravelSquadSheet> createState() => _TravelSquadSheetState();
}

class _TravelSquadSheetState extends State<TravelSquadSheet> {
  bool _hasJoined = false;

  final List<Map<String, String>> _squadMembers = [
    {'name': 'Aarav Sharma', 'handle': '@aarav_travels', 'status': 'Visiting this weekend'},
    {'name': 'Ananya Roy', 'handle': '@ananya_explores', 'status': 'Planning trip in 3 days'},
    {'name': 'Rohan Gupta', 'handle': '@rohan_hikes', 'status': 'Looking for travel buddies'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
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
                  color: const Color(0xff29A96A).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xff29A96A), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Travel Squad',
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff1C0D5A),
                      ),
                    ),
                    Text(
                      'Explorers planning to visit ${widget.locationName}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._squadMembers.map((member) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xffF6F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xff2B1564),
                    radius: 18,
                    child: Text(
                      member['name']![0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['name']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1C0D5A)),
                        ),
                        Text(
                          member['status']!,
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xffE0E7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      member['handle']!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff4F46E5)),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasJoined = !_hasJoined;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_hasJoined ? 'You joined the Travel Squad for ${widget.locationName}!' : 'You left the squad.'),
                    backgroundColor: const Color(0xff29A96A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: Icon(_hasJoined ? Icons.check_circle_rounded : Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
              label: Text(_hasJoined ? 'Joined Squad' : 'I\'m Planning to Visit Too', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasJoined ? const Color(0xff29A96A) : const Color(0xff2B1564),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
