import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidely_new/config/config.dart';
import 'package:hidely_new/services/notification_polling_service.dart';

import 'package:hidely_new/widgets/something_went_wrong_screen.dart';

import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/deep_link_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved auth session & token from SharedPreferences before UI mounts
  await AuthService().init();

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
    const ProviderScope(
      child: HidelyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HidelyApp extends StatelessWidget {
  const HidelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hidely — Social Places Discovery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.home,
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