import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/splash_screen.dart';
import '../screens/main_wrapper.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/creator_profile_screen.dart';
import '../screens/category_screen.dart';
import '../screens/location_detail_screen.dart';
import '../utils/web_history.dart';

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
  static const String category = '/category';
  static const String place = '/place';

  static String pathForTab(int index) {
    switch (index) {
      case 1:
        return map;
      case 2:
        return chat;
      case 3:
        return explore;
      case 4:
        return profile;
      case 0:
      default:
        return home;
    }
  }

  static int tabForPath(String path) {
    final clean = path.trim().toLowerCase();
    if (clean == '/map' || clean.startsWith('/map')) return 1;
    if (clean == '/chat' || clean.startsWith('/chat')) return 2;
    if (clean == '/explore' || clean.startsWith('/explore')) return 3;
    if (clean == '/profile' || clean.startsWith('/profile')) return 4;
    return 0;
  }

  /// Syncs browser address bar to the current route on web
  static void syncWebUrl(String path) {
    if (kIsWeb) {
      updateBrowserUrl(path);
      saveLastActiveRoute(path);
    }
  }

  /// Persists last active route so refresh always restores the current screen
  static Future<void> saveLastActiveRoute(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hidely_last_active_route', path);
    } catch (_) {}
  }

  static String determineInitialRoute([String? savedRoute]) {
    if (kIsWeb) {
      final browserPath = getBrowserCurrentPath();
      if (browserPath.isNotEmpty && browserPath != '/') {
        return browserPath;
      }
      if (savedRoute != null && savedRoute.isNotEmpty && savedRoute != '/') {
        return savedRoute;
      }
    }
    return home;
  }

  static Route<dynamic> generateRouteFor(String routeName, [Object? arguments]) {
    final String clean = routeName.trim();
    final Uri uri = Uri.parse(clean.isEmpty ? '/' : clean);
    final String path = (uri.path.length > 1 && uri.path.endsWith('/'))
        ? uri.path.substring(0, uri.path.length - 1)
        : (uri.path.isEmpty ? '/' : uri.path);

    final RouteSettings settings = RouteSettings(name: routeName, arguments: arguments);

    // Dynamic Route: /profile/:username
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'profile') {
      final username = uri.pathSegments.last;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CreatorProfileScreen(username: username),
      );
    }

    // Dynamic Route: /category/:name or /category?name=...
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'category') {
      String categoryName = 'Mountains';
      if (uri.pathSegments.length >= 2) {
        categoryName = Uri.decodeComponent(uri.pathSegments[1]);
      } else if (uri.queryParameters.containsKey('name')) {
        categoryName = uri.queryParameters['name']!;
      }
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CategoryScreen(categoryName: categoryName),
      );
    }

    // Dynamic Route: /place or /location
    if (uri.pathSegments.isNotEmpty &&
        (uri.pathSegments.first == 'place' || uri.pathSegments.first == 'location')) {
      final title = uri.queryParameters['title'] ?? (uri.pathSegments.length >= 2 ? Uri.decodeComponent(uri.pathSegments[1]) : 'Hidden Place');
      final location = uri.queryParameters['location'] ?? '';
      final image = uri.queryParameters['image'] ?? 'assets/images/explore_2.png';
      final category = uri.queryParameters['category'] ?? 'Waterfalls';
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => LocationDetailScreen(
          title: title,
          location: location,
          image: image,
          category: category,
        ),
      );
    }

    switch (path) {
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
      case '/leaderboard':
        return MaterialPageRoute(settings: settings, builder: (_) => const LeaderboardScreen());
      case create:
        return MaterialPageRoute(settings: settings, builder: (_) => const CreatePostScreen());
      case editProfile:
        return MaterialPageRoute(settings: settings, builder: (_) => const EditProfileScreen());
      default:
        final tabIndex = tabForPath(path);
        return MaterialPageRoute(settings: settings, builder: (_) => MainWrapper(initialIndex: tabIndex));
    }
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return generateRouteFor(settings.name ?? '/', settings.arguments);
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
