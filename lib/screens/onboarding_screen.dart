import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/welcome_success_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _pages = [
    {
      "title": "Cinematography",
      "description": "We handle both music and video production to make your sound and visuals pop.",
      "image": "assets/images/onboarding_1.jpg",
    },
    {
      "title": "Romantic Escapes",
      "description": "Discover picturesque streetscapes, classical art, and romantic cafes across Europe.",
      "image": "assets/images/onboarding_2.jpg",
    },
    {
      "title": "Cultural Journeys",
      "description": "Explore the ancient traditions, spiritual ghats, and vibrant festivals of India.",
      "image": "assets/images/onboarding_3.jpg",
    },
  ];

  void _onNextPressed() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeSuccessScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White status bar icons on Android
        statusBarBrightness: Brightness.dark,      // White status bar icons on iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // --- 1. SMOOTH CROSS-FADING BACKGROUND IMAGES ---
            ...List.generate(_pages.length, (index) {
              final bool isActive = index == _currentIndex;
              return Positioned.fill(
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOut,
                  child: Image.asset(
                    _pages[index]["image"]!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              );
            }),

            // Dark overlay to match mockup's high-contrast dark aesthetic
            Container(
              color: Colors.black.withOpacity(0.55),
            ),

            // --- 2. SWIPEABLE CONTENT VIEW ---
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    child: Column(
                      children: [
                        const Spacer(),

                        // Text container that will slide with the finger swipe
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Serif Italic Title matching mockup
                            Text(
                              page["title"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontFamily: 'serif',
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Subtitle/Description text
                            Text(
                              page["description"]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 156),
                      ],
                    ),
                  ),
                );
              },
            ),

            // --- 3. FIXED OVERLAYS (Logo, Indicator, and Next Button) ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  children: [
                    // --- 3.1 FIXED TOP BRANDING LOGO ---
                    const SizedBox(height: 50),
                    IgnorePointer(
                      child: Image.asset(
                        'assets/images/logo_horizontal.png',
                        width: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text(
                          'HIDELY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // --- 3.2 FIXED INDICATOR DOTS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) {
                        final bool isSelected = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isSelected ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 40),

                    // --- 3.3 FIXED SOLID WHITE "NEXT" BUTTON ---
                    GestureDetector(
                      onTap: _onNextPressed,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Next",
                          style: TextStyle(
                            color: Color(0xff2B1564),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}