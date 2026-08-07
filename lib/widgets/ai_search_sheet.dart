import 'package:flutter/material.dart';
import 'package:hidely_new/services/ai_service.dart';

class AiSearchSheet extends StatefulWidget {
  final String initialQuery;

  const AiSearchSheet({super.key, this.initialQuery = ''});

  @override
  State<AiSearchSheet> createState() => _AiSearchSheetState();
}

class _AiSearchSheetState extends State<AiSearchSheet> {
  final TextEditingController _queryController = TextEditingController();
  bool _isSearching = false;
  AiSearchResult? _searchResult;

  final List<String> _quickSuggestions = [
    'Delhi ke paas hidden waterfall',
    'Rishikesh secret camping spot',
    'Budget mountain treks under 5000',
    'Best sunset viewpoints in Goa',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _queryController.text = widget.initialQuery;
      _performAiSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performAiSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Record user preference category for Netflix-style personalization
    if (query.toLowerCase().contains('waterfall')) {
      UserPreferenceEngine.recordCategoryView('Waterfalls');
    } else if (query.toLowerCase().contains('trek')) {
      UserPreferenceEngine.recordCategoryView('Trekking');
    } else if (query.toLowerCase().contains('beach') || query.toLowerCase().contains('goa')) {
      UserPreferenceEngine.recordCategoryView('Beaches');
    }

    setState(() {
      _isSearching = true;
    });

    final result = await AiService().aiSearchPlaces(query);

    if (mounted) {
      setState(() {
        _searchResult = result;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
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
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Intelligent Search',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C0D5A),
                      ),
                    ),
                    Text(
                      'Conversational travel recommendations',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Color(0xFF7C3AED), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      onSubmitted: (val) => _performAiSearch(val),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Delhi ke paas hidden waterfall...',
                        hintStyle: TextStyle(fontSize: 13.5, color: Colors.black45),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF7C3AED)),
                    onPressed: () => _performAiSearch(_queryController.text),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _quickSuggestions.map((sug) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    avatar: const Icon(Icons.auto_awesome_outlined, size: 14, color: Color(0xFF7C3AED)),
                    label: Text(sug, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                    onPressed: () {
                      _queryController.text = sug;
                      _performAiSearch(sug);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Search Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF7C3AED)),
                        SizedBox(height: 14),
                        Text(
                          'AI is searching hidden spots & calculating recommendations...',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                : _searchResult == null
                    ? const Center(
                        child: Text(
                          'Type any query above to ask AI!',
                          style: TextStyle(fontSize: 14, color: Colors.black45),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Conversational AI Direct Answer Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7C3AED).withOpacity(0.08),
                                  const Color(0xFF2563EB).withOpacity(0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'AI Direct Recommendation',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchResult!.directAnswer,
                                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            'Matched Hidden Destinations:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C0D5A)),
                          ),
                          const SizedBox(height: 12),

                          ..._searchResult!.recommendedPlaces.map((place) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              child: Row(
                                children: [
                                  Image.network(
                                    place['image'],
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: Colors.grey.shade300),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place['name'],
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${place['location']} • ${place['distance']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${place['rating']}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                place['category'],
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
