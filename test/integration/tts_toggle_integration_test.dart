import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';

void main() {
  group('Integration: TTS toggle', () {
    test('Speak and stop toggle state', () {
      final t = TTSController();
      expect(t.isPlaying, false);
      t.speak();
      expect(t.isPlaying, true);
      t.stop();
      expect(t.isPlaying, false);
    });
  });
}

