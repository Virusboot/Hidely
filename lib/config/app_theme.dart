import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Centralized ThemeData builder for Hidely application.
class AppTheme {
  AppTheme._();

  static const String fontName = 'Inter';

  static ThemeData get lightTheme {
    final baseTypography = Typography.material2021(platform: defaultTargetPlatform);
    final textTheme = baseTypography.black.apply(
      fontFamily: fontName,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      fontFamily: fontName,
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      typography: Typography.material2021(
        platform: defaultTargetPlatform,
        black: textTheme,
        white: baseTypography.white.apply(fontFamily: fontName),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.primaryDark),
        titleTextStyle: TextStyle(
          fontFamily: fontName,
          color: AppColors.primaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
