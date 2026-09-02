import 'package:flutter/material.dart';

/// Responsive Breakpoint Manager & Utilities for Hidely Platform
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static const double mobileMax = 767.0;
  static const double tabletMax = 1023.0;
  static const double desktopMax = 1439.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > mobileMax && w <= tabletMax;
  }

  static bool isDesktop(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > tabletMax && w <= desktopMax;
  }

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > desktopMax;

  static bool isDesktopOrTablet(BuildContext context) =>
      MediaQuery.of(context).size.width > mobileMax;
}

/// Helper wrapper to center content and restrict max width on large screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 640.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
