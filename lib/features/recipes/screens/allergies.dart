import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class AllergiesScreen extends StatefulWidget {
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

  static const double smallSize = 64;
  static const double largeSize = 82;
  static const double tileRadius = 18;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color titleColor = Color(0xFF462F4D);
  static const Color buttonOrange = Color(0xFFF2894F);
  static const Color buttonText = Color(0xFFFFF2EA);

  final List<_TileData> _tiles = const [
    _TileData(label: 'Caffeine', asset: 'assets/food/caffeine.png', left: 95, top: 317, isLarge: false),
    _TileData(label: 'Tree nuts', asset: 'assets/food/treenuts.png', left: 189, top: 283, isLarge: true),
    _TileData(label: 'Peanuts', asset: 'assets/food/peanuts.png', left: 280, top: 352, isLarge: false),
    _TileData(label: 'Spicy', asset: 'assets/food/spicy.png', left: 33, top: 374, isLarge: false),
    _TileData(label: 'Gluten', asset: 'assets/food/gluten.png', left: 155, top: 382, isLarge: false, iconW: 58, iconH: 39),
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
    if (widget.fromProfile) _loadExistingAllergies();
  }

  Future<void> _loadExistingAllergies() async {
    setState(() => _fetching = true);
    try {
      final list = await _userService.getUserAllergies();
      if (!mounted) return;
      setState(() {
        _selected..clear()..addAll(list);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load allergies: $e')));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) _selected.remove(label);
      else _selected.add(label);
    });
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainNavigationShell()), (route) => false);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await _userService.updateAllergies(_selected.toList());
      if (mounted) {
         if (widget.fromProfile) Navigator.pop(context);
         else _skip();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving preferences: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width >= 600;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isTablet ? 16.sh : 25.sh),
                // Header row
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.sw),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.fromProfile)
                        const BackButtonWidget(color: titleColor)
                      else
                        const SizedBox(width: 40, height: 40),
                      if (!widget.fromProfile)
                        GestureDetector(
                          onTap: _skip,
                          child: Text('Skip', style: TextStyle(color: const Color(0xFF74503C), fontSize: 16.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w600)),
                        )
                      else
                        const SizedBox(width: 40, height: 40),
                    ],
                  ),
                ),
                SizedBox(height: 15.sh),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.sw),
                  child: _StaggeredItem(
                    index: 0,
                    delay: 100,
                    child: Text('What should we\navoid for you?', style: TextStyle(color: titleColor, fontSize: 36.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w900, height: 1.10)),
                  ),
                ),
                SizedBox(height: 10.sh),

                // Subtitle
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.sw),
                  child: _StaggeredItem(
                    index: 1,
                    delay: 100,
                    child: Text('Pick the ingredients you want to avoid due to\nallergies, intolerances, or personal health\nneeds.', style: TextStyle(color: titleColor, fontSize: 15.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w400, height: 1.35)),
                  ),
                ),

                // Tile Cluster in perfectly proportioned FittedBox
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 380,
                        height: 410,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < _tiles.length; i++)
                              Positioned(
                                left: _tiles[i].left.toDouble(),
                                top: _tiles[i].top.toDouble() - 270.0,
                                child: _StaggeredItem(
                                  index: i + 3,
                                  delay: 40,
                                  child: _DiamondTile(
                                    size: (_tiles[i].isLarge ? largeSize : smallSize).toDouble(),
                                    radius: tileRadius.toDouble(),
                                    asset: _tiles[i].asset,
                                    label: _tiles[i].label,
                                    selected: _selected.contains(_tiles[i].label),
                                    iconW: _tiles[i].iconW?.toDouble(),
                                    iconH: _tiles[i].iconH?.toDouble(),
                                    onTap: () => _toggle(_tiles[i].label),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom bar
                Padding(
                  padding: EdgeInsets.fromLTRB(30.sw, 0, 30.sw, mq.padding.bottom + 20.sh),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StaggeredItem(
                        index: 15,
                        child: Text('${_selected.length}/12 Selected', style: TextStyle(color: titleColor, fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
                      ),
                      SizedBox(height: 12.sh),
                      _StaggeredItem(
                        index: 16,
                        child: GestureDetector(
                          onTap: _loading ? null : _save,
                          child: Container(
                            height: math.max(60.0, 62.sh),
                            decoration: BoxDecoration(color: buttonOrange, borderRadius: BorderRadius.circular(20.sw), boxShadow: [BoxShadow(color: buttonOrange.withValues(alpha: 0.35), blurRadius: 15, offset: const Offset(0, 8))]),
                            child: Center(
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(widget.fromProfile ? 'Save Settings' : 'Continue', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Satoshi')),
                                        SizedBox(width: 10.sw),
                                        Image.asset('assets/icons/next_button.png', width: 18.sw, height: 18.sh, fit: BoxFit.contain),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  final Widget child;
  final int index;
  final double delay;
  const _StaggeredItem({required this.child, required this.index, this.delay = 50});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * delay).toInt().clamp(0, 600)),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
        );
      },
      child: child,
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
  final double? iconW;
  final double? iconH;

  const _DiamondTile({required this.size, required this.radius, required this.asset, required this.label, required this.selected, required this.onTap, this.iconW, this.iconH});

  static const Color tileLight = Color(0xFFF9E3D5);
  static const Color tileDark = Color(0xFF3D2B44);
  static const Color labelBrown = Color(0xFF74503C);

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? tileDark : tileLight.withValues(alpha: 0.6);
    final textColor = selected ? Colors.white : labelBrown;
    final double defaultIcon = size * 0.42;
    final double w = (iconW != null) ? iconW! : defaultIcon;
    final double h = (iconH != null) ? iconH! : defaultIcon;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: selected ? 0.25 : 0.08), blurRadius: 12, offset: const Offset(4, 4))],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(asset, width: w, height: h, fit: BoxFit.contain),
                  SizedBox(height: size * 0.05),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 12.5, fontFamily: 'Satoshi', fontWeight: selected ? FontWeight.w900 : FontWeight.w700, height: 1.1)),
                  ),
                ],
              ),
            ),
          ],
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

  const _TileData({required this.label, required this.asset, required this.left, required this.top, required this.isLarge, this.iconW, this.iconH});
}
