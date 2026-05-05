import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? contentText;
  final List<Widget>? actions;
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color bg = const Color(0xFFFFF3EB);

  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.contentText,
    this.actions,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    String? contentText,
    List<Widget>? actions,
  }) {
    return GlassDialog.show<T>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: content,
        contentText: contentText,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.sw)),
      title: Text(
        title,
        style: TextStyle(
          color: purple,
          fontSize: 20.sp,
          fontWeight: FontWeight.w900,
          fontFamily: "Satoshi",
        ),
      ),
      content: content ?? (contentText != null 
        ? Text(
            contentText!,
            style: TextStyle(
              color: purple.withValues(alpha: 0.7),
              fontSize: 14.sp,
              fontFamily: "Satoshi",
            ),
          ) 
        : null),
      actionsPadding: EdgeInsets.only(right: 16.sw, bottom: 16.sh, left: 16.sw),
      actions: actions ?? [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: TextStyle(color: purple.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
