import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class BackButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const BackButtonWidget({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.maybePop(context),
      child: Container(
        width: 50.sw,
        height: 50.sw,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9E3D5),
          borderRadius: BorderRadius.circular(25.sw),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 18.sp,
          color: color ?? const Color(0xFF462F4D),
        ),
      ),
    );
  }
}



