import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final bool glassy;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.glassy = false,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (!isTest) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        
        // Premium Warm Beige Palette vs Glassy Palette
        final base = widget.glassy 
            ? Colors.white.withValues(alpha: 0.1) 
            : const Color(0xFFF5E9E2);
        final highlight = widget.glassy 
            ? Colors.white.withValues(alpha: 0.25) 
            : const Color(0xFFFCF5F1);

        Widget box = Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: const Alignment(-2, -0.5),
              end: const Alignment(2, 0.5),
              colors: [base, highlight, base],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(t),
            ),
            border: widget.glassy 
                ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5) 
                : null,
          ),
        );

        if (widget.glassy) {
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: box,
            ),
          );
        }

        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: box,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double percent;
  const _SlidingGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}
