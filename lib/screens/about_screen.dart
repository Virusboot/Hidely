import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          "About Hidely",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
