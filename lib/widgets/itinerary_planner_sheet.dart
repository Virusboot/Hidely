import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/config/app_colors.dart';
import 'package:hidely_new/services/ai_service.dart';

class ItineraryPlannerSheet extends StatefulWidget {
  final String locationName;

  const ItineraryPlannerSheet({super.key, required this.locationName});

  @override
  State<ItineraryPlannerSheet> createState() => _ItineraryPlannerSheetState();
}

class _ItineraryPlannerSheetState extends State<ItineraryPlannerSheet> {
  late TextEditingController _locationController;

  // Budget Slider Value (Right below Destination)
  double _budget = 10000;

  // Dates
  DateTimeRange? _selectedDateRange;

  // Travellers
  String _selectedTraveller = 'Friends';
  final List<String> _travellerOptions = ['Solo', 'Couple', 'Friends', 'Family'];

  // Transport
  String _selectedTransport = 'Car';
  final List<String> _transportOptions = ['Car', 'Bike', 'Train', 'Flight', 'Bus'];

  // Stay
  String _selectedStay = 'Mid-range';
  final List<String> _stayOptions = ['Budget', 'Mid-range', 'Luxury', 'Hostel'];

  // Trip Vibe
  final Set<String> _selectedVibes = {'Adventure', 'Nature'};
  final List<String> _vibeOptions = [
    'Adventure',
    'Nature',
    'Hidden',
    'Food',
    'Photography',
    'Spiritual',
    'Relaxation',
    'Nightlife',
  ];

  // Pace
  String _selectedPace = 'Balanced';
  final List<String> _paceOptions = ['Relaxed', 'Balanced', 'Packed'];

  bool _isGenerating = false;
  AiItineraryResult? _generatedItinerary;

  @override
  void initState() {
    super.initState();
    final initialLoc = widget.locationName.contains('Trip') ? '' : widget.locationName;
    _locationController = TextEditingController(text: initialLoc);
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().add(const Duration(days: 1)),
      end: DateTime.now().add(const Duration(days: 4)),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    if (_selectedDateRange == null) return 3;
    final days = _selectedDateRange!.duration.inDays;
    return days > 0 ? days : 1;
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().add(const Duration(days: 1)),
          end: DateTime.now().add(const Duration(days: 4)),
        );
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _generateItinerary() async {
    final destination = _locationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your destination'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final result = await AiService().generateCustomItinerary(
      location: destination,
      budget: _budget,
      days: _calculatedDays,
    );

    if (mounted) {
      setState(() {
        _generatedItinerary = result;
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveItineraryToStorage() async {
    if (_generatedItinerary == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> existingRaw = prefs.getStringList('saved_itineraries') ?? [];

      final Map<String, dynamic> item = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'location': _generatedItinerary!.location,
        'days': _generatedItinerary!.days,
        'budget': _generatedItinerary!.budget,
        'summaryTip': _generatedItinerary!.summaryTip,
        'savedAt': DateTime.now().toIso8601String(),
        'daysData': _generatedItinerary!.itineraryDays.map((d) => {
              'dayNumber': d.dayNumber,
              'title': d.title,
              'morning': d.morning,
              'afternoon': d.afternoon,
              'evening': d.evening,
              'estimatedCost': d.estimatedCost,
            }).toList(),
      };

      existingRaw.add(json.encode(item));
      await prefs.setStringList('saved_itineraries', existingRaw);
    } catch (e) {
      debugPrint('Error saving itinerary: $e');
    }
  }

  void _openVibePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Trip Vibes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _vibeOptions.map((vibe) {
                      final isSel = _selectedVibes.contains(vibe);
                      return FilterChip(
                        label: Text(vibe),
                        selected: isSel,
                        selectedColor: const Color(0xFFEDE9FE),
                        checkmarkColor: const Color(0xFF6D28D9),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? const Color(0xFF6D28D9) : const Color(0xFF475569),
                        ),
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              _selectedVibes.add(vibe);
                            } else {
                              if (_selectedVibes.length > 1) {
                                _selectedVibes.remove(vibe);
                              }
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryDark),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSlot({
    required IconData icon,
    required String slotName,
    required String timeRange,
    required String desc,
    required List<Color> gradientColors,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: gradientColors.first.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slotName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            timeRange,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: textColor.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxSheetHeight = screenHeight * 0.90;
    final double adjustedHeight = (maxSheetHeight - bottomInset).clamp(280.0, maxSheetHeight);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: adjustedHeight,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Drag Handle Bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Header (Fixed at Top)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Trip Planner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Live AI Status Pill
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isGenerating ? const Color(0xffEEF2FF) : const Color(0xffECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isGenerating ? const Color(0xffC7D2FE) : const Color(0xffA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 11,
                                      color: _isGenerating ? const Color(0xff4F46E5) : const Color(0xff059669),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isGenerating ? 'AI Syncing...' : 'AI Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _isGenerating ? const Color(0xff4F46E5) : const Color(0xff059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Auto AI customized itinerary for your travel',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_generatedItinerary != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _generatedItinerary = null;
                        });
                      },
                      child: const Text(
                        'Edit Form',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 19),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Scrollable Content
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  if (_isGenerating)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.primary),
                            const SizedBox(height: 16),
                            Text(
                              'Crafting your ideal trip to ${_locationController.text}...',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_generatedItinerary != null) ...[
                    // Generated Itinerary Display
                    if (_generatedItinerary!.summaryTip.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 15),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _generatedItinerary!.summaryTip,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    ..._generatedItinerary!.itineraryDays.map((day) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Day ${day.dayNumber}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      day.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  if (day.estimatedCost > 0) ...[
                                    const SizedBox(width: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xffA7F3D0)),
                                        ),
                                        child: Text(
                                          '~₹${day.estimatedCost.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                              ),
                              _buildTimelineSlot(
                                icon: Icons.wb_twilight_rounded,
                                slotName: 'Morning Exploration',
                                timeRange: '08:00 AM - 12:00 PM',
                                desc: day.morning,
                                gradientColors: const [Color(0xFFF97316), Color(0xFFFBBF24)],
                                cardBg: const Color(0xFFFFFBEB),
                                borderColor: const Color(0xFFFDE68A),
                                textColor: const Color(0xFFB45309),
                                isLast: false,
                              ),
                              _buildTimelineSlot(
                                icon: Icons.wb_sunny_rounded,
                                slotName: 'Afternoon Adventure',
                                timeRange: '12:30 PM - 05:00 PM',
                                desc: day.afternoon,
                                gradientColors: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                                cardBg: const Color(0xFFF0F9FF),
                                borderColor: const Color(0xFFBAE6FD),
                                textColor: const Color(0xFF0369A1),
                                isLast: false,
                              ),
                              _buildTimelineSlot(
                                icon: Icons.nights_stay_rounded,
                                slotName: 'Evening Experience',
                                timeRange: '05:30 PM - 09:00 PM',
                                desc: day.evening,
                                gradientColors: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                                cardBg: const Color(0xFFF5F3FF),
                                borderColor: const Color(0xFFDDD6FE),
                                textColor: const Color(0xFF6D28D9),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    // Clean Form Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Destination
                          const Text(
                            'Destination',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              controller: _locationController,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Where are you going?',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.black38),
                                prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Total Budget Slider (Directly under Destination)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Budget',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₹${_budget.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 5,
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.primary.withOpacity(0.12),
                              thumbColor: AppColors.primary,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayColor: AppColors.primary.withOpacity(0.1),
                            ),
                            child: Slider(
                              value: _budget,
                              min: 1000,
                              max: 50000,
                              divisions: 49,
                              onChanged: (val) {
                                setState(() => _budget = val);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Dates
                          const Text(
                            'Dates',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDateRange(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Start Date → End Date',
                                          style: TextStyle(fontSize: 10.5, color: Colors.black45, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _selectedDateRange != null
                                              ? "${DateFormat('d MMM').format(_selectedDateRange!.start)} - ${DateFormat('d MMM').format(_selectedDateRange!.end)} ($_calculatedDays Days)"
                                              : "Select Trip Dates",
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, color: Colors.black45, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Travellers Dropdown
                          _buildDropdownField(
                            label: 'Travellers',
                            value: _selectedTraveller,
                            items: _travellerOptions,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTraveller = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // 5. Transport Dropdown
                          _buildDropdownField(
                            label: 'Transport',
                            value: _selectedTransport,
                            items: _transportOptions,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTransport = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // 6. Stay Dropdown
                          _buildDropdownField(
                            label: 'Stay',
                            value: _selectedStay,
                            items: _stayOptions,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStay = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // 7. Trip Vibe Selector Dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trip Vibe',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _openVibePickerModal(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedVibes.isEmpty ? 'Select Trip Vibes' : _selectedVibes.join(', '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryDark),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 8. Pace Dropdown
                          _buildDropdownField(
                            label: 'Pace',
                            value: _selectedPace,
                            items: _paceOptions,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPace = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),

            // Fixed Bottom CTA Button
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomPadding),
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
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isGenerating
                      ? null
                      : (_generatedItinerary == null
                          ? _generateItinerary
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              final loc = _locationController.text;
                              await _saveItineraryToStorage();
                              if (mounted) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Itinerary for $loc saved to Trip List!',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _generatedItinerary == null
                              ? Icons.auto_awesome_rounded
                              : Icons.bookmark_add_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isGenerating
                              ? 'Creating Your Trip...'
                              : (_generatedItinerary == null ? 'Create My Trip' : 'Save Itinerary'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
