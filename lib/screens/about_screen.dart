import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 16.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- 1. PREMIUM CENTERED HEADER BAR ---
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
                        "About Hidely",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button on the left
                  ],
                ),
              ),

              // --- 2. BODY CONTENT ---
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 32.0,
                    bottom: bottomPadding,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Logo image container matching standard design branding
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Hidely",
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Version 1.0.0 (Build 12)",
                        style: TextStyle(
                          color: Color(0xff6B657D),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Hidely is a premium travel discovery platform that enables creators to explore nearby stays, discover unseen routes, and share travel logs securely.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xff3D2A7A),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      // Bottom Info Footer block
                      const Text(
                        "© 2026 Hidely Inc. All rights reserved.",
                        style: TextStyle(
                          color: Color(0xff8E8AA0),
                          fontSize: 12,
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
