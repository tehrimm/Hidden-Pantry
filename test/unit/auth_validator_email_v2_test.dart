import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('[Unit][AuthValidator][Email] invalid', () {
    final invalids = [
      '',
      '   ',
      'abc',
      'abc@',
      'user@domain',
    ];
    for (var i = 0; i < invalids.length; i++) {
      test('[Unit][AuthValidator][Email] invalid-$i "${invalids[i]}"', () {
        final res = AuthValidator.validateEmail(invalids[i]);
        expect(res != null, true);
      });
    }
  });

  group('[Unit][AuthValidator][Email] valid', () {
    final valids = [
      'a@b.co',
      'user@gmail.com',
      'first.last@domain.org',
      'first_last@sub.domain.io',
      'u+label@domain.com',
      'name@sub.domain.co.uk',
    ];
    for (var i = 0; i < valids.length; i++) {
      test('[Unit][AuthValidator][Email] valid-$i "${valids[i]}"', () {
        final res = AuthValidator.validateEmail(valids[i]);
        expect(res, null);
      });
    }
  });
}

