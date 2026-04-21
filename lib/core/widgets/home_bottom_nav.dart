import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class HpBottomNav extends StatelessWidget {
  const HpBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.orange,
    this.isNutritionistInUserView = false,
  });

  final int currentIndex; // 0 home, 1 search, 2 plus, 3 bookmark, 4 nutritionist
  final ValueChanged<int> onTap;
  final Color orange;
  final bool isNutritionistInUserView;

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    const Color brandPurple = Color(0xFF462F4D);

    return SizedBox(
      height: 90.sh,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // MAIN NAV BAR BACKGROUND (NOTCHED)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(double.infinity, 70.sh),
              painter: _NotchedNavPainter(
                color: brandPurple,
                notchRadius: 38.sw,
              ),
            ),
          ),

          // ICONS ROW
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 70.sh,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.sw),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _navIcon(
                      index: 0,
                      active: "assets/icons/home_active.png",
                      inactive: "assets/icons/home_inactive.png",
                    ),
                    _navIcon(
                      index: 1,
                      active: "assets/icons/search_active.png",
                      inactive: "assets/icons/search_inactive.png",
                    ),

                    SizedBox(width: 60.sw), // space for FAB notch

                    _navIcon(
                      index: 3,
                      active: "assets/icons/bookmark_active.png",
                      inactive: "assets/icons/bookmark_inactive.png",
                    ),

                    isNutritionistInUserView
                        ? _expertIcon()
                        : _navIcon(
                            index: 4,
                            active: "assets/icons/user_active.png",
                            inactive: "assets/icons/user_inactive.png",
                          ),
                  ],
                ),
              ),
            ),
          ),

          // FLOATING PLUS BUTTON
          Positioned(
            bottom: 35.sh,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 60.sw,
                height: 60.sw,
                decoration: BoxDecoration(
                  color: orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: orange.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    "assets/icons/plus.png",
                    width: 24.sw,
                    height: 24.sw,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIcon({
    required int index,
    required String active,
    required String inactive,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            isActive ? active : inactive,
            width: 24.sw,
            height: 24.sw,
            fit: BoxFit.contain,
            // If the icons were dark, they might need color tuning for purple bg
            // But usually active icons are colorful/white.
          ),
          SizedBox(height: 6.sh),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 6.sw,
            height: 6.sw,
            decoration: BoxDecoration(
              color: isActive ? orange : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expertIcon() {
    final isActive = currentIndex == 4;

    return GestureDetector(
      onTap: () => onTap(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/icons/user_inactive.png", // Or expert icon if exists
            width: 24.sw,
            height: 24.sw,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 6.sh),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 6.sw,
            height: 6.sw,
            decoration: BoxDecoration(
              color: isActive ? orange : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchedNavPainter extends CustomPainter {
  final Color color;
  final double notchRadius;

  _NotchedNavPainter({required this.color, required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final topRadius = 20.sw;
    final path = Path();
    
    // Start at bottom left
    path.moveTo(0, size.height);
    
    // Line up to top left corner start
    path.lineTo(0, topRadius);
    
    // Top left curve
    path.quadraticBezierTo(0, 0, topRadius, 0);
    
    // Line to notch start
    final notchCenter = size.width / 2;
    // Tightened the transition for a 'closer' notch feel
    final transitionWidth = notchRadius * 1.3;
    final notchStart = notchCenter - transitionWidth;
    final notchEnd = notchCenter + transitionWidth;
    
    path.lineTo(notchStart, 0);
    
    // SMOOTH S-CURVE NOTCH (Deepened and narrowed)
    final dipDepth = notchRadius * 1.15;
    path.cubicTo(
      notchCenter - notchRadius * 0.9, 0,
      notchCenter - notchRadius * 0.7, dipDepth,
      notchCenter, dipDepth,
    );
    path.cubicTo(
      notchCenter + notchRadius * 0.7, dipDepth,
      notchCenter + notchRadius * 0.9, 0,
      notchEnd, 0,
    );
    
    // Line to top right corner start
    path.lineTo(size.width - topRadius, 0);
    
    // Top right curve
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);
    
    // Line to bottom right
    path.lineTo(size.width, size.height);
    
    // Close path
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 8.0, true);
    
    // Draw background
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



