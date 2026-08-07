import 'package:flutter/material.dart';
import 'package:hidely_new/services/ai_service.dart';

class ItineraryPlannerSheet extends StatefulWidget {
  final String locationName;

  const ItineraryPlannerSheet({super.key, required this.locationName});

  @override
  State<ItineraryPlannerSheet> createState() => _ItineraryPlannerSheetState();
}

class _ItineraryPlannerSheetState extends State<ItineraryPlannerSheet> {
  late TextEditingController _locationController;
  double _budget = 5000;
  int _days = 3;
  bool _isGenerating = false;
  AiItineraryResult? _generatedItinerary;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.locationName);
    _generateItinerary();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _generateItinerary() async {
    setState(() => _isGenerating = true);
    final result = await AiService().generateCustomItinerary(
      location: _locationController.text.trim().isEmpty ? 'Destination' : _locationController.text.trim(),
      budget: _budget,
      days: _days,
    );

    if (mounted) {
      setState(() {
        _generatedItinerary = result;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff5B3EC8).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xff5B3EC8), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Trip Planner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1C0D5A),
                        ),
                      ),
                      Text(
                        'Customized Budget & Duration Itinerary',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
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
          ),

          const SizedBox(height: 8),

          // Input Controls: Location, Budget, Days
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Location Input
                  TextField(
                    controller: _locationController,
                    onSubmitted: (_) => _generateItinerary(),
                    decoration: InputDecoration(
                      labelText: 'Destination Location',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xff5B3EC8), size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Budget & Days Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Budget: ₹${_budget.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                            ),
                            Slider(
                              value: _budget,
                              min: 1000,
                              max: 25000,
                              divisions: 24,
                              activeColor: const Color(0xff5B3EC8),
                              onChanged: (val) {
                                setState(() => _budget = val);
                              },
                              onChangeEnd: (_) => _generateItinerary(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Days:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, size: 16),
                                  onPressed: _days > 1
                                      ? () {
                                          setState(() => _days--);
                                          _generateItinerary();
                                        }
                                      : null,
                                ),
                                Text(
                                  '$_days',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  onPressed: _days < 7
                                      ? () {
                                          setState(() => _days++);
                                          _generateItinerary();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Generated Itinerary Display
          Expanded(
            child: _isGenerating
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xff5B3EC8)),
                  )
                : _generatedItinerary == null
                    ? const SizedBox()
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Summary Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff5B3EC8).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lightbulb_rounded, color: Color(0xff5B3EC8), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _generatedItinerary!.summaryTip,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xff1C0D5A), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Days Loop
                          ..._generatedItinerary!.itineraryDays.map((day) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1.5,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Day ${day.dayNumber}: ${day.title}',
                                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '~₹${day.estimatedCost.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    _buildSlotRow(Icons.wb_twilight_rounded, 'Morning', day.morning, const Color(0xffF57C00)),
                                    const SizedBox(height: 8),
                                    _buildSlotRow(Icons.wb_sunny_rounded, 'Afternoon', day.afternoon, const Color(0xff0288D1)),
                                    const SizedBox(height: 8),
                                    _buildSlotRow(Icons.nightlife_rounded, 'Evening', day.evening, const Color(0xff7C3AED)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
          ),

          // Save CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('AI Itinerary for ${_locationController.text} saved to Trip List!'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(IconData icon, String label, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'PublicSans'),
              children: [
                TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
