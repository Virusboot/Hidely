import 'package:flutter/material.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _expandedIndex;

  final List<Map<String, String>> faqs = [
    {
      "q": "How do I download offline maps?",
      "a": "Go to the Maps screen, tap the download icon on the bottom right of the map, and select your area to save it locally."
    },
    {
      "q": "How can I block someone?",
      "a": "Visit the creator's profile page, tap the three dots (...) in the top right corner, and select 'Block'."
    },
    {
      "q": "Is my location shared publicly?",
      "a": "No, Hidely prioritizes your privacy. Your real-time location details are never shared with other users without your explicit permission."
    },
    {
      "q": "How does 3D Navigation work?",
      "a": "Start navigation for any stay or destination. The map automatically rotates and tilts to a 3D perspective to follow your path."
    }
  ];

  @override
  Widget build(BuildContext context) {
    // Add bottom padding to prevent content from hiding behind the system navigation bar
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 24.0;

    return Scaffold(
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
              // --- 1. PREMIUM HEADER BAR (Matches other settings pages) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/back_icon.png',
                            color: const Color(0xff1C0D5A),
                            width: 18.0,
                            height: 18.0,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "Help Center",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 20, // Match 20 from settings & privacy
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button on the left
                  ],
                ),
              ),

              // --- 2. SCROLLABLE BODY ---
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 12.0,
                    bottom: bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff2B1564), Color(0xff4B2D8E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "How can we help?",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Find answers, read policies, or get in touch with our support team directly.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Frequently Asked Questions",
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // FAQs List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: faqs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final faq = faqs[index];
                          final isExpanded = _expandedIndex == index;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ExpansionTile(
                              key: Key('faq_${index}_$isExpanded'),
                              shape: const Border(),
                              initiallyExpanded: isExpanded,
                              title: Text(
                                faq["q"]!,
                                style: const TextStyle(
                                  color: Color(0xff1C0D5A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onExpansionChanged: (expanding) {
                                setState(() {
                                  if (expanding) {
                                    _expandedIndex = index;
                                  } else {
                                    if (_expandedIndex == index) {
                                      _expandedIndex = null;
                                    }
                                  }
                                });
                              },
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                  child: Text(
                                    faq["a"]!,
                                    style: TextStyle(
                                      color: const Color(0xff1C0D5A).withOpacity(0.7),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      // Contact Support Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xffE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.mail_outline_rounded, size: 36, color: Color(0xff2B1564)),
                            const SizedBox(height: 12),
                            const Text(
                              "Still need help?",
                              style: TextStyle(
                                color: Color(0xff1C0D5A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Send an email to our support team and we will get back to you shortly.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xff1C0D5A).withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xff2B1564),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Text(
                                "support@hidely.app",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
