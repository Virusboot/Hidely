import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/onboarding_controller.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/local_storage_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusMessage = "Loading cinematic world...";

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestAllPermissions() async {
    // Request all required permissions at once on first launch
    final statuses = await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    // Check if location was permanently denied — guide user to settings
    if (statuses[Permission.location] == PermissionStatus.permanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Location Required",
              style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Hidely needs location access to show hidden wonders near you. Please enable it in App Settings.",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Later", style: TextStyle(color: Colors.black54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2B1564),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text("Open Settings"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // 0. Request all permissions upfront on first launch
      await _requestAllPermissions();

      // 1. Initialize Auth Session
      setState(() => _statusMessage = "Restoring session...");
      await AuthService().init().timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint('[Splash] AuthService init timed out');
      });

      // 2. Initialize API Service
      if (!mounted) return;
      setState(() => _statusMessage = "Connecting to universe...");
      await ApiService().init().timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint('[Splash] ApiService init timed out');
      });

      // 3. Initialize Local Storage (Isar Database)
      if (!mounted) return;
      setState(() => _statusMessage = "Syncing local database...");
      final localStorageService = LocalStorageService();
      await localStorageService.init().timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[Splash] LocalStorage init timed out');
      });

      // Wait a fraction of a second to show loaded state for smooth transition
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      final bool isLoggedIn = AuthService().isLoggedIn;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              isLoggedIn ? const MainWrapper() : const OnboardingController(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      debugPrint('[Splash] Initialization error: $e');
      // If error occurs, fallback immediately to prevent app blocking
      if (mounted) {
        final bool isLoggedIn = AuthService().isLoggedIn;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isLoggedIn ? const MainWrapper() : const OnboardingController(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff2B1564), // Deep Purple
                Color(0xff1C0D5A), // Extremely Dark Blue/Violet
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Beautiful soft ambient glow in the center background
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff9333EA).withOpacity(0.15),
                        // Soft blur to act as background light
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff9333EA).withOpacity(0.2),
                            blurRadius: 100,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content Column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Logo / Brand Name
                      Image.asset(
                        'assets/images/logo_horizontal.png',
                        width: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text(
                          'HIDELY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.5,
                            fontFamily: 'serif',
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Sleek Cinematic Progress Spinner
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Status Info Label
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const Spacer(flex: 3),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
