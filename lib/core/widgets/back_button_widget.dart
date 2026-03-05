import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.maybePop(context),
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9E3D5),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: color ?? const Color(0xFF462F4D),
        ),
      ),
    );
  }
}



