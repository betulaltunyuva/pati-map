import 'package:flutter/material.dart';

/// Web panel responsive kirilimlari (400 / 768 / 1024).
abstract final class PanelResponsive {
  static const double narrowMax = 480;
  static const double mobileMax = 768;
  static const double tabletMax = 1024;
  static const double sidebarMin = 980;

  static bool isNarrow(double width) => width < narrowMax;
  static bool isMobile(double width) => width < mobileMax;
  static bool isTablet(double width) => width < tabletMax;
  static bool useSidebar(double width) => width >= sidebarMin;

  static EdgeInsets pagePadding(double width) {
    if (isNarrow(width)) {
      return const EdgeInsets.fromLTRB(12, 14, 12, 20);
    }
    if (isMobile(width)) {
      return const EdgeInsets.fromLTRB(16, 16, 16, 22);
    }
    return const EdgeInsets.fromLTRB(28, 20, 28, 30);
  }

  static double ofWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;
}
