import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/edit_profile_screen.dart';

/// Centralized route constants and route map definitions.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String editProfile = '/edit-profile';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        editProfile: (context) => const EditProfileScreen(),
      };
}
