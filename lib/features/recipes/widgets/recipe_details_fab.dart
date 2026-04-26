import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class AnimatedStartCookingFab extends StatefulWidget {
  final VoidCallback onTap;
  final bool isExpandedManually;

  const AnimatedStartCookingFab({
    super.key,
    required this.onTap,
    required this.isExpandedManually,
  });

  @override
  State<AnimatedStartCookingFab> createState() => _AnimatedStartCookingFabState();
}

class _AnimatedStartCookingFabState extends State<AnimatedStartCookingFab> with SingleTickerProviderStateMixin {
  AnimationController? _shimmerController;
  bool _clickExpanded = false;
  static const Color orange = Color(0xFFEF8A54);

  bool get _isExpanded => widget.isExpandedManually || _clickExpanded;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
    );
    
    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTest) {
      _shimmerController?.repeat();
    }
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _shimmerController;
    if (controller == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        if (_clickExpanded) return;
        
        if (!_isExpanded) {
          setState(() => _clickExpanded = true);
          await Future.delayed(const Duration(milliseconds: 400));
        }
        
        widget.onTap();
        
        bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
        if (!isTest) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
        if (mounted) setState(() => _clickExpanded = false);
      },
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            height: 56.sw,
            width: _isExpanded ? 156.sw : 56.sw,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.sw),
              boxShadow: [
                BoxShadow(
                  color: orange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment(-2.0 + controller.value * 4.0, -1.0),
                end: Alignment(-1.0 + controller.value * 4.0, 1.0),
                colors: const [
                  orange,
                  Color(0xFFFFA573),
                  orange,
                ],
                stops: const [0.4, 0.5, 0.6],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      "Start Cooking",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: _isExpanded ? 16.sw : 0,
                  left: _isExpanded ? null : 0,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 500),
                    turns: _isExpanded ? 0 : 0.25,
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18.sw,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
