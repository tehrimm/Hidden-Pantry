import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class IngredientRecognitionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoading = false;

  static const int _inputSize = 224;
  

  Future<void> init() async {
    if (_interpreter != null) return;
    _isLoading = true;
    try {
      // Load model
      final options = InterpreterOptions();
      // Use metal delegate on iOS or NNAPI on Android if available? 
      // For now keep it simple CPU to avoid compatibility issues during initial setup.
      
      print("Loading model from assets/model/ingredient_detector.tflite...");
      _interpreter = await Interpreter.fromAsset('assets/model/ingredient_detector.tflite', options: options);
      print("Model loaded successfully.");

      // Load labels
      print("Loading labels from assets/model/class_names.txt...");
      final labelData = await rootBundle.loadString('assets/model/class_names.txt');
      _labels = labelData.split('\n').where((l) => l.trim().isNotEmpty).toList();
      print("Labels loaded: ${_labels.length}");
      
    } catch (e) {
      print("Error initializing IngredientRecognitionService: $e");
    } finally {
      _isLoading = false;
    }
  }

  Future<List<({String label, double confidence})>> predict(File imageFile) async {
    if (_interpreter == null) {
      if (!_isLoading) await init();
      if (_interpreter == null) return [];
    }

    try {
      // 1. Read and decode image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return [];

      // 2. Resize to 224x224 (Squash to fit - robust for MobileNet)
      final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

      // 3. Convert to Float32 input buffer (normalized [-1, 1])
      final input = Float32List(1 * _inputSize * _inputSize * 3);
      var pixelIndex = 0;
      for (var y = 0; y < _inputSize; y++) {
        for (var x = 0; x < _inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          input[pixelIndex++] = (r / 127.5) - 1.0;
          input[pixelIndex++] = (g / 127.5) - 1.0;
          input[pixelIndex++] = (b / 127.5) - 1.0;
        }
      }

      // 4. Run inference
      final outputAttributes = _interpreter!.getOutputTensor(0);
      final outputShape = outputAttributes.shape; 
      final outputBuffer = Float32List(outputShape.reduce((a, b) => a * b));
      final output = outputBuffer.reshape(outputShape);

      _interpreter!.run(input.reshape([1, _inputSize, _inputSize, 3]), output);

      // 5. Parse results
      final probabilities = output[0] as List<double>;
      
      final indexedProbs = List.generate(probabilities.length, (i) => (index: i, prob: probabilities[i]));
      indexedProbs.sort((a, b) => b.prob.compareTo(a.prob));
      
      final top3 = indexedProbs.take(3).toList();
      final List<({String label, double confidence})> results = [];

      for (var p in top3) {
        if (p.index < _labels.length && p.prob > 0.1) { // Lower threshold for alternatives
           results.add((label: _labels[p.index], confidence: p.prob));
        }
      }
      
      return results;

    } catch (e) {
      print("Error during prediction: $e");
    }
    return [];
  }
  
  void close() {
    _interpreter?.close();
  }
}
