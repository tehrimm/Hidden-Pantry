import 'package:flutter/material.dart';

class FoodLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const FoodLoader({
    super.key,
    this.size = 50,
    this.color,
  });

  @override
  State<FoodLoader> createState() => _FoodLoaderState();
}

class _FoodLoaderState extends State<FoodLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _index = 0;

  final shapes = [
    FoodShape.carrot,
    FoodShape.lettuce,
    FoodShape.apple,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          await Future.delayed(const Duration(milliseconds: 200)); // pause

          _controller.reset();
          setState(() {
            _index = (_index + 1) % shapes.length;
          });
          _controller.forward();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFFEF8A54);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _FoodPainter(
            shape: shapes[_index],
            progress: _controller.value,
            color: color,
          ),
        );
      },
    );
  }
}
enum FoodShape { carrot, lettuce, apple }

class _FoodPainter extends CustomPainter {
  final FoodShape shape;
  final double progress;
  final Color color;

  _FoodPainter({
    required this.shape,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = _getPath(size);

    final metric = path.computeMetrics().first;

    final extract = metric.extractPath(
      0,
      metric.length * progress,
    );

    canvas.drawPath(extract, paint);
  }

  Path _getPath(Size size) {
    switch (shape) {
      case FoodShape.carrot:
        return _carrot(size);
      case FoodShape.lettuce:
        return _lettuce(size);
      case FoodShape.apple:
        return _apple(size);
    }
  }

  // 🥕 CARROT (single stroke path)
  Path _carrot(Size s) {
    final w = s.width;
    final h = s.height;

    return Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..quadraticBezierTo(w * 0.8, h * 0.3, w * 0.5, h * 0.9)
      ..quadraticBezierTo(w * 0.2, h * 0.3, w * 0.5, h * 0.1)
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.4, h * 0.0)
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.6, h * 0.0);
  }

  // 🥬 LETTUCE (wavy)
  Path _lettuce(Size s) {
    final w = s.width;
    final h = s.height;

    final path = Path();
    path.moveTo(w * 0.1, h * 0.5);

    for (int i = 0; i < 6; i++) {
      final x = w * (0.1 + i * 0.15);
      final y = (i % 2 == 0) ? h * 0.3 : h * 0.7;

      path.quadraticBezierTo(x, y, x + w * 0.15, h * 0.5);
    }

    return path;
  }

  // 🍎 APPLE (continuous loop)
  Path _apple(Size s) {
    final w = s.width;
    final h = s.height;

    return Path()
      ..moveTo(w * 0.5, h * 0.2)
      ..cubicTo(w * 0.9, h * 0.1, w * 0.9, h * 0.8, w * 0.5, h * 0.85)
      ..cubicTo(w * 0.1, h * 0.8, w * 0.1, h * 0.1, w * 0.5, h * 0.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}