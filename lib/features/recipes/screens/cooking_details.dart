import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/post_review.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class CookingDetailsScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialServings;
  
  const CookingDetailsScreen({
    super.key, 
    required this.recipe,
    this.initialServings = 1,
  });

  @override
  State<CookingDetailsScreen> createState() => _CookingDetailsScreenState();
}

class _CookingDetailsScreenState extends State<CookingDetailsScreen> {
  final PageController _pageController = PageController();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  int _currentIndex = 0;
  bool _isPlaying = false;
  late int _currentServings;

  // Timer state
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _currentServings = widget.initialServings;
    _initTts();
  }

  void _initTts() {
    _tts.setStartHandler(() {
      setState(() => _isPlaying = true);
    });
    _tts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
    });
    _tts.setErrorHandler((msg) {
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
      if (!force) return; // Toggle stop
    }
    // Small delay to ensure stop state is processed
    if (force) await Future.delayed(const Duration(milliseconds: 100));
    await _tts.speak(text);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimerFinished();
      }
    });
  }

  void _onTimerFinished() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _remainingSeconds = 0;
    });
    // Play ping
    _audioPlayer.play(AssetSource('ping.mp3')).catchError((e) {
      // Fallback to TTS if asset missing
      _tts.speak("Timer finished");
    });
  }

  void _cancelTimer() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text("Cancel Timer?", style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: Text("Are you sure you want to stop the timer?", style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: TextStyle(color: const Color(0xFF462F4D), fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Yes", style: TextStyle(color: const Color(0xFFEF8A54), fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
    if (res == true) {
      _timer?.cancel();
      setState(() {
        _timerRunning = false;
        _remainingSeconds = 0;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  List<int> _detectTimes(String text) {
    final regex = RegExp(r'(\d+)(?:-(\d+))?\s*(hours|hour|hr|hrs|minutes|minute|min|mins)', caseSensitive: false);
    final matches = regex.allMatches(text);
    List<int> timesInMinutes = [];
    for (var m in matches) {
      int val = int.parse(m.group(1)!);
      String unit = m.group(3)!.toLowerCase();
      if (unit.startsWith('h')) {
        timesInMinutes.add(val * 60);
      } else {
        timesInMinutes.add(val);
      }
    }
    return timesInMinutes;
  }

  void _showTimerPicker(int initialMinutes) {
    Duration duration = Duration(minutes: initialMinutes);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260.sh,
        color: const Color(0xFFFFF3EB),
        child: Column(
          children: [
            Container(
              height: 200.sh,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms,
                initialTimerDuration: duration,
                onTimerDurationChanged: (d) => duration = d,
              ),
            ),
            CupertinoButton(
              child: const Text("Start Timer", style: TextStyle(color: Color(0xFFEF8A54), fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context);
                _startTimer(duration.inSeconds);
              },
            )
          ],
        ),
      ),
    );
  }

  double _scaleFactor() {
    final base = widget.recipe.baseServings;
    if (base <= 0) return 1.0;
    return _currentServings / base;
  }



  String _fmtQty(double qty) {
    final scaled = qty * _scaleFactor();
    if (scaled <= 0) return "";
    
    // Check for whole numbers
    if ((scaled - scaled.roundToDouble()).abs() < 0.0001) {
      return scaled.round().toString();
    }
    
    // Split into whole and fractional parts
    final int wholePart = scaled.floor();
    final double fractionPart = scaled - wholePart;
    
    // Fraction lookup table for common cooking decimals
    String? fraction;
    if ((fractionPart - 0.5).abs() < 0.02) fraction = "1/2";
    else if ((fractionPart - 0.25).abs() < 0.02) fraction = "1/4";
    else if ((fractionPart - 0.75).abs() < 0.02) fraction = "3/4";
    else if ((fractionPart - 0.33).abs() < 0.04) fraction = "1/3";
    else if ((fractionPart - 0.66).abs() < 0.04) fraction = "2/3";
    else if ((fractionPart - 0.125).abs() < 0.02) fraction = "1/8";
    else if ((fractionPart - 0.375).abs() < 0.02) fraction = "3/8";
    else if ((fractionPart - 0.625).abs() < 0.02) fraction = "5/8";
    else if ((fractionPart - 0.875).abs() < 0.02) fraction = "7/8";

    if (fraction != null) {
      return wholePart > 0 ? "$wholePart $fraction" : fraction;
    }

    // Fallback to decimal if no common fraction match
    return scaled
        .toStringAsFixed(2)
        .replaceAll(RegExp(r"0+$"), "")
        .replaceAll(RegExp(r"\.$"), "");
  }

  Future<bool> _onWillPop() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text("Exit Cooking?", style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: Text("Are you sure you want to stop cooking?", style: TextStyle(color: const Color(0xFF462F4D), fontFamily: 'Satoshi', fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: TextStyle(color: const Color(0xFF462F4D), fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Yes", style: TextStyle(color: const Color(0xFFEF8A54), fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostReviewScreen(recipe: widget.recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      ResponsiveUtils.init(context);
      final screenWidth = MediaQuery.of(context).size.width;
      final currentDirection = widget.recipe.directions[_currentIndex];
      final detectedTimes = _detectTimes(currentDirection);

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          endDrawer: _buildIngredientDrawer(),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB),
              borderRadius: BorderRadius.all(Radius.circular(30.sw)),
            ),
            child: Stack(
              children: [
                // Background Patterns
                const PatternBackground(),
                
                // Step image (uses step-specific image when available)
               Positioned(
                left: 0,
                top: 140.sh,
                child: _stepImage(screenWidth, _currentIndex),
              ),
                
                // Header: Close Button, Step Counter, Ingredient Label
                Positioned(
                  left: 30.sw,
                  right: 30.sw,
                  top: 40.sh,
                  child: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (await _onWillPop()) {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 50.sw,
                            height: 50.sw,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E3D5),
                              borderRadius: BorderRadius.circular(25.sw),
                            ),
                            child: Center(
                              child: Icon(Icons.close, size: 24.sw, color: const Color(0xFF462F4D)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Step ${_currentIndex + 1} of ${widget.recipe.directions.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF462F4D),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                          child: Text(
                            'Ingredient',
                            style: TextStyle(
                              color: const Color(0xFF462F4D),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Direction Text with PageView
                Positioned(
                  left: 30.sw,
                  right: 30.sw,
                  top: 360.sh,
                  bottom: 120.sh,
                  child: Column(
                    children: [
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is OverscrollNotification && notification.overscroll > 5) {
                              if (_currentIndex == widget.recipe.directions.length - 1) {
                                _openReview();
                                return true;
                              }
                            }
                            return false;
                          },
                          child: PageView.builder(
                            controller: _pageController,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemCount: widget.recipe.directions.length,
                            onPageChanged: (idx) {
                              setState(() => _currentIndex = idx);
                              // Auto-read on swipe
                              _speak(widget.recipe.directions[idx], force: true);
                            },
                            itemBuilder: (context, index) {
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Padding(
                                  padding: EdgeInsets.only(top: 10.sh),
                                  child: Text(
                                    widget.recipe.directions[index],
                                    style: TextStyle(
                                      color: const Color(0xFF462F4D),
                                      fontSize: 16.sp,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_currentIndex == widget.recipe.directions.length - 1)
                        Padding(
                          padding: EdgeInsets.only(top: 20.sh),
                          child: GestureDetector(
                            onTap: _openReview,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 12.sh),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF8A54),
                                borderRadius: BorderRadius.circular(20.sw),
                              ),
                              child: Text(
                                "Finish & Review",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Satoshi',
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Timer Display (Center below direction)
                if (_timerRunning)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 130.sh,
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _formatDuration(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEF8A54),
                              fontFamily: 'Satoshi',
                            ),
                          ),
                          Text(
                            "remaining",
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF462F4D),
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Play/Pause Button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40.sh,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _speak(widget.recipe.directions[_currentIndex]),
                      child: Container(
                        width: 74.sw,
                        height: 71.sh,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE48E5B),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40.sw,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Timer Button (Bottom Right)
                if (detectedTimes.isNotEmpty || _timerRunning)
                  Positioned(
                    right: 20.sw,
                    bottom: 50.sh,
                    child: GestureDetector(
                      onTap: () {
                        if (_timerRunning) {
                          _cancelTimer();
                        } else {
                          _showTimerPicker(detectedTimes.isNotEmpty ? detectedTimes.first : 5);
                        }
                      },
                      child: Container(
                        width: 55.sw,
                        height: 55.sw,
                        decoration: BoxDecoration(
                          color: _timerRunning ? const Color(0xFF462F4D) : const Color(0xFFEF8A54),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.1),
                              blurRadius: 10.sw,
                              offset: Offset(0, 4.sh),
                            ),
                          ],
                        ),
                        child: Icon(
                          _timerRunning ? Icons.timer_off_outlined : Icons.timer_outlined,
                          color: Colors.white,
                          size: 28.sw,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildIngredientDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFF3EB),
      width: MediaQuery.of(context).size.width * 0.75,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.sw),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ingredients for $_currentServings servings",
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF462F4D),
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 24.sh),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.recipe.ingredients.length,
                  separatorBuilder: (_, __) => Divider(height: 24.sh),
                  itemBuilder: (context, index) {
                    final ing = widget.recipe.ingredients[index];
                    final qtyStr = _fmtQty(ing.quantity);
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.sh),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ing.name,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: const Color(0xFF462F4D),
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.sw),
                          Text(
                            "${qtyStr.isEmpty ? '' : '$qtyStr '}${ing.unit}",
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF462F4D),
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepImage(double width, int index) {
    String? url;
    final steps = widget.recipe.stepsDetailed;
    if (steps != null && index >= 0 && index < steps.length) {
      final m = steps[index];
      final u = m['imageUrl'] ?? m['image_url'] ?? m['image'];
      if (u is String && u.trim().isNotEmpty) {
        url = u.trim();
      }
    }
    url ??= widget.recipe.imageUrl;
    final hasImage = url != null && url.trim().isNotEmpty;

    return Container(
      width: width,
      height: 180.sh,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: hasImage
          ? Image.network(
              url,
              width: width,
              height: 180.sh,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(width),
            )
          : _placeholder(width),
    );
  }

  Widget _placeholder(double width) {
    return Image.asset(
      'assets/logos/recipe_placeholder.jpg',
      width: width,
      height: 180.sh,
      fit: BoxFit.cover,
    );
  }
}



