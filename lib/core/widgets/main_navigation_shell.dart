import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/screens/home/home_screen.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_dashboard.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  bool _isNutritionist = false;

  @override
  void initState() {
    super.initState();
    _checkNutritionist();
    debugPrint('[MainNavigationShell] Initialized with index $_currentIndex');
  }

  Future<void> _checkNutritionist() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) {
      setState(() => _isNutritionist = isNutr);
    }
  }

  void _onTap(int index) async {
    debugPrint('[MainNavigationShell] Tab tapped: $index');
    if (index == 2) {
      // Plus button (Upload) usually opens a full screen flow
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      );
      return;
    }

    if (index == 4 && _isNutritionist) {
      debugPrint('[MainNavigationShell] Switching to Nutritionist Dashboard');
      await ViewModeService().setUserView(false);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const NutritionistDashboard()),
        (route) => false,
      );
      return;
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final Color orange = const Color(0xFFEF8A54);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      extendBody: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.4, 1.0],
              ),
            ),
          ),
          
          // Decorative Orbs for premium feel (Consistency with Nutritionist Dashboard)
          const _ShellBackgroundPattern(),

          IndexedStack(
            index: _currentIndex,
            children: const [
              HomeScreen(inShell: true),
              SearchScreen(inShell: true),
              SizedBox.shrink(), // Placeholder for plus button slot (index 2)
              SavedRecipesScreen(inShell: true),
              NutritionistDiscoveryScreen(inShell: true),
            ],
          ),
        ],
      ),
      bottomNavigationBar: HpBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTap,
        orange: orange,
        isNutritionistInUserView: _isNutritionist,
      ),
    );
  }
}

class _ShellBackgroundPattern extends StatelessWidget {
  const _ShellBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _ShellFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _ShellFloatingOrb(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.1),
              size: 500,
              duration: const Duration(seconds: 20),
            ),
          ),
          Positioned(
            top: 300.sh,
            right: -50.sw,
            child: _ShellFloatingOrb(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.05),
              size: 300,
              duration: const Duration(seconds: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _ShellFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_ShellFloatingOrb> createState() => _ShellFloatingOrbState();
}

class _ShellFloatingOrbState extends State<_ShellFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
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
        final double angle = _controller.value * 2 * 3.14159;
        return Transform.translate(
          offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
          child: Container(
            width: widget.size.sw,
            height: widget.size.sw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}
