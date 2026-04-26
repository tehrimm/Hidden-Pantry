import 'package:flutter_test/flutter_test.dart';

String normalizeTranscript(String raw) {
  return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

bool shouldRunVoiceSearch({
  required String transcript,
  required int minChars,
}) {
  final q = normalizeTranscript(transcript);
  return q.length >= minChars;
}

bool shouldAcceptVoiceResult({
  required String candidate,
  required String previousAccepted,
}) {
  final next = normalizeTranscript(candidate);
  final prev = normalizeTranscript(previousAccepted);
  if (next.isEmpty) return false;
  if (next == prev) return false;
  return true;
}

void main() {
  group('Business: Voice search rules', () {
    test('Normalization trims and lowercases transcript', () {
      expect(normalizeTranscript('  CHICKEN Pasta  '), 'chicken pasta');
    });

    test('Normalization collapses extra whitespace', () {
      expect(normalizeTranscript('egg     fried   rice'), 'egg fried rice');
    });

    test('Search blocked when transcript is shorter than minimum', () {
      expect(
        shouldRunVoiceSearch(transcript: 'pi', minChars: 3),
        false,
      );
    });

    test('Search allowed when transcript meets minimum length', () {
      expect(
        shouldRunVoiceSearch(transcript: 'pizza', minChars: 3),
        true,
      );
    });

    test('Empty/blank voice result is rejected', () {
      expect(
        shouldAcceptVoiceResult(candidate: '   ', previousAccepted: 'pasta'),
        false,
      );
    });

    test('Duplicate consecutive voice result is rejected, new one accepted', () {
      expect(
        shouldAcceptVoiceResult(candidate: 'Chicken Curry', previousAccepted: 'chicken curry'),
        false,
      );
      expect(
        shouldAcceptVoiceResult(candidate: 'Chicken Soup', previousAccepted: 'chicken curry'),
        true,
      );
    });
  });
}
