import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IngredientRecognitionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoading = false;
  String lastError = "";

  // Pre-built lowercase set of all known ingredient words for fast OCR matching
  final Set<String> _knownWords = {};

  static const int _inputSize = 224;

  String _canonicalizeLabel(String s) {
    var out = s.replaceAll('\r', '').trim();
    out = out.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    out = out.replaceAll(RegExp(r'\s+\d+$'), '').trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  Future<void> init() async {
    if (_interpreter != null) return;
    _isLoading = true;
    try {
      print("Loading model...");
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
          'assets/model/ingredient_detector.tflite',
          options: options);
      print("Model loaded.");

      final labelData =
          await rootBundle.loadString('assets/model/class_names.txt');
      final rawLines = labelData.split('\n');
      _labels = rawLines.map(_canonicalizeLabel).toList();

      // Align label count with model output
      try {
        final outShape = _interpreter!.getOutputTensor(0).shape;
        final numClasses = outShape.reduce((a, b) => a * b);
        if (_labels.length != numClasses) {
          if (_labels.length == numClasses + 1 && _labels.last.trim().isEmpty) {
            _labels = _labels.sublist(0, numClasses);
          } else if (_labels.length == numClasses + 1 &&
              _labels.first.trim().isEmpty) {
            _labels = _labels.sublist(1);
          } else if (_labels.length == numClasses - 1) {
            _labels = [''] + _labels;
          }
        }
      } catch (_) {}

      // Build fast-lookup word set
      for (final label in _labels) {
        if (label.isEmpty) continue;
        _knownWords.add(label.toLowerCase());
        for (final word in label.toLowerCase().split(' ')) {
          if (word.length > 2) _knownWords.add(word);
        }
      }
      print("Labels: ${_labels.length}, known words: ${_knownWords.length}");
    } catch (e) {
      print("Init error: $e");
      lastError = "Init error: $e";
    } finally {
      _isLoading = false;
    }
  }

  List<double> _getRgb(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
  }

  List<double> _runModel(List<double> input, List<int> shape) {
    final outputAttributes = _interpreter!.getOutputTensor(0);
    final outputShape = outputAttributes.shape;
    final numOutputs = outputShape.reduce((a, b) => a * b);
    final outputBuffer = Float32List(numOutputs);
    final output = outputBuffer.reshape(outputShape);
    _interpreter!.run(Float32List.fromList(input).reshape(shape), output);

    // Robustly extract probabilities regardless of how tflite_flutter
    // wraps the output (Float32List, List<double>, or generic List).
    final raw = output[0];
    if (raw is Float32List) return raw.toList();
    if (raw is List<double>) return raw;
    if (raw is List) return raw.map((e) => (e as num).toDouble()).toList();
    // Flat fallback: treat the whole buffer as the output
    return outputBuffer.toList();
  }

  /// OCR path — best for packaged goods, labels, signs.
  Future<List<({String label, double confidence})>> _runOcr(
      File imageFile) async {
    final List<({String label, double confidence})> results = [];
    try {
      print("Running OCR...");
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String rawText = recognizedText.text;
      final String detectedText = rawText.toLowerCase();
      print("OCR text: '$rawText'");

      if (detectedText.isEmpty) return results;

      // Pass 1: full phrase match
      for (final label in _labels) {
        if (label.isEmpty) continue;
        final pattern =
            RegExp(r'\b' + RegExp.escape(label.toLowerCase()) + r'\b');
        if (pattern.hasMatch(detectedText)) {
          print("OCR phrase match: $label");
          results.add((label: label, confidence: 0.90));
          break;
        }
      }

      // Pass 2: word scoring
      if (results.isEmpty) {
        final ocrWords = detectedText
            .split(RegExp(r'[\s,;.\-/\\()\[\]]+'))
            .map((w) => w.trim().toLowerCase())
            .where((w) => w.length > 2)
            .toList();
        print("OCR words: $ocrWords");

        final Map<String, int> scores = {};
        for (final word in ocrWords) {
          if (_knownWords.contains(word)) {
            for (final label in _labels) {
              if (label.isEmpty) continue;
              if (label.toLowerCase() == word ||
                  label.toLowerCase().split(' ').contains(word)) {
                scores[label] = (scores[label] ?? 0) + 1;
              }
            }
          }
        }

        if (scores.isNotEmpty) {
          final sorted = scores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          var conf = 0.80;
          for (final entry in sorted.take(3)) {
            print("OCR word match: ${entry.key} (${entry.value})");
            results.add((label: entry.key, confidence: conf));
            conf -= 0.05;
          }
        }
      }
    } catch (e) {
      print("OCR error: $e");
      lastError = "OCR error: $e";
    }
    return results;
  }

  /// Model path — best for clean photos of fresh produce.
  Future<List<({String label, double confidence})>> _runModelInference(
      File imageFile) async {
    final List<({String label, double confidence})> results = [];
    if (_interpreter == null) return results;
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        lastError = "Model error: img.decodeImage returned null";
        return results;
      }

      final side = math.min(image.width, image.height);
      final cx = ((image.width - side) / 2).round();
      final cy = ((image.height - side) / 2).round();
      final square =
          img.copyCrop(image, x: cx, y: cy, width: side, height: side);
      final resized =
          img.copyResize(square, width: _inputSize, height: _inputSize);

      final total = _inputSize * _inputSize * 3;
      final inputBuffer = List<double>.filled(total, 0.0);
      var idx = 0;
      for (var py = 0; py < _inputSize; py++) {
        for (var px = 0; px < _inputSize; px++) {
          final rgb = _getRgb(resized, px, py);
          inputBuffer[idx++] = rgb[0] / 255.0;
          inputBuffer[idx++] = rgb[1] / 255.0;
          inputBuffer[idx++] = rgb[2] / 255.0;
        }
      }

      final probs = _runModel(inputBuffer, [1, _inputSize, _inputSize, 3]);
      final indexedProbs =
          List.generate(probs.length, (i) => (index: i, prob: probs[i]));
      indexedProbs.sort((a, b) => b.prob.compareTo(a.prob));

      // Include top-3 at a low 0.20 threshold so fresh produce always surfaces
      for (final p in indexedProbs.take(3)) {
        if (p.prob > 0.20 && p.index < _labels.length) {
          final label = _labels[p.index];
          if (label.isNotEmpty) {
            print("Model: $label (${(p.prob * 100).toStringAsFixed(1)}%)");
            results.add((label: label, confidence: p.prob));
          }
        }
      }

      // Always keep the single best guess as an absolute fallback
      if (results.isEmpty && indexedProbs.isNotEmpty) {
        final best = indexedProbs.first;
        if (best.index < _labels.length && _labels[best.index].isNotEmpty) {
          print(
              "Model fallback: ${_labels[best.index]} (${(best.prob * 100).toStringAsFixed(1)}%)");
          results.add((label: _labels[best.index], confidence: best.prob));
        } else {
          lastError = "Model error: Top index ${best.index} is out of bounds or empty. Labels loaded: ${_labels.length}";
        }
      }
    } catch (e) {
      print("Model error: $e");
      lastError = "Model error: $e";
    }
    return results;
  }

  Future<List<({String label, double confidence})>> predict(
      File imageFile) async {
    lastError = ""; // Clear previous errors FIRST

    // Always ensure model is loaded before predicting — so fresh produce
    // (no OCR text) still gets model results on the very first capture.
    if (_interpreter == null) {
      if (!_isLoading) await init();
    }

    // If init threw an error, return early so the UI shows it.
    if (lastError.isNotEmpty) {
      return [];
    }

    // Run OCR and model inference IN PARALLEL for speed
    final results = await Future.wait([
      _runOcr(imageFile),
      _runModelInference(imageFile),
    ]);

    final ocrResults = results[0];
    final modelResults = results[1];

    final merged = [...ocrResults];

    // Merge model results only when not already found by OCR
    for (final mr in modelResults) {
      final alreadyCovered =
          merged.any((r) => r.label.toLowerCase() == mr.label.toLowerCase());
      if (!alreadyCovered) {
        merged.add(mr);
      }
    }

    print(
        "Final: ${merged.map((r) => '${r.label}(${(r.confidence * 100).toStringAsFixed(0)}%)').join(', ')}");
    return merged;
  }

  void close() {
    _interpreter?.close();
  }
}
