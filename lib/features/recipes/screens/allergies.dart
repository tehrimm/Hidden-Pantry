import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

class AllergiesScreen extends StatefulWidget {
  /// When opened from Profile Settings:
  /// - shows back button
  /// - hides Skip
  /// - preselects allergies from Firestore
  /// - button text becomes Save
  final bool fromProfile;
  final UserService? userService;

  const AllergiesScreen({super.key, this.fromProfile = false, this.userService});

  @override
  State<AllergiesScreen> createState() => _AllergiesScreenState();
}

class _AllergiesScreenState extends State<AllergiesScreen> {
  late final UserService _userService;
  final Set<String> _selected = {};
  bool _loading = false;
  bool _fetching = false;

  // Figma base
  static const double baseW = 393.0;
  static const double baseH = 852.0;

  // Tile sizes
  static const double smallSize = 70;
  static const double largeSize = 90;

  // Rounded corners
  static const double screenRadius = 20;
  static const double tileRadius = 20;

  // Colors
  static const Color bg = Color(0xFFFFF3EB);
  static const Color titleColor = Color(0xFF462F4D);
  static const Color buttonOrange = Color(0xFFF2894F);
  static const Color buttonText = Color(0xFFFFF2EA);

  // 12 ingredients (KEEP labels EXACT, because Firestore values must match these)
  final List<_TileData> _tiles = const [
    _TileData(label: 'Caffeine', asset: 'assets/food/caffeine.png', left: 95, top: 317, isLarge: false),
    _TileData(label: 'Tree nuts', asset: 'assets/food/treenuts.png', left: 189, top: 283, isLarge: true),
    _TileData(label: 'Peanuts', asset: 'assets/food/peanuts.png', left: 280, top: 352, isLarge: false),

    _TileData(label: 'Spicy', asset: 'assets/food/spicy.png', left: 33, top: 374, isLarge: false),
    _TileData(
      label: 'Gluten',
      asset: 'assets/food/gluten.png',
      left: 155,
      top: 382,
      isLarge: false,
      iconW: 58,
      iconH: 39,
    ),
    _TileData(label: 'Soy', asset: 'assets/food/soy.png', left: 222, top: 420, isLarge: true, iconW: 45, iconH: 45),

    _TileData(label: 'Shellfish', asset: 'assets/food/shellfish.png', left: 68, top: 435, isLarge: true),
    _TileData(label: 'Wheat', asset: 'assets/food/wheat.png', left: 150, top: 491, isLarge: true),
    _TileData(label: 'Dairy', asset: 'assets/food/milk.png', left: 279, top: 525, isLarge: false, iconW: 35, iconH: 35),

    _TileData(label: 'Fish', asset: 'assets/food/fish.png', left: 33, top: 523, isLarge: false),
    _TileData(label: 'Eggs', asset: 'assets/food/eggs.png', left: 98, top: 579, isLarge: false, iconW: 50, iconH: 42),
    _TileData(label: 'Tomatoes', asset: 'assets/food/tomato.png', left: 205, top: 582, isLarge: true),
  ];

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    if (widget.fromProfile) {
      _loadExistingAllergies();
    }
  }

  Future<void> _loadExistingAllergies() async {
    setState(() => _fetching = true);
    try {
      final list = await _userService.getUserAllergies();
      if (!mounted) return;

      setState(() {
        _selected
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load allergies: $e')),
      );
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _toggle(String label) {
    if (_loading || _fetching) return;
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    );
  }

  Future<void> _saveOrContinue() async {
    if (_loading || _fetching) return;

    // Signup flow requires at least one selection
    if (!widget.fromProfile && _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _userService.updateAllergies(_selected.toList());

      if (!mounted) return;

      // Profile mode goes back
      if (widget.fromProfile) {
        Navigator.of(context).pop(true);
        return;
      }

      // Signup mode goes home (shell)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // true responsive (keeps proportions)
          final s = math.min(w / baseW, h / baseH);

          // center the whole design
          final dx = (w - baseW * s) / 2;
          final dy = (h - baseH * s) / 2;

          return Stack(
            children: [
              Positioned.fill(child: Container(color: bg)),

              Positioned(
                left: dx,
                top: dy,
                width: baseW * s,
                height: baseH * s,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(screenRadius * s),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(child: Container(color: bg)),

                      const PatternBackground(),

                      // Back button ONLY in profile mode
                      if (widget.fromProfile)
                        Positioned(
                          left: 30 * s,
                          top: 51 * s,
                          child: BackButtonWidget(color: titleColor),
                        ),

                      // Skip ONLY in signup mode
                      if (!widget.fromProfile)
                        Positioned(
                          right: 30 * s,
                          top: 67 * s,
                          child: GestureDetector(
                            onTap: _skip,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: const Color(0xFF74503C),
                                fontSize: 15 * s,
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      // Title
                      Positioned(
                        left: 30 * s,
                        top: 117 * s,
                        child: SizedBox(
                          width: 330 * s,
                          child: Text(
                            'What should we\navoid for you?',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 40 * s,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w900,
                              height: 1.10,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 30 * s,
                        top: 222 * s,
                        child: SizedBox(
                          width: 325 * s,
                          child: Text(
                            'Pick the ingredients you want to avoid due to\nallergies, intolerances, or personal health\nneeds.',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15 * s,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),

                      // Tiles
                      for (final t in _tiles)
                        Positioned(
                          left: t.left * s,
                          top: t.top * s,
                          child: _DiamondTile(
                            size: (t.isLarge ? largeSize : smallSize) * s,
                            radius: tileRadius * s,
                            asset: t.asset,
                            label: t.label,
                            selected: _selected.contains(t.label),
                            onTap: () => _toggle(t.label),
                            scale: s,
                            iconW: t.iconW,
                            iconH: t.iconH,
                          ),
                        ),

                      // Counter
                      Positioned(
                        left: 30 * s,
                        top: 704 * s,
                        child: Text(
                          '${_selected.length}/12 Selected',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15 * s,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      // Button
                      Positioned(
                        left: 32 * s,
                        top: 748 * s,
                        child: GestureDetector(
                          onTap: (_loading || _fetching) ? null : _saveOrContinue,
                          child: Container(
                            width: 332 * s,
                            height: 62 * s,
                            decoration: BoxDecoration(
                              color: buttonOrange,
                              borderRadius: BorderRadius.circular(20 * s),
                            ),
                            child: Center(
                              child: (_loading || _fetching)
                                  ? SizedBox(
                                      width: 20 * s,
                                      height: 20 * s,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.fromProfile ? 'Save' : 'Continue',
                                          style: TextStyle(
                                            color: buttonText,
                                            fontSize: 15 * s,
                                            fontFamily: 'Satoshi',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 10 * s),
                                        Image.asset(
                                          'assets/icons/nextButton.png',
                                          width: 18 * s,
                                          height: 18 * s,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiamondTile extends StatelessWidget {
  final double size;
  final double radius;
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  final double? iconW;
  final double? iconH;

  const _DiamondTile({
    required this.size,
    required this.radius,
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scale,
    this.iconW,
    this.iconH,
  });

  static const Color tileLight = Color(0xFFF9E3D5);
  static const Color tileDark = Color(0xFF3D2B44);
  static const Color labelBrown = Color(0xFF74503C);

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? tileDark : tileLight;
    final textColor = selected ? Colors.white : labelBrown;

    final double defaultIcon = size * 0.42;
    final double w = (iconW != null) ? iconW! * scale : defaultIcon;
    final double h = (iconH != null) ? iconH! * scale : defaultIcon;

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  asset,
                  width: w,
                  height: h,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: size * 0.07),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12 * scale,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileData {
  final String label;
  final String asset;
  final double left;
  final double top;
  final bool isLarge;

  final double? iconW;
  final double? iconH;

  const _TileData({
    required this.label,
    required this.asset,
    required this.left,
    required this.top,
    required this.isLarge,
    this.iconW,
    this.iconH,
  });
}




