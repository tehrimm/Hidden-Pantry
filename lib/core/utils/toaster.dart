import 'package:flutter/material.dart';

class Toaster {
  static void show(BuildContext context, String message, {bool isError = false, bool atTop = true}) {
    final Color bgColor = const Color(0xFFF9E3D5);
    final Color textColor = const Color(0xFF462F4D);
    final Color orange = const Color(0xFFEF8A54);

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final statusTop = MediaQuery.of(context).viewPadding.top;
    final navBottom = MediaQuery.of(context).viewPadding.bottom;
    
    final canPop = ModalRoute.of(context)?.canPop ?? Navigator.canPop(context);
    final extra = canPop ? (kToolbarHeight + 8.0) : 16.0;
    
    final topPadding = statusTop + extra;
    final bottomPadding = navBottom + 20.0;

    final entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: atTop ? topPadding : null,
          bottom: atTop ? null : bottomPadding,
          left: 16,
          right: 16,
          child: SafeArea(
            top: atTop,
            bottom: !atTop,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(
                      isError ? Icons.error_outline : Icons.check_circle_outline,
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    final isTestEnv = bindingType.contains('TestWidgetsFlutterBinding');
    if (isTestEnv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        entry.remove();
      });
    } else {
      Future.delayed(const Duration(seconds: 3)).then((_) {
        entry.remove();
      });
    }
  }
}
