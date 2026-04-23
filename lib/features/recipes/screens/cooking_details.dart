import 'dart:async';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui' as ui;
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/post_review.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/utils/ingredient_icon_mapper.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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

class _CookingDetailsScreenState extends State<CookingDetailsScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _ttsFinished = false;
  late int _currentServings;

  // Timer state
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerRunning = false;

  // Voice Control State
  final SpeechToText _speech = SpeechToText();
  bool _isVoiceEnabled = false;
  bool _speechEnabled = false;
  String _lastStatus = '';
  DateTime? _lastCommandTime;
  DateTime? _lastRestart;
  bool _shouldListen = false;
  bool _isManuallyStopped = false;
  Timer? _listenWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentServings = widget.initialServings;
    _initTts();
    
    // Check global voice preference before auto-starting
    _checkVoicePreference();
  }

  Future<void> _checkVoicePreference() async {
    // 1. Read the first step aloud safely
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _safeSpeak(widget.recipe.directions[_currentIndex]);

    // 2. Check if voice mode should be auto-enabled
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool voiceOn = true; // Default
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        voiceOn = doc.data()?['voiceEnabled'] ?? true;
      }

      if (voiceOn && mounted) {
        _toggleVoiceMode();
      }
    } catch (e) {
      debugPrint("Error fetching voice preference: $e");
      // Fallback: auto-enable if we can't check
      if (mounted) _toggleVoiceMode();
    }
  }

  void _initTts() {
    _tts.setStartHandler(() {
      setState(() => _isPlaying = true);
    });
    _tts.setCompletionHandler(() async {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _ttsFinished = true;
      });
      
      // Control central restart - only if NOT manually stopped
      if (_isVoiceEnabled && !_isManuallyStopped) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _safeRestartListening();
        });
      }
    });
    _tts.setErrorHandler((msg) {
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListenLoop();
    _pageController.dispose();
    _tts.stop();
    _timer?.cancel();
    _audioPlayer.dispose();
    _stopListening();
    super.dispose();
  }

  // --- Voice Control Logic ---

  Future<bool> _initVoiceControl() async {
    try {
      // Ensure clean state before re-init
      await _speech.cancel();
      
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎙️ Status: $status');
          if (status == 'notListening') {
            _safeRestartListening();
          }
          if (mounted) setState(() => _lastStatus = status);
        },
        onError: (err) {
          debugPrint('❌ Error: $err');
          _safeRestartListening();
        },
      );
      return _speechEnabled;
    } catch (e) {
      return false;
    }
  }

  void _startListenLoop() {
    _listenWatchdog?.cancel();
    _listenWatchdog = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isVoiceEnabled || _isPlaying || _isManuallyStopped) return;
      
      if (!_speech.isListening && !(_lastStatus == 'initializing')) {
        debugPrint("🔁 Watchdog: Restarting speech engine...");
        _startListening();
      }
    });
  }

  void _stopListenLoop() {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
  }

  void _safeRestartListening() async {
    if (!_isVoiceEnabled || _isManuallyStopped || _isPlaying) return;

    // Restart Cooldown (Prevent rapid-fire loops)
    if (_lastRestart != null &&
        DateTime.now().difference(_lastRestart!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRestart = DateTime.now();

    try {
      // 🔥 Force clean reset before listening again
      await _speech.cancel();
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted || !_isVoiceEnabled || _isManuallyStopped || _isPlaying) return;

      _startListening();
    } catch (e) {
      debugPrint("🎙️ Restart failed: $e");
    }
  }

  Future<void> _toggleVoiceMode() async {
    if (_isVoiceEnabled) {
      _shouldListen = false;
      _isManuallyStopped = true;
      _stopListenLoop();
      await _speech.cancel();
      if (mounted) setState(() => _isVoiceEnabled = false);
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();
    
    if (status.isGranted) {
      final ok = await _initVoiceControl();
      if (ok) {
        _shouldListen = true;
        _isManuallyStopped = false; // 🔥 Reset manual stop when enabling
        if (mounted) setState(() => _isVoiceEnabled = true);
        _startListenLoop();
        _startListening();
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || !_isVoiceEnabled || _isManuallyStopped || _isPlaying) return;

    // 🔥 Safety guard: reset if already active
    if (_speech.isListening) {
      await _speech.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _handleVoiceCommand(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: false, // 🔥 Fixed: More reliable on Android
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint("🎙️ Listen error: $e");
    }
  }

  Future<void> _stopListening() async {
    await _speech.cancel();
  }

  Future<void> _handleVoiceCommand(String text) async {
    if (text.trim().isEmpty) return;
    
    final command = text.toLowerCase().trim();
    final words = command.split(" ");
    
    // Time-based Debounce
    if (_lastCommandTime != null && 
        DateTime.now().difference(_lastCommandTime!) < const Duration(milliseconds: 1200)) {
      return; 
    }
    _lastCommandTime = DateTime.now();

    bool processed = false;
    debugPrint("🧠 Processing: $command");

    // STRICT WORD-LEVEL MAPPING
    final isNext = words.contains("next") || words.contains("forward") || 
                   words.contains("skip") || words.contains("done");

    final isBack = words.contains("back") || words.contains("previous") || 
                   words.contains("last");

    final isRepeat = words.contains("repeat") || words.contains("again") || 
                     words.contains("read");

    if (isNext) {
      await _speakConfirmation("Next step");
      _nextStep();
      processed = true;
    }
    else if (isBack) {
      await _speakConfirmation("Going back");
      _prevStep();
      processed = true;
    }
    else if (isRepeat) {
      _speak(widget.recipe.directions[_currentIndex], force: true);
      processed = true;
    }
    else if (words.contains("stop") || words.contains("shh") || words.contains("silence")) {
      _isManuallyStopped = true;
      _tts.stop();
      _shouldListen = false;
      await _speech.cancel();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isVoiceEnabled = false;
        });
      }
      processed = true;
    }
    else if (words.contains("exit") || words.contains("quit") || words.contains("cancel") || words.contains("close")) {
      _toggleVoiceMode();
      processed = true;
    }

    if (processed) {
       await _speech.cancel(); // 🔥 Use cancel for instant reset
       Future.delayed(const Duration(milliseconds: 600), () {
         if (_isVoiceEnabled && !_isManuallyStopped) {
           _safeRestartListening();
         }
       });
    }
  }

  // Quick voice confirmation feedback
  Future<void> _speakConfirmation(String phrase) async {
    await _tts.speak(phrase);
    // Let confirmation finish before reading step
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _nextStep() {
    if (_currentIndex < widget.recipe.directions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _safeSpeak(String text) async {
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _speak(text, force: true);
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (_isPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _isPlaying = false);
      if (!force) return;
    }

    // Use cancel for cleaner transition
    if (_isVoiceEnabled) await _speech.cancel();

    if (force) await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _ttsFinished = false);
    
    final spokenText = "Step ${_currentIndex + 1}. $text";
    await _tts.speak(spokenText);
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
    final res = await GlassDialog.show<bool>(
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
    int selectedMinutes = initialMinutes;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 380.sh,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB).withValues(alpha: 0.85),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              children: [
                // Drag Handle
                SizedBox(height: 12.sh),
                Container(
                  width: 40.sw,
                  height: 4.sh,
                  decoration: BoxDecoration(
                    color: const Color(0xFF462F4D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.sw),
                  ),
                ),
                
                // Header
                Padding(
                  padding: EdgeInsets.all(24.sw),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: const Color(0xFF462F4D), size: 24.sw),
                      SizedBox(width: 12.sw),
                      Text(
                        "Set Timer",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF462F4D),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close_rounded, color: const Color(0xFF462F4D), size: 24.sw),
                      ),
                    ],
                  ),
                ),
  
                // The Picker
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: Color(0xFF462F4D),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hms,
                      initialTimerDuration: Duration(minutes: selectedMinutes),
                      onTimerDurationChanged: (d) => selectedMinutes = d.inMinutes,
                    ),
                  ),
                ),
  
                // Action Button
                Padding(
                  padding: EdgeInsets.all(24.sw),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _startTimer(selectedMinutes * 60);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 55.sh,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF8A54),
                        borderRadius: BorderRadius.circular(16.sw),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF8A54).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Start Timer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 10.sh),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _scaleFactor() {
    final base = widget.recipe.baseServings;
    if (base <= 0) return 1.0;
    return _currentServings / base;
  }



  List<IngredientItem> _getIngredientsInStep(String text) {
    if (text.isEmpty) return [];
    final t = text.toLowerCase();
    return widget.recipe.ingredients.where((ing) {
      final name = ing.name.toLowerCase();
      // Try to find if either the whole name or key parts of it exist in the text
      // We check for exact words to avoid sub-string matches (like "oil" in "boil")
      final words = name.split(' ');
      return words.any((word) {
        if (word.length < 3) return false;
        return t.contains(word);
      }) || t.contains(name);
    }).toList();
  }

  String _fmtQty(double qty) {
    final scaled = qty * _scaleFactor();
    if (scaled <= 0) return "";
    
    final int wholePart = scaled.floor();
    final double fractionPart = scaled - wholePart;
    
    // Define standard cooking fractions
    final List<Map<String, dynamic>> fractions = [
      {'val': 0.0, 'str': ""},
      {'val': 0.125, 'str': "1/8"},
      {'val': 0.25, 'str': "1/4"},
      {'val': 0.333, 'str': "1/3"},
      {'val': 0.375, 'str': "3/8"},
      {'val': 0.5, 'str': "1/2"},
      {'val': 0.625, 'str': "5/8"},
      {'val': 0.666, 'str': "2/3"},
      {'val': 0.75, 'str': "3/4"},
      {'val': 0.875, 'str': "7/8"},
      {'val': 1.0, 'str': "UP"}, // Special marker for rounding up
    ];

    double minDiff = 999.0;
    Map<String, dynamic> bestMatch = fractions.first;

    for (var f in fractions) {
      double diff = (fractionPart - f['val']).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = f;
      }
    }

    if (bestMatch['str'] == "UP") {
      return (wholePart + 1).toString();
    }
    
    if (bestMatch['val'] == 0.0) {
      return wholePart > 0 ? wholePart.toString() : "0";
    }

    return wholePart > 0 ? "$wholePart ${bestMatch['str']}" : bestMatch['str'];
  }

  Future<bool> _onWillPop() async {
    final res = await GlassDialog.show<bool>(
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
                  right: 0,
                  top: 140.sh,
                  child: RepaintBoundary(child: _stepImage(screenWidth, _currentIndex)),
                ),
                
                // Header: Close Button, Step Counter, Ingredient Label
                Positioned(
                  left: 30.sw,
                  right: 30.sw,
                  top: 40.sh,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Left placeholder to balance the right side
                        SizedBox(
                          width: 80.sw,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () async {
                                if (await _onWillPop()) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                width: 44.sw,
                                height: 44.sw,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9E3D5),
                                  borderRadius: BorderRadius.circular(22.sw),
                                ),
                                child: Center(
                                  child: Icon(Icons.close, size: 20.sw, color: const Color(0xFF462F4D)),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Center Progress
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Step ${_currentIndex + 1} of ${widget.recipe.directions.length}',
                                style: TextStyle(
                                  color: const Color(0xFF462F4D),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              SizedBox(height: 10.sh),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10.sw),
                                child: SizedBox(
                                  width: 140.sw,
                                  height: 6.sh,
                                  child: LinearProgressIndicator(
                                    value: (_currentIndex + 1) / widget.recipe.directions.length,
                                    backgroundColor: const Color(0xFFF9E3D5),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF8A54)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right placeholder
                        SizedBox(
                          width: 80.sw,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                              child: Text(
                                'Ingredients',
                                style: TextStyle(
                                  color: const Color(0xFF462F4D),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Satoshi',
                                  decoration: TextDecoration.underline,
                                ),
                              ),
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
                  top: 380.sh,
                  bottom: 120.sh,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    itemCount: widget.recipe.directions.length,
                    onPageChanged: (idx) {
                      if (!mounted) return;
                      setState(() => _currentIndex = idx);
                      _safeSpeak(widget.recipe.directions[idx]);
                    },
                    itemBuilder: (context, index) {
                      final direction = widget.recipe.directions[index];
                      final stepIngredients = _getIngredientsInStep(direction);
                      
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Container(
                                      width: 44.sw,
                                      height: 44.sw,
                                      margin: EdgeInsets.only(right: 16.sw),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF8A54),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${index + 1}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20.sp,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: direction,
                                    style: TextStyle(
                                      color: const Color(0xFF462F4D),
                                      fontSize: 16.sp,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // "You'll Need" Section
                            if (stepIngredients.isNotEmpty) ...[
                              SizedBox(height: 30.sh),
                              Text(
                                "You'll Need",
                                style: TextStyle(
                                  color: const Color(0xFF462F4D),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Satoshi',
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 16.sh),
                              Wrap(
                                spacing: 10.sw,
                                runSpacing: 20.sh,
                                children: stepIngredients.map((IngredientItem ing) {
                                  return Container(
                                    width: (ResponsiveUtils.screenWidth - 80.sw) / 2, // Fits 2 in a row with spacing
                                    padding: EdgeInsets.all(12.sw),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9E3D5),
                                      borderRadius: BorderRadius.circular(15.sw),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          IngredientIconMapper.getIcon(ing.name),
                                          color: const Color(0xFF462F4D),
                                          size: 20.sw,
                                        ),
                                        SizedBox(width: 10.sw),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                ing.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: const Color(0xFF462F4D),
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                              SizedBox(height: 2.sh),
                                              Text(
                                                "${_fmtQty(ing.quantity)} ${ing.unit}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: const Color(0xFFEF8A54),
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Satoshi',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            
                            // Review button removed from here to be moved to fixed bottom
                          ],
                        ),
                      );
                    },
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
                // Unified Action Bar (Finish, Play, Timer)
                // 1. Timer Button
                if (detectedTimes.isNotEmpty || _timerRunning)
                  Positioned(
                    left: 25.sw,
                    bottom: 30.sh,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
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
                              color: const Color(0xFF462F4D),
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
                        SizedBox(height: 8.sh),
                        Text(
                          "TIMER",
                          style: TextStyle(
                            color: const Color(0xFF462F4D),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Play/Pause Button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 25.sh,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _speak(widget.recipe.directions[_currentIndex]),
                          child: Container(
                            width: 60.sw,
                            height: 60.sw,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE48E5B),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30.sw,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.sh),
                        Text(
                          _isPlaying ? "STOP" : "PLAY",
                          style: TextStyle(
                            color: const Color(0xFFEF8A54),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Finish Button
                if (_currentIndex == widget.recipe.directions.length - 1)
                  Positioned(
                    right: 25.sw,
                    bottom: 30.sh,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _openReview,
                          child: Container(
                            width: 55.sw,
                            height: 55.sw,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF462F4D), width: 1.5),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.stars_rounded,
                                color: const Color(0xFF462F4D),
                                size: 24.sw,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.sh),
                        Text(
                          "FINISH",
                          style: TextStyle(
                            color: const Color(0xFF462F4D),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Swipe Reminder (Glassy Corner Peel)
                if (_currentIndex == 0 && _ttsFinished)
                  Positioned(
                    right: 0,
                    bottom: 140.sh,
                    child: SizedBox(
                      width: 160.sw,
                      height: 160.sw,
                      child: const _SwipeReminder(),
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
      width: double.infinity,
      height: 220.sh,
      margin: EdgeInsets.symmetric(horizontal: 30.sw),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.sw),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.sw),
        child: hasImage
            ? Image.network(
                url,
                width: width,
                height: 220.sh,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(width),
              )
            : _placeholder(width),
      ),
    );
  }

  Widget _placeholder(double width) {
    return Image.asset(
      'assets/logos/recipe_placeholder.jpg',
      width: width,
      height: 220.sh,
      fit: BoxFit.cover,
    );
  }
}

class _SwipeReminder extends StatefulWidget {
  const _SwipeReminder();

  @override
  State<_SwipeReminder> createState() => _SwipeReminderState();
}

class _SwipeReminderState extends State<_SwipeReminder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _peelAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _peelAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _peelAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // The Glassy Peel
            ClipPath(
              clipper: _PeelClipper(_peelAnimation.value),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // The Peel Lines and Shadow
            CustomPaint(
              size: Size(160.sw, 160.sw),
              painter: _PagePeelPainter(_peelAnimation.value),
            ),
          ],
        );
      },
    );
  }
}

class _PeelClipper extends CustomClipper<Path> {
  final double amount;
  _PeelClipper(this.amount);

  @override
  Path getClip(Size size) {
    final path = Path();
    // Triangular area for the fold at bottom-right
    path.moveTo(size.width, size.height * (1 - amount * 2));
    path.quadraticBezierTo(
      size.width * (1.1 - amount), size.height * (1.1 - amount),
      size.width * (1 - amount * 2), size.height,
    );
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_PeelClipper oldClipper) => oldClipper.amount != amount;
}

class _PagePeelPainter extends CustomPainter {
  final double amount;
  _PagePeelPainter(this.amount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final foldPath = Path();
    // The curved line representing the "fold"
    foldPath.moveTo(size.width, size.height * (1 - amount * 2));
    foldPath.quadraticBezierTo(
      size.width * (1.1 - amount), size.height * (1.1 - amount),
      size.width * (1 - amount * 2), size.height,
    );

    // Draw a stronger shadow under the fold
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawPath(foldPath, shadowPaint);

    // Draw the highlights
    canvas.drawPath(foldPath, paint);
    
    // A little "SWIPE" hint inside the peel
    final textPainter = TextPainter(
      text: TextSpan(
        text: "→",
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.sp,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha:0.3), blurRadius: 4, offset: const Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    // Position it slightly inside the fold
    textPainter.paint(canvas, Offset(size.width - 45.sw, size.height - 45.sw));
  }

  @override
  bool shouldRepaint(_PagePeelPainter oldDelegate) => oldDelegate.amount != amount;
}



