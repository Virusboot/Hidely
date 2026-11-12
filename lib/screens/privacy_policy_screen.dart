import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff1C0D5A).withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                          "Privacy Policy",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            color: Color(0xff1C0D5A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button on the left
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
                          "Privacy Policy",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Last updated: November 2026",
                          style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader("1. Eligibility & Age Limit (18+)"),
                        _buildSectionBody(
                          "Hidely is strictly intended for individuals aged 18 years and older. By creating an account, you confirm that you are an adult aged 18+ under the Digital Personal Data Protection Act, 2023 (DPDP Act). We do not knowingly collect data from minors; any underage account will be suspended and permanently erased.",
                        ),
                        _buildSectionHeader("2. Information We Collect"),
                        _buildSectionBody(
                          "We collect account information you directly provide (name, username, email address, hashed password, and optional bio or gender), content you share (posts, photos, reels, comments, and chat messages), and precise location data only when you grant foreground permission to explore nearby places or geo-tag posts. We do not collect device contacts or track your location in the background.",
                        ),
                        _buildSectionHeader("3. How We Use Information & Processors"),
                        _buildSectionBody(
                          "Your information powers nearby place discovery, user-generated feeds, in-app messaging, moderation/safety enforcement, and OTP verification. We do not sell or rent personal data. Essential processing relies on trusted infrastructure providers (managed database hosting, interactive maps, encrypted peer-to-peer WebRTC signaling for user-initiated audio/video calls, and email OTP delivery) under strict data-protection controls.",
                        ),
                        _buildSectionHeader("4. Permissions & Device Controls"),
                        _buildSectionBody(
                          "Location, Camera, Microphone, and Photo Library access are optional and requested just-in-time. Media EXIF coordinates are read only on user-selected uploads to accurately place your travel posts. You can revoke permissions anytime via your device settings.",
                        ),
                        _buildSectionHeader("5. Child Safety & Zero-Tolerance Policy"),
                        _buildSectionBody(
                          "Hidely enforces zero tolerance against Child Sexual Abuse and Exploitation (CSAE) and harmful or unlawful content. Violating accounts are permanently terminated and reported where required by law. View our Child Safety Standards at /child-safety on our backend domain.",
                        ),
                        _buildSectionHeader("6. Your Data Rights (DPDP Act 2023)"),
                        _buildSectionBody(
                          "You have the right to access, download a machine-readable copy of, correct, or permanently delete your personal data. Use 'Download My Data' or 'Delete Account' inside Settings & Privacy, or submit a web deletion request via /delete-account on our backend domain.",
                        ),
                        _buildSectionHeader("7. Grievance Officer & Contact (IT Rules 2021)"),
                        _buildSectionBody(
                          "General support: support@hidely.app\n"
                          "Grievance & Child Safety Officer: grievance@hidely.app\n"
                          "Under India's IT Rules 2021 and DPDP Act 2023, privacy grievances and safety escalations are acknowledged within 24 hours and resolved within 15 days.",
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
