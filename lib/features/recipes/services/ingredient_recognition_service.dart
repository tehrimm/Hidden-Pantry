import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class IngredientRecognitionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoading = false;

  static const int _inputSize = 224;
  
  String _canonicalizeLabel(String s) {
    var out = s.replaceAll('\r', '').trim();
    out = out.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    out = out.replaceAll(RegExp(r'\s+\d+$'), '').trim(); // drop trailing numbers
    out = out.replaceAll(RegExp(r'\s+'), ' '); // collapse spaces
    return out;
  }

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
      // Preserve line positions to keep indices aligned with the model output.
      final rawLines = labelData.split('\n');
      _labels = rawLines.map(_canonicalizeLabel).toList();

      // Align label count with model output classes if needed
      try {
        final outShape = _interpreter!.getOutputTensor(0).shape;
        final numClasses = outShape.reduce((a, b) => a * b);
        if (_labels.length != numClasses) {
          // Common cases:
          // 1) Leading blank line removed earlier → labels shorter by 1
          // 2) Trailing blank line present → labels longer by 1
          if (_labels.length == numClasses + 1 && (_labels.last.isEmpty || _labels.last.trim().isEmpty)) {
            _labels = _labels.sublist(0, numClasses);
          } else if (_labels.length == numClasses + 1 && (_labels.first.isEmpty || _labels.first.trim().isEmpty)) {
            _labels = _labels.sublist(1);
          } else if (_labels.length == numClasses - 1) {
            // Insert a placeholder background at index 0 if missing
            _labels = [''] + _labels;
          }
        }
      } catch (_) {}
      print("Labels loaded (aligned): ${_labels.length}");
      
    } catch (e) {
      print("Error initializing IngredientRecognitionService: $e");
    } finally {
      _isLoading = false;
    }
  }

  List<double> _getRgb(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
  }

  List<double> _run(List<double> input, List<int> shape) {
    final outputAttributes = _interpreter!.getOutputTensor(0);
    final outputShape = outputAttributes.shape;
    final outputBuffer = Float32List(outputShape.reduce((a, b) => a * b));
    final output = outputBuffer.reshape(outputShape);
    _interpreter!.run(Float32List.fromList(input).reshape(shape), output);
    final probs = (output[0] as List<double>).toList();
    return probs;
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

      // 2. Center-crop square then resize -> more robust for classifiers trained on crops
      final side = math.min(image.width, image.height);
      final x = ((image.width - side) / 2).round();
      final y = ((image.height - side) / 2).round();
      final square = img.copyCrop(image, x: x, y: y, width: side, height: side);
      final resized = img.copyResize(square, width: _inputSize, height: _inputSize);

      // 3. Build input: [0, 1] (as trained by train_model.py ImageDataGenerator)
      final total = _inputSize * _inputSize * 3;
      final inputBuffer = List<double>.filled(total, 0.0);
      var idx = 0;
      for (var y = 0; y < _inputSize; y++) {
        for (var x = 0; x < _inputSize; x++) {
          final rgb = _getRgb(resized, x, y);
          inputBuffer[idx++] = rgb[0] / 255.0;
          inputBuffer[idx++] = rgb[1] / 255.0;
          inputBuffer[idx++] = rgb[2] / 255.0;
        }
      }

      // 4. Run model inference
      final chosen = _run(inputBuffer, [1, _inputSize, _inputSize, 3]);

      // 5. Parse results
      final indexedProbs = List.generate(chosen.length, (i) => (index: i, prob: chosen[i]));
      indexedProbs.sort((a, b) => b.prob.compareTo(a.prob));
      final top3 = indexedProbs.take(3).toList();
      final List<({String label, double confidence})> results = [];
      for (var p in top3) {
        if (p.index < _labels.length && p.prob > 0.1) {
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
