import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

bool get isRunningTest => WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

class StaggeredEntry extends StatefulWidget {
  final Widget child;
  final int delay;

  const StaggeredEntry({super.key, required this.child, required this.delay});

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry> {
  bool _start = false;

  @override
  void initState() {
    super.initState();
    if (isRunningTest) {
      _start = true;
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) setState(() => _start = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      scale: _start ? 1.0 : 0.95,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        opacity: _start ? 1.0 : 0.0,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 30.sh, end: 0.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, _start ? 0 : value),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class HeartBurst extends StatefulWidget {
  final bool isLiked;
  final Widget child;

  const HeartBurst({super.key, required this.isLiked, required this.child});

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
    ]).animate(_controller);

    _burstAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(HeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _controller.forward(from: 0.0);
    } else if (!widget.isLiked) {
      _controller.reverse(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _burstAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: BurstPainter(
                progress: _burstAnimation.value,
                color: Colors.red.withValues(alpha: 0.5),
              ),
              size: Size(50.sw, 50.sw),
            );
          },
        ),
        ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ],
    );
  }
}

class DownloadAnimatedIcon extends StatefulWidget {
  final bool isDownloaded;
  final Widget child;

  const DownloadAnimatedIcon({super.key, required this.isDownloaded, required this.child});

  @override
  State<DownloadAnimatedIcon> createState() => _DownloadAnimatedIconState();
}

class _DownloadAnimatedIconState extends State<DownloadAnimatedIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(DownloadAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDownloaded != oldWidget.isDownloaded) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (_controller.isAnimating && widget.isDownloaded)
              CustomPaint(
                painter: DownloadLinePainter(progress: _slideAnimation.value),
                size: Size(30.sw, 30.sw),
              ),
            ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class BookmarkAnimatedIcon extends StatefulWidget {
  final bool isBookmarked;
  final Widget child;

  const BookmarkAnimatedIcon({super.key, required this.isBookmarked, required this.child});

  @override
  State<BookmarkAnimatedIcon> createState() => _BookmarkAnimatedIconState();
}

class _BookmarkAnimatedIconState extends State<BookmarkAnimatedIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(BookmarkAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBookmarked != oldWidget.isBookmarked) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class DownloadLinePainter extends CustomPainter {
  final double progress;

  DownloadLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF8A54).withValues(alpha: (1 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.sw
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final double startY = center.dy - 10.sh + (20.sh * progress);
    final double endY = startY + 5.sh;

    canvas.drawLine(Offset(center.dx - 8.sw, startY), Offset(center.dx - 8.sw, endY), paint);
    canvas.drawLine(Offset(center.dx + 8.sw, startY + 2.sh), Offset(center.dx + 8.sw, endY + 2.sh), paint);
  }

  @override
  bool shouldRepaint(DownloadLinePainter oldDelegate) => oldDelegate.progress != progress;
}

class BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;

    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress))
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * progress;
    
    final ringPaint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.sw * (1 - progress);
    
    canvas.drawCircle(center, radius * 1.8, ringPaint);

    for (int i = 0; i < 8; i++) {
        double angle = i * 45 * 3.14159 / 180;
        double dist = radius * 1.6;
        canvas.drawCircle(
          Offset(center.dx + dist * 0.8 * (i < 4 ? 1 : -1) * (i == 0 || i == 4 ? 1 : 0.7), 
                 center.dy + dist * 0.8 * (i % 3 == 0 ? 1.0 : -0.8) * (i == 2 || i == 6 ? 1 : 0.7)),
          3.sw * (1 - progress),
          paint
        );
    }
  }

  @override
  bool shouldRepaint(BurstPainter oldDelegate) => oldDelegate.progress != progress;
}
