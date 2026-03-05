import 'package:flutter/material.dart';

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

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/bg/nav_bar.png",
              fit: BoxFit.fill,
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(left: 30, right: 30, bottom: 14),
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
                    active: "assets/icons/Search_active.png",
                    inactive: "assets/icons/search_inactive.png",
                  ),
                  const SizedBox(width: 48), // space for plus
                  _navIcon(
                    index: 3,
                    active: "assets/icons/Bookmark_active.png",
                    inactive: "assets/icons/Bookmark_inactive.png",
                  ),

                  // Nutritionist tab
                  isNutritionistInUserView
                      ? _expertIcon()
                      : _navIcon(
                          index: 4,
                          active: "assets/icons/User_active.png",
                          inactive: "assets/icons/User_inactive.png",
                        ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 4,
            right: 0,
            bottom: 40,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/icons/Plus.png",
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
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
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 48,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              isActive ? active : inactive,
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: isActive ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  border: Border.all(width: 1.6, color: orange),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expertIcon() {
    const index = 4;
    final isActive = currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 48,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              "assets/icons/User_inactive.png",
              width: 24, // Consistent icon size
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: isActive ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  border: Border.all(width: 1.6, color: orange),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



