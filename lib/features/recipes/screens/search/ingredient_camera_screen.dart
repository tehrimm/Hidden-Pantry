import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/services/ingredient_recognition_service.dart';

class IngredientCameraScreen extends StatefulWidget {
  const IngredientCameraScreen({super.key});

  @override
  State<IngredientCameraScreen> createState() => _IngredientCameraScreenState();
}

class _IngredientCameraScreenState extends State<IngredientCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  final IngredientRecognitionService _recognitionService = IngredientRecognitionService();
  
  // List to accumulate recognized ingredients
  final List<String> _recognizedIngredients = [];

  // CSV Loading & Validation
  final Set<String> _validIngredients = {};

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadCsv();
    _recognitionService.init(); 
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
    // 1. Remove trailing numbers (e.g. "Tomato 1" -> "Tomato")
    String clean = rawLabel.replaceAll(RegExp(r'\s*\d+$'), '').trim();
    
    // 2. Check if simple clean exists
    if (_validIngredients.contains(clean.toLowerCase())) {
      return clean.toLowerCase(); 
    }

    // 3. Fallback: try removing specific descriptors if not found?
    // E.g. "Apple Red" -> "Apple".
    // Or just return the clean version if not strictly enforcing CSV.
    // User said "search if they are in csv". 
    // If "Apple Red" is in CSV, great. If not, maybe "Apple"?
    
    // Let's try splitting by space and finding simpler match if complex fails
    final parts = clean.split(' ');
    if (parts.length > 1) {
       // try first word
       if (_validIngredients.contains(parts.first.toLowerCase())) {
         return parts.first.toLowerCase(); 
       }
    }

    // If still not found, return clean version anyway (best effort)
    return clean.toLowerCase();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use back camera
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        _controller = CameraController(
          backCamera,
          ResolutionPreset.medium, // Medium resolution is enough for 224x224 and faster
          enableAudio: false,
        );

        await _controller!.initialize();
        // Force flash OFF by default to avoid auto-firing
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
    _controller?.dispose();
    _recognitionService.close(); // Close interpreter
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final file = File(image.path);

      // Run inference
      final results = await _recognitionService.predict(file);
      
      if (!mounted) return;

      if (results.isNotEmpty) {
        if (results.length == 1 || results.first.confidence > 0.8) {
           _showResultDialog(results.first.label, results.first.confidence, file);
        } else {
           // Show selection dialog for ambiguous results
           _showSelectionDialog(results, file);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not recognize ingredient. Try again.")),
        );
        setState(() => _isProcessing = false);
      }

    } catch (e) {
      print("Error capturing picture: $e");
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      print("Error toggling flash: $e");
    }
  }

  void _showSelectionDialog(List<({String label, double confidence})> results, File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Ingredient"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imageFile,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
              const Text("Multiple matches found:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${(item.confidence * 100).toStringAsFixed(0)}% confidence"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                         Navigator.pop(dialogContext);
                         // Proceed with selected item
                         _showResultDialog(item.label, item.confidence, imageFile); 
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _isProcessing = false);
            },
            child: const Text("Retake"),
          ),
        ]
      ),
    );
  }

  void _showResultDialog(String label, double confidence, File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Ingredient Found!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                imageFile,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Found: $label", // Show RAW label initially
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF462F4D)),
            ),
            const SizedBox(height: 8),
            Text(
              "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _isProcessing = false);
            },
            child: const Text("Retake"),
          ),
          TextButton(
            onPressed: () {
              final validated = _cleanAndValidate(label);
              _recognizedIngredients.add(validated);
              
              Navigator.pop(dialogContext);
              setState(() => _isProcessing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$validated added to selections")),
              );
            },
            child: const Text("Add & Take Another"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF8A54),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final validated = _cleanAndValidate(label);
              _recognizedIngredients.add(validated);
              
              Navigator.pop(dialogContext); // Close dialog
              Navigator.of(context).pop(_recognizedIngredients); // Close screen
            },
            child: const Text("Add & Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen camera preview
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),
          
          // Controls
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () {
                          Navigator.pop(context, _recognizedIngredients.isNotEmpty ? _recognizedIngredients : null);
                        },
                      ),
                      // Flash toggle
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom capture bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isProcessing ? Colors.grey : Colors.transparent,
                        ),
                        child: _isProcessing 
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Captured items counter overlay
          if (_recognizedIngredients.isNotEmpty)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha:0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_recognizedIngredients.length} Items",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
