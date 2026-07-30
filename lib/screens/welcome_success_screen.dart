import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/login_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';

class WelcomeSuccessScreen extends StatefulWidget {
  const WelcomeSuccessScreen({super.key});

  @override
  State<WelcomeSuccessScreen> createState() => _WelcomeSuccessScreenState();
}

class _WelcomeSuccessScreenState extends State<WelcomeSuccessScreen> {
  bool _useDarkIcons = false;

  @override
  void initState() {
    super.initState();
    // Delay switching status bar icons to dark until the screen transition finishes
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) {
        setState(() {
          _useDarkIcons = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _useDarkIcons ? Brightness.dark : Brightness.light,
        statusBarBrightness: _useDarkIcons ? Brightness.light : Brightness.dark,
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
                Color(0xffE0F2FE), // Light sky blue from XML vector
                Color(0xffFDF7FF), // Soft clean lavender tint from XML vector
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenSize.height - MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // --- 1. TOP MARGIN ---
                      const SizedBox(height: 24),

                      // --- 2. CINEMATIC FLOATING IMAGE FRAME (Taller 4:6 Aspect Ratio) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: AspectRatio(
                          aspectRatio: 4 / 5, // Exact 4:5 Aspect Ratio requested
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cardHeight = constraints.maxHeight;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(36),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Perfect scaled valley background asset with defensive fallback
                                      Image.asset(
                                        'assets/images/welcome_success_bg.jpg',
                                        fit: BoxFit.cover,
                                        alignment: const Alignment(0.0, -0.2),
                                        errorBuilder: (context, error, stackTrace) {
                                          return Image.asset(
                                            'assets/images/onboarding_bg.jpg',
                                            fit: BoxFit.cover,
                                            alignment: const Alignment(0.0, -0.2),
                                          );
                                        },
                                      ),

                                      // Subtle internal asset vignette mask
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.15),
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.2),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Floating Target Point Indicator (Purple Circular Dot Ring)
                                      Positioned(
                                        top: cardHeight * 0.40,
                                        left: screenSize.width * 0.22,
                                        child: _buildLocationPulsePoint(),
                                      ),

                                      // Floating Tag 1: PARTENON • 438 BC
                                      Positioned(
                                        top: cardHeight * 0.47,
                                        left: screenSize.width * 0.18,
                                        child: _buildGlassmorphicTag("PARTENON • 438 BC"),
                                      ),

                                      // Floating Tag 2: DORIC COLUMNS
                                      Positioned(
                                        bottom: cardHeight * 0.26,
                                        right: screenSize.width * 0.14,
                                        child: _buildGlassmorphicTag("DORIC COLUMNS"),
                                      ),

                                      // Small camera circular tag anchor on top right
                                      Positioned(
                                        top: cardHeight * 0.35,
                                        right: screenSize.width * 0.12,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.7),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withOpacity(0.9)),
                                          ),
                                          child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.black87),
                                        ),
                                      ),

                                      // --- Bottom Glassmorphic AI Lens Banner Section ---
                                      Positioned(
                                        bottom: 20,
                                        left: 20,
                                        right: 20,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                            child: Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.55),
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.4),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xff4D2CA8),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.auto_awesome,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  const Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          "AI Lens is Ready",
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Color(0xff1C0D5A),
                                                          ),
                                                        ),
                                                        SizedBox(height: 3),
                                                        Text(
                                                          "I've calibrated for your current location in Athens.",
                                                          style: TextStyle(
                                                            fontSize: 12.5,
                                                            color: Colors.black54,
                                                            fontWeight: FontWeight.w400,
                                                            height: 1.25,
                                                          ),
                                                        ),
                                                      ],
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
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // --- 3. BOTTOM CONTENT SEGMENT (Title, Subtitle, CTA Buttons) ---
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),

                              // Restored Original Title style
                              const Text(
                                "You're all set!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xff1C0D5A),
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Restored Original Description style
                              Text(
                                "Your cinematic guide to history is now active. Explore the world's secrets in real-time.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xff1C0D5A).withOpacity(0.65),
                                  fontSize: 15,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const Spacer(),

                              // Primary Action Button: Explore Now (Solid purple design)
                              GestureDetector(
                                onTap: () {
                                  // Guest mode — user has not logged in
                                  AuthService().logout();
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => const MainWrapper(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 800),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff2B1564),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xff2B1564).withOpacity(0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.travel_explore,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Explore Now",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Secondary Action Button: Sign In (Glassy thin outline design)
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: double.infinity,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: const Color(0xff2B1564).withOpacity(0.25),
                                          width: 0.8, // Thin outline
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.login_rounded,
                                            color: Color(0xff2B1564),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "Sign In",
                                            style: TextStyle(
                                              color: Color(0xff2B1564),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 64), // Elevated bottom space
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for location pulse circle icon indicator
  Widget _buildLocationPulsePoint() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xff5D3EBC),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  // Helper Widget for custom tag components
  Widget _buildGlassmorphicTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75), // Perfect matte white translucency match
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xff2B1564), // Matching font styling perfectly
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}