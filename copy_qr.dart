import 'dart:io';

void main() {
  final source = File(r'C:\Users\tehri\.gemini\antigravity\brain\c0b6c927-b947-40b9-a6b5-3edc84834735\qr_code_apk_1778896725894.png');
  final target = File('public/web/qr_code.png');

  if (source.existsSync()) {
    source.copySync(target.path);
    print('✅ QR code copied to ${target.path}');
  } else {
    print('❌ Source file not found: ${source.path}');
  }
}
