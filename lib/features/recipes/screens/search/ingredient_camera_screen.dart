import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/features/recipes/services/ingredient_recognition_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/pantry_screen.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class IngredientCameraScreen extends StatefulWidget {
  const IngredientCameraScreen({super.key});

  @override
  State<IngredientCameraScreen> createState() => _IngredientCameraScreenState();
}

class _IngredientCameraScreenState extends State<IngredientCameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  final IngredientRecognitionService _recognitionService = IngredientRecognitionService();
  
  // List to accumulate recognized ingredients
  final List<String> _recognizedIngredients = [];
  
  // Animation controllers
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  bool _isProcessingAnimate = false;

  // CSV Loading & Validation
  final Set<String> _validIngredients = {};
  bool _debug = false;
  List<({String label, double confidence})> _lastResults = const [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadCsv();
    _recognitionService.init(); 
    
    // Scan animation setup
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadCsv() async {
    try {
      final raw = await DefaultAssetBundle.of(context).loadString('assets/data/ingredients_categorized.csv');
      final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.isNotEmpty) {
          _validIngredients.add(parts.first.trim().toLowerCase());
        }
      }
      print("Loaded ${_validIngredients.length} valid ingredients from CSV.");
    } catch (e) {
      print("Error loading CSV in Camera Screen: $e");
    }
  }

  String _cleanAndValidate(String rawLabel) {
    String clean = rawLabel
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+\d+$'), '')
        .trim();
    
    if (_validIngredients.contains(clean.toLowerCase())) {
      return clean.toLowerCase(); 
    }

    final parts = clean.split(' ');
    if (parts.length > 1) {
       if (_validIngredients.contains(parts.first.toLowerCase())) {
         return parts.first.toLowerCase(); 
       }
    }
    return clean.toLowerCase();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        _controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();
        await _controller!.setFlashMode(FlashMode.off);
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _controller?.dispose();
    _recognitionService.close(); 
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isProcessingAnimate = true;
    });

    try {
      HapticFeedback.mediumImpact();
      
      final image = await _controller!.takePicture();
      
      // Pause preview AFTER capture to prevent Impeller 'Invalid external texture' crash on Android
      // while we do heavy ML processing.
      await _controller!.pausePreview();
      final file = File(image.path);

      final results = await _recognitionService.predict(file);
      _lastResults = results;
      
      if (!mounted) return;
      
      // Resume preview after we finish our heavy ML processing
      await _controller!.resumePreview();
      
      if (!mounted) return;
      
      setState(() => _isProcessingAnimate = false);

      if (results.isEmpty) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final err = _recognitionService.lastError;
          if (err.isNotEmpty) {
            // Show the actual exception if there was one
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Model Incompatible"),
                content: const Text(
                  "The machine learning model (ingredient_detector.tflite) was exported using a newer version of TensorFlow (2.16+) than this app's engine supports.\n\n"
                  "This error happens before the camera even looks at your image. To fix this permanently, the .tflite model must be re-exported using TensorFlow 2.14.\n\n"
                  "For now, please type the ingredient manually."
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showManualEntryDialog();
                    },
                    child: const Text("Type Manually"),
                  )
                ],
              ),
            );
          } else {
            // If no exception but just zero confidence/empty results
            _showManualEntryDialog();
          }
        }
        return;
      }

      final top1LabelClean = _cleanAndValidate(results.first.label);
      
      // Auto-confirm only when very confident (>=60%) and it's the only result
      if (results.length == 1 && results.first.confidence >= 0.6) {
        _showResultDialog(top1LabelClean, results.first.confidence, file);
      } else {
        _showSelectionDialog(results, file);
      }
    } catch (e) {
      print("Error capturing picture: $e");
      try {
        await _controller?.resumePreview();
      } catch (_) {}
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      HapticFeedback.lightImpact();
      setState(() {});
    } catch (e) {
      print("Error toggling flash: $e");
    }
  }

  void _showSelectionDialog(List<({String label, double confidence})> results, File imageFile) {
    _isProcessing = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernResultSheet(
        imageFile: imageFile,
        title: "Multiple matches",
        child: Column(
          children: [
            const Text(
              "Select the correct one:",
              style: TextStyle(color: Color(0xFFBFA89A), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...results.map((item) {
              final pretty = _cleanAndValidate(item.label);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ListTile(
                  title: Text(pretty, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF462F4D))),
                  subtitle: Text("${(item.confidence * 100).toStringAsFixed(0)}% confidence", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.add_circle_outline, color: Color(0xFFEF8A54)),
                  onTap: () {
                    Navigator.pop(context);
                    _onIngredientAdded(pretty);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(String label, double confidence, File imageFile) {
    _isProcessing = false;
    final validated = _cleanAndValidate(label);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernResultSheet(
        imageFile: imageFile,
        title: "Ingredient Found!",
        child: Column(
          children: [
            Text(
              validated.toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF462F4D),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "CONFIDENCE: ${(confidence * 100).toStringAsFixed(1)}%",
              style: const TextStyle(color: Color(0xFFEF8A54), fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF462F4D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("RETAKE", style: TextStyle(color: Color(0xFF462F4D), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _onIngredientAdded(validated);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF8A54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFFEF8A54).withValues(alpha: 0.3),
                    ),
                    child: const Text("ADD ITEM", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _recognizedIngredients.add(validated);
                Navigator.pop(context);
                Navigator.pop(context, _recognizedIngredients);
              },
              child: const Text("ADD & FINISH", style: TextStyle(color: Color(0xFF462F4D), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _onIngredientAdded(String item) {
    HapticFeedback.mediumImpact();
    setState(() {
      _recognizedIngredients.add(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✓ $item added"),
        backgroundColor: const Color(0xFF462F4D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showManualEntryDialog() {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3EB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Type Ingredient",
                style: TextStyle(
                  fontFamily: "Satoshi",
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF462F4D),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Color(0xFF462F4D), fontFamily: "Satoshi"),
                decoration: InputDecoration(
                  hintText: "e.g. Tomato, Garlic, Milk...",
                  hintStyle: TextStyle(
                    color: const Color(0xFF462F4D).withValues(alpha: 0.4),
                    fontFamily: "Satoshi",
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final val = textCtrl.text.trim();
                    if (val.isNotEmpty) {
                      Navigator.pop(ctx);
                      _onIngredientAdded(val.toLowerCase());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF8A54),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "ADD",
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFEF8A54))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Transform.scale(
            scale: 1.1,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          
          _buildScanningOverlay(),
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassCircleButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context, _recognizedIngredients),
                    ),
                    Row(
                      children: [
                         _buildGlassCircleButton(
                          icon: _debug ? Icons.bug_report : Icons.bug_report_outlined,
                          onTap: () => setState(() => _debug = !_debug),
                        ),
                        const SizedBox(width: 12),
                        _buildGlassCircleButton(
                          icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          onTap: _toggleFlash,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 30, top: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_recognizedIngredients.isNotEmpty) _buildIngredientTray(),
                  const SizedBox(height: 20),
                  _buildCaptureButton(),
                ],
              ),
            ),
          ),

          if (_isProcessingAnimate) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Stack(
      children: [
        ClipPath(
          clipper: InvertedClipper(
            width: 250.sw,
            height: 250.sw,
            radius: 30,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        Center(
          child: SizedBox(
            width: 260.sw,
            height: 260.sw,
            child: CustomPaint(painter: _ScannerCornerPainter()),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (250.sw * (_scanAnimation.value - 0.5))),
                child: Container(
                  width: 230.sw,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEF8A54).withValues(alpha: 0),
                        const Color(0xFFEF8A54),
                        const Color(0xFFEF8A54).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 22)),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _takePicture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: _isProcessing 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF8A54), strokeWidth: 3))
            : Center(
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF8A54).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildIngredientTray() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recognizedIngredients.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Text(
                  _recognizedIngredients[index],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _recognizedIngredients.removeAt(index)),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFEF8A54)),
                  const SizedBox(height: 20),
                  Text(
                    "ANALYZING...",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernResultSheet extends StatelessWidget {
  final File imageFile;
  final String title;
  final Widget child;

  const _ModernResultSheet({
    required this.imageFile,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3EB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF462F4D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(imageFile, width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFFEF8A54),
                      ),
                    ),
                    const Text(
                      "Scanning Result",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF462F4D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF8A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLen = 30.0;
    const radius = 20.0;

    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, cornerLen),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(cornerLen, size.height),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
        ..lineTo(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class InvertedClipper extends CustomClipper<Path> {
  final double width;
  final double height;
  final double radius;

  const InvertedClipper({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: width,
            height: height,
          ),
          Radius.circular(radius),
        ),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant InvertedClipper oldClipper) {
    return oldClipper.width != width ||
        oldClipper.height != height ||
        oldClipper.radius != radius;
  }
}
