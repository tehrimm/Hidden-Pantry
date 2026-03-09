import 'dart:io';

void main() {
  final source = File('assets/logos/logo.png');
  final dest = File('public/logo.png');
  source.copySync(dest.path);
  print('Copied logo successfully');
}
