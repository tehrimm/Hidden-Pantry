import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A full-screen premium glassmorphic background widget.
/// Renders the branded LinearGradient, animated floating orbs,
/// and the decorative stroke ellipses used across the entire app.
/// Drop this as the first child in any Stack to instantly modernise a screen.
class PatternBackground extends StatefulWidget {
  final double opacity;
  const PatternBackground({super.key, this.opacity = 1.0});

  @override
  State<PatternBackground> createState() => _PatternBackgroundState();
}

class _PatternBackgroundState extends State<PatternBackground>
    with TickerProviderStateMixin {
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;

  @override
  void initState() {
    super.initState();
    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseW = 393.0;
    const baseH = 852.0;
    final size = MediaQuery.of(context).size;
    double sx(double v) => v * (size.width / baseW);
    double sy(double v) => v * (size.height / baseH);

    const stroke = Color(0xFFF5DDCE);

    return Opacity(
      opacity: widget.opacity,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 1. Branded gradient fill ──────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ── 2. Top-right animated orb ─────────────────────────────────
            Positioned(
              top: sy(-100),
              right: sx(-100),
              child: AnimatedBuilder(
                animation: _orb1Controller,
                builder: (_, __) {
                  final angle = _orb1Controller.value * 2 * math.pi;
                  return Transform.translate(
                    offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
                    child: Container(
                      width: sx(400),
                      height: sx(400),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFE0D3).withValues(alpha: 0.5),
                            const Color(0xFFFFE0D3).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── 3. Bottom-left animated orb ───────────────────────────────
            Positioned(
              bottom: sy(100),
              left: sx(-150),
              child: AnimatedBuilder(
                animation: _orb2Controller,
                builder: (_, __) {
                  final angle = _orb2Controller.value * 2 * math.pi;
                  return Transform.translate(
                    offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
                    child: Container(
                      width: sx(500),
                      height: sx(500),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFEF8A54).withValues(alpha: 0.10),
                            const Color(0xFFEF8A54).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── 4. Decorative stroke ellipses (original pattern) ──────────
            Positioned(
              left: sx(-154),
              top: sy(-14),
              child: Transform.rotate(
                angle: 21 * math.pi / 180,
                child: Container(
                  width: sx(271),
                  height: sy(159),
                  decoration: BoxDecoration(
                    border: Border.all(color: stroke),
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(sx(136), sy(80)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: sx(-149),
              top: sy(-100),
              child: Transform.rotate(
                angle: 4 * math.pi / 180,
                child: Container(
                  width: sx(303),
                  height: sy(329),
                  decoration: BoxDecoration(
                    border: Border.all(color: stroke),
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(sx(152), sy(165)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
