import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/features/recipes/screens/home/home_screen.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/discovery.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_dashboard.dart';

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
    _checkNutritionistStatus();
  }

  Future<void> _checkNutritionistStatus() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) {
      setState(() => _isNutritionist = isNutr);
    }
  }

  void _onTap(int index) async {
    if (index == 2) {
      // Plus button (Upload) usually opens a full screen flow
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      );
      return;
    }

    if (index == 4 && _isNutritionist) {
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
      backgroundColor: const Color(0xFFFFF3EB), // Theme background
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(inShell: true),
          SearchScreen(inShell: true),
          SizedBox.shrink(), // Placeholder for plus button slot (index 2)
          SavedRecipesScreen(inShell: true),
          NutritionistDiscoveryScreen(inShell: true),
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
