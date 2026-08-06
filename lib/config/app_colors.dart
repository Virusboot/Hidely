import 'package:flutter/material.dart';

/// Centralized color palette for the Hidely application.
class AppColors {
  AppColors._();

  // Primary Branding Colors
  static const Color primary = Color(0xff2B1564);
  static const Color primaryDark = Color(0xff1C0D5A);
  static const Color primaryLight = Color(0xff432C81);
  static const Color accent = Color(0xff4F46E5);
  static const Color accentBlue = Color(0xff2563EB);

  // Background & Surface Colors
  static const Color background = Color(0xffF6F9FC);
  static const Color surface = Colors.white;
  static const Color cardBg = Color(0xffFAFAFA);
  static const Color chipBg = Color(0xffEFEFEF);
  static const Color divider = Color(0xffE2E8F0);

  // Text & Content Colors
  static const Color textPrimary = Color(0xff1C0D5A);
  static const Color textSecondary = Color(0xff4A457A);
  static const Color textMuted = Color(0xff8E8AA0);
  static const Color textHint = Colors.black38;

  // Status & Utility Colors
  static const Color success = Color(0xff059669);
  static const Color warning = Color(0xffB25E00);
  static const Color error = Color(0xffEF4444);
  static const Color info = Color(0xff3B82F6);
}
