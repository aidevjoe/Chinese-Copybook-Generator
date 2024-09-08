import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  static bool isPhone(BuildContext context) {
    final data = MediaQuery.of(context);
    return data.size.shortestSide < 600 && data.devicePixelRatio > 2.0;
  }

  static bool isTablet(BuildContext context) {
    final data = MediaQuery.of(context);
    return data.size.shortestSide >= 600 && data.size.shortestSide < 900;
  }

  static bool isDesktop(BuildContext context) {
    final data = MediaQuery.of(context);
    return data.size.shortestSide >= 900;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isPhone(context)) {
          return mobile;
        } else if (isTablet(context)) {
          return tablet;
        } else {
          return desktop;
        }
      },
    );
  }
}
