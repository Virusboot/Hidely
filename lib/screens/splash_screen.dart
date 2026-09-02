import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/services.dart';
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
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
                      ],
                    ),
                  ),

                  // Content Column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 5),

                      const Spacer(flex: 2),

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
