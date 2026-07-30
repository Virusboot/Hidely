import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar with Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
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
                      const SizedBox(width: 16),
                      const Text(
                        "Terms of Service",
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Terms of Service",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Last updated: July 16, 2026",
                          style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader("1. Acceptance of Terms"),
                        _buildSectionBody(
                          "Welcome to Hidely. By creating an account or using our mobile application, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, you should not access or use our services.",
                        ),
                        _buildSectionHeader("2. User Accounts"),
                        _buildSectionBody(
                          "To access certain features of Hidely, you must create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to provide accurate, current, and complete information during registration.",
                        ),
                        _buildSectionHeader("3. Privacy & Location Sharing"),
                        _buildSectionBody(
                          "Hidely is a location-contextual platform. Your privacy is paramount to us. Location sharing is only initiated with your active consent. Please read our Privacy Policy to understand how we collect, use, and share your information, including your location data.",
                        ),
                        _buildSectionHeader("4. Acceptable Conduct"),
                        _buildSectionBody(
                          "You agree not to use the app to upload, post, or distribute any content that is unlawful, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, or invasive of another's privacy. Users found violating these rules may have their accounts suspended or terminated.",
                        ),
                        _buildSectionHeader("5. Intellectual Property"),
                        _buildSectionBody(
                          "All original content, designs, features, and functionality of Hidely are and will remain the exclusive property of Hidely and its licensors. You may not reproduce, copy, or redistribute any elements of the app without explicit written permission.",
                        ),
                        _buildSectionHeader("6. Limitation of Liability"),
                        _buildSectionBody(
                          "Hidely is provided on an 'as-is' and 'as-available' basis. In no event shall Hidely, its directors, employees, or partners be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your access to or use of the app.",
                        ),
                        _buildSectionHeader("7. Changes to Terms"),
                        _buildSectionBody(
                          "We reserve the right to modify or replace these Terms of Service at any time. We will notify you of any changes by updating the 'Last updated' date at the top of this page.",
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xff1C0D5A),
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xff1C0D5A).withOpacity(0.7),
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}
