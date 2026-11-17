import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hidely_new/screens/onboarding_controller.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/local_storage_service.dart';

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

    try {
      FlutterNativeSplash.remove();
    } catch (_) {}

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

  Future<void> _initializeApp() async {
    try {
      setState(() => _statusMessage = "Loading Hidely...");

      // Initialize core services concurrently
      await Future.wait([
        AuthService().init().timeout(const Duration(seconds: 4), onTimeout: () {
          debugPrint('[Splash] AuthService init timed out');
        }),
        ApiService().init().timeout(const Duration(seconds: 4), onTimeout: () {
          debugPrint('[Splash] ApiService init timed out');
        }),
        LocalStorageService().init().timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint('[Splash] LocalStorage init timed out');
        }),
      ]);

      // Skip splash delay on Web for instantaneous Home load
      if (!kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (!mounted) return;

      final bool isLoggedIn = AuthService().isLoggedIn;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: const RouteSettings(name: "/main"),
          pageBuilder: (context, animation, secondaryAnimation) =>
              (isLoggedIn || kIsWeb) ? const MainWrapper() : const OnboardingController(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return FadeTransition(opacity: curvedAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    } catch (e) {
      debugPrint('[Splash] Initialization error: $e');
      if (mounted) {
        final bool isLoggedIn = AuthService().isLoggedIn;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            settings: const RouteSettings(name: "/main"),
            pageBuilder: (context, animation, secondaryAnimation) =>
                isLoggedIn ? const MainWrapper() : const OnboardingController(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 450),
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
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xff0D0622),
                Color(0xff1C0D5A),
                Color(0xff2B1564),
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
                  // Atmospheric background glowing spheres
                  Positioned(
                    top: -60,
                    right: -60,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff9333EA).withOpacity(0.18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff9333EA).withOpacity(0.25),
                            blurRadius: 90,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff3B82F6).withOpacity(0.12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff3B82F6).withOpacity(0.2),
                            blurRadius: 100,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Logo Emblem & Brand
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glassy glowing emblem card
                        Container(
                          width: 104,
                          height: 104,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff9333EA).withOpacity(0.35),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.explore_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Brand Title
                        Image.asset(
                          'assets/images/logo_horizontal.png',
                          width: 210,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            'HIDELY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0,
                              fontFamily: 'serif',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Tagline
                        Text(
                          'CINEMATIC TRAVEL & DISCOVERY',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Loading & Status
                  Positioned(
                    left: 40,
                    right: 40,
                    bottom: 40,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Subtle smooth progress indicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 3,
                            width: 140,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xffA855F7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
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
    );
  }
}
