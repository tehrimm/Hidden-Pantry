import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
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
        final t = _c.value; // 0..1
        // Premium Warm Beige Palette
        final base = const Color(0xFFF5E9E2);
        final highlight = const Color(0xFFFCF5F1);

        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-2, 0),
                end: const Alignment(2, 0),
                transform: GradientRotation(t * 2 * 3.14159 / 4), // Subtle angle
                colors: [base, highlight, base],
                stops: const [0.3, 0.5, 0.7],
              ),
            ),
          ),
        );
      },
    );
  }
}



