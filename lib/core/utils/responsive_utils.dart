import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double screenWidth = 393.0;
  static double screenHeight = 852.0;
  static double wScale = 1.0;
  static double hScale = 1.0;
  static TextScaler textScaler = TextScaler.noScaling;
  static double maxBottomPadding = 0.0; // Cached to prevent keyboard shrinking bugs

  // Design dimensions (e.g., iPhone 14)
  static const double designWidth = 393.0;
  static const double designHeight = 852.0;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    screenWidth = mq.size.width;
    screenHeight = mq.size.height;

    wScale = (screenWidth / designWidth).clamp(0.95, 2.0);
    hScale = (screenHeight / designHeight).clamp(0.95, 2.0);
    textScaler = mq.textScaler;

    // Cache the bottom padding only when the keyboard is completely closed.
    // Samsung/Android devices shrink viewPadding/padding to 0 when the keyboard opens,
    // and some skins report garbage values. By only updating when viewInsets.bottom is 0,
    // we get the true, stable bottom system safe area and lock it during keyboard display.
    final isKeyboardClosed = mq.viewInsets.bottom == 0;
    if (isKeyboardClosed) {
      maxBottomPadding = mq.viewPadding.bottom;
    }
  }

  /// Scale width based on design width
  static double sw(double width) => width * wScale;

  /// Scale height based on design height
  static double sh(double height) => height * hScale;

  /// Scale font size using width scale and text scaler
  static double sp(double fontSize) => textScaler.scale(fontSize * wScale);

  /// Get vertical spacing based on scaled height
  static double vSpace(double height) => height * hScale;

  /// Get horizontal spacing based on scaled width
  static double hSpace(double width) => width * wScale;

  /// Check if the screen is small (e.g., mobile)
  static bool isSmallScreen() => screenWidth < 600;

  /// Check if the screen is a tablet
  static bool isTablet() => screenWidth >= 600 && screenWidth < 1200;

  /// Check if the screen is large (e.g., desktop)
  static bool isLargeScreen() => screenWidth >= 1200;
}

/// Extension for easy access to responsive dimensions
extension ResponsiveExtension on num {
  double get sw => ResponsiveUtils.sw(toDouble());
  double get sh => ResponsiveUtils.sh(toDouble());
  double get sp => ResponsiveUtils.sp(toDouble());
}
