import 'package:flutter/material.dart';
import 'package:hidely_new/models/gamification_models.dart';
import 'package:hidely_new/services/api_service.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  bool _isLoading = true;
  List<PointTransaction> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await ApiService().getPointHistory();
    if (mounted) {
      if (result.success) {
        final list = (result.data?['history'] as List?)
                ?.map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        setState(() {
          _history = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getEventColor(String eventType) {
    if (eventType.contains('hidden_place') || eventType.contains('verified')) {
      return const Color(0xff10B981);
    }
    if (eventType.contains('camera') || eventType.contains('high_accuracy')) {
      return const Color(0xff3B82F6);
    }
    if (eventType.contains('level') || eventType.contains('badge')) {
      return const Color(0xffA855F7);
    }
    return const Color(0xff2B1564);
  }

  IconData _getEventIcon(String eventType) {
    if (eventType.contains('hidden_place')) return Icons.place_rounded;
    if (eventType.contains('camera')) return Icons.camera_alt_rounded;
    if (eventType.contains('accuracy')) return Icons.gps_fixed_rounded;
    if (eventType.contains('level') || eventType.contains('badge')) return Icons.emoji_events_rounded;
    return Icons.stars_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Points Activity",
          style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xff1C0D5A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        "No point transactions yet.",
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Start exploring places and sharing camera posts!",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
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
                            width: 44,
                            height: 44,
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
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff1C0D5A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tx.createdAt.length > 10 ? tx.createdAt.substring(0, 10) : tx.createdAt,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xffF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "+${tx.points}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
