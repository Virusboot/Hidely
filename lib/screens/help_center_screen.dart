import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xffF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xff1C0D5A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Help Center",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                    shape: const Border(),
                    title: Text(
                      faq["q"]!,
                      style: const TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    );
  }
}
