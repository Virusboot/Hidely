import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/main_wrapper.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/creator_profile_screen.dart';

/// Centralized route constants and route map definitions for Web & Mobile.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String map = '/map';
  static const String chat = '/chat';
  static const String explore = '/explore';
  static const String profile = '/profile';
  static const String rank = '/rank';
  static const String create = '/create';
  static const String editProfile = '/edit-profile';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final Uri uri = Uri.parse(settings.name ?? '/');

    // Dynamic Route Parsing
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'profile') {
      final username = uri.pathSegments.last;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CreatorProfileScreen(username: username),
      );
    }

    switch (uri.path) {
      case splash:
        return MaterialPageRoute(settings: settings, builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 0));
      case map:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 1));
      case chat:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 2));
      case explore:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 3));
      case profile:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 4));
      case rank:
        return MaterialPageRoute(settings: settings, builder: (_) => const LeaderboardScreen());
      case create:
        return MaterialPageRoute(settings: settings, builder: (_) => const CreatePostScreen());
      case editProfile:
        return MaterialPageRoute(settings: settings, builder: (_) => const EditProfileScreen());
      default:
        return MaterialPageRoute(settings: settings, builder: (_) => const MainWrapper(initialIndex: 0));
    }
  }

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        home: (context) => const MainWrapper(initialIndex: 0),
        map: (context) => const MainWrapper(initialIndex: 1),
        chat: (context) => const MainWrapper(initialIndex: 2),
        explore: (context) => const MainWrapper(initialIndex: 3),
        profile: (context) => const MainWrapper(initialIndex: 4),
        rank: (context) => const LeaderboardScreen(),
        create: (context) => const CreatePostScreen(),
        editProfile: (context) => const EditProfileScreen(),
      };
}
