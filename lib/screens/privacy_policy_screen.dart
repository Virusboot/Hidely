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
                          "Last updated: July 16, 2026",
                          style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader("1. Information We Collect"),
                        _buildSectionBody(
                          "We collect information that you provide to us directly when creating an account, such as your full name, email address, and account password. Additionally, since Hidely is location-contextual, we collect precise location data with your permission when the app is active.",
                        ),
                        _buildSectionHeader("2. How We Use Information"),
                        _buildSectionBody(
                          "We use the collected information to provide, maintain, and improve the app's services, especially the nearby place discovery and contextual feed. We also use your information to secure your account, prevent fraud, and communicate updates or security alerts to you.",
                        ),
                        _buildSectionHeader("3. Sharing of Information"),
                        _buildSectionBody(
                          "We do not sell or rent your personal or location data to third parties. We may share information with trusted third-party service providers to help run the app (such as database hosting or authentication services), but only under strict data-protection agreements.",
                        ),
                        _buildSectionHeader("4. Location Permissions & Settings"),
                        _buildSectionBody(
                          "You can enable, modify, or disable location sharing at any time through your mobile device's system settings. Please note that disabling location services will significantly limit the features and functionality of Hidely.",
                        ),
                        _buildSectionHeader("5. Data Security"),
                        _buildSectionBody(
                          "We employ industry-standard technical and organizational security measures to protect your personal data from unauthorized access, loss, misuse, or alteration. However, no internet-based data transmission or storage can be guaranteed 100% secure.",
                        ),
                        _buildSectionHeader("6. Your Data Rights"),
                        _buildSectionBody(
                          "Depending on your location, you may have specific legal rights regarding your personal data, including the right to request deletion of your account and personal data, or to obtain a copy of the information we store.",
                        ),
                        _buildSectionHeader("7. Contact Us"),
                        _buildSectionBody(
                          "If you have any questions or feedback about this Privacy Policy, please contact us at support@hidelyapp.com.",
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
