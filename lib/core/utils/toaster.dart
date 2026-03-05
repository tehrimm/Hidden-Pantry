import 'package:flutter/material.dart';

class Toaster {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final Color bgColor = const Color(0xFFF9E3D5);
    final Color textColor = const Color(0xFF462F4D);
    final Color orange = const Color(0xFFEF8A54);

    final mediaQuery = MediaQuery.of(context);
    final scaffoldHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    // ensure margin doesn't push the snackbar off the top of the short scaffold
    final safeBottomMargin = (scaffoldHeight - 120).clamp(0.0, mediaQuery.size.height);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red : orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Satoshi",
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: safeBottomMargin,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
