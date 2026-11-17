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

  @override
  void initState() {
    super.initState();

    // Dismiss native splash seamlessly on the first Flutter frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
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

      // Smooth brief delay on mobile for graceful logo presentation
      if (!kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 700));
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
          transitionDuration: const Duration(milliseconds: 400),
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
            transitionDuration: const Duration(milliseconds: 400),
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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
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
            child: Image.asset(
              'assets/images/splash_logo.png',
              width: 320,
              height: 320,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/logo_horizontal_color.png',
                width: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
