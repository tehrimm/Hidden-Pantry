import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassDialog {
  /// A drop-in replacement for standard `showDialog`.
  /// Wraps the underlying dialog in a frosted glass effect and a bouncy 
  /// scale entrance animation.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      // Start with a transparent barrier since we use a BackdropFilter
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        // Unused because we render everything in transitionBuilder
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Stack(
          children: [
            // 1. Fade the blur effect in smoothly
            FadeTransition(
              opacity: anim1,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1), // Gentle darkening
                ),
              ),
            ),
            // 2. Bounce and scale the actual dialog widget
            ScaleTransition(
              scale: CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(
                opacity: anim1,
                child: builder(context),
              ),
            ),
          ],
        );
      },
    );
  }
}
