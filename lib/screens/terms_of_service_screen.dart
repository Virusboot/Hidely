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
                          "Terms of Service",
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
                          "Last updated: November 2026",
                          style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSectionHeader("1. Acceptance & 18+ Eligibility"),
                        _buildSectionBody(
                          "Welcome to Hidely. By creating an account or using Hidely, you confirm that you are at least 18 years old and agree to be bound by these Terms of Service and our Privacy Policy.",
                        ),
                        _buildSectionHeader("2. User Accounts & Security"),
                        _buildSectionBody(
                          "You are responsible for safeguarding your account password and for all activities under your account. Changing or resetting your password automatically revokes older active login tokens.",
                        ),
                        _buildSectionHeader("3. Community Conduct & Zero-Tolerance Safety"),
                        _buildSectionBody(
                          "Hidely strictly prohibits unlawful, defamatory, harassing, hateful, explicit, fraudulent, or misleading content, as well as Child Sexual Abuse and Exploitation (CSAE) in any form. You can report content/users or block any account immediately in-app. Verified safety and CSAE reports are acted upon within 24 hours, including permanent content removal and account termination.",
                        ),
                        _buildSectionHeader("4. Points, Badges & Non-Monetary Features"),
                        _buildSectionBody(
                          "Hidely Points (XP), daily streaks, ranks, and explorer badges are strictly gamified engagement indicators. They hold zero monetary, cash, wallet, or prepaid instrument value and cannot be exchanged, redeemed, sold, or converted into INR or any currency.",
                        ),
                        _buildSectionHeader("5. Local Explorers Directory (Preview)"),
                        _buildSectionBody(
                          "The Local Explorers section is currently an informational feature preview only. Hidely does not collect booking fees, process payments, endorse guides, or act as a travel payment aggregator inside the app.",
                        ),
                        _buildSectionHeader("6. Location Sharing & Intellectual Property"),
                        _buildSectionBody(
                          "Foreground location sharing is activated only with your permission. All original Hidely trademarks, UI designs, and software remain the exclusive property of Hidely and its licensors.",
                        ),
                        _buildSectionHeader("7. Grievance Redressal & Limitation of Liability"),
                        _buildSectionBody(
                          "Hidely is provided on an 'as-is' basis. These Terms are governed by the laws of India. For support contact support@hidely.app. For takedown, safety, or IT Rules 2021 / DPDP Act 2023 grievances, email grievance@hidely.app (24-hour acknowledgment; 15-day resolution).",
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
