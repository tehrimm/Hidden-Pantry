import 'package:flutter_test/flutter_test.dart';

bool canStartVoiceCooking({
  required bool hasPremiumAccess,
  required bool micPermissionGranted,
  required bool manuallyStopped,
}) {
  if (!hasPremiumAccess) return false;
  if (!micPermissionGranted) return false;
  if (manuallyStopped) return false;
  return true;
}

String normalizeVoiceCommand(String input) {
  final s = input.trim().toLowerCase();
  if (s.contains('next')) return 'next_step';
  if (s.contains('previous') || s.contains('back')) return 'previous_step';
  if (s.contains('repeat') || s.contains('again')) return 'repeat_step';
  if (s.contains('ingredient')) return 'open_ingredients';
  if (s.contains('stop')) return 'stop_voice';
  return 'unknown';
}

void main() {
  group('Business: Start cooking voice rules', () {
    test('Voice cooking allowed when premium + mic + not manually stopped', () {
      expect(
        canStartVoiceCooking(
          hasPremiumAccess: true,
          micPermissionGranted: true,
          manuallyStopped: false,
        ),
        true,
      );
    });

    test('Voice cooking denied when user is not premium', () {
      expect(
        canStartVoiceCooking(
          hasPremiumAccess: false,
          micPermissionGranted: true,
          manuallyStopped: false,
        ),
        false,
      );
    });

    test('Voice cooking denied when mic permission is missing', () {
      expect(
        canStartVoiceCooking(
          hasPremiumAccess: true,
          micPermissionGranted: false,
          manuallyStopped: false,
        ),
        false,
      );
    });

    test('Voice cooking denied when manually stopped by user', () {
      expect(
        canStartVoiceCooking(
          hasPremiumAccess: true,
          micPermissionGranted: true,
          manuallyStopped: true,
        ),
        false,
      );
    });

    test('Command normalization maps core cooking intents', () {
      expect(normalizeVoiceCommand('next step please'), 'next_step');
      expect(normalizeVoiceCommand('go back'), 'previous_step');
      expect(normalizeVoiceCommand('repeat that again'), 'repeat_step');
    });

    test('Command normalization maps ingredient and stop intents', () {
      expect(normalizeVoiceCommand('show ingredients'), 'open_ingredients');
      expect(normalizeVoiceCommand('stop voice mode'), 'stop_voice');
      expect(normalizeVoiceCommand('completely unrelated'), 'unknown');
    });
  });
}
