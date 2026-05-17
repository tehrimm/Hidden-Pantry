import 'dart:io';

void main() async {
  final source = File('assets/logos/logo2.png');
  final dest = File('public/web/logo2.png');
  if (await source.exists()) {
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
    print('Copied logo2.png to public/web/ successfully');
  } else {
    print('Source logo2.png not found');
  }
}
