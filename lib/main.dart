import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/config/config.dart';
import 'package:hidely_new/services/notification_polling_service.dart';

import 'package:hidely_new/widgets/something_went_wrong_screen.dart';

import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/deep_link_service.dart';
import 'package:hidely_new/utils/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dismiss native splash screen immediately so Android 12+ never gets stuck
  try {
    FlutterNativeSplash.remove();
  } catch (e) {
    debugPrint('[main] FlutterNativeSplash remove error: $e');
  }

  // Global Error Handling & Custom Error Screen (>99.5% Crash Free Target)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter UI Error: ${details.exception}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SomethingWentWrongScreen();
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught Platform/Async Error: $error');
    return true; // Prevents crash
  };

  // Configure HTML5 path URL strategy on Web
  configureUrlStrategy();

  // Load saved auth session & token from SharedPreferences before UI mounts (safe timeout)
  try {
    await AuthService().init().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('[main] AuthService init timed out - continuing startup');
      },
    );
  } catch (e) {
    debugPrint('[main] AuthService init error: $e');
  }

  String? savedRoute;
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
    );
    savedRoute = prefs.getString('hidely_last_active_route');
  } catch (e) {
    debugPrint('[main] SharedPreferences error: $e');
  }

  final initialRoute = AppRoutes.determineInitialRoute(savedRoute);

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Non-blocking initialization for < 2 sec app startup
  DeepLinkService();
  NotificationPollingService().initialize().catchError((e) {
    debugPrint("Background Notification Polling init error: $e");
  });

  runApp(
    ProviderScope(
      child: HidelyApp(initialRoute: initialRoute),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class HidelyApp extends StatelessWidget {
  final String initialRoute;
  const HidelyApp({super.key, this.initialRoute = AppRoutes.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Hidely — Social Places Discovery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (String initialRouteName) {
        return [
          AppRoutes.generateRouteFor(initialRouteName),
        ];
      },
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final constrainedTextScaler = mediaQueryData.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.25,
        );
        return MediaQuery(
          data: mediaQueryData.copyWith(textScaler: constrainedTextScaler),
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}