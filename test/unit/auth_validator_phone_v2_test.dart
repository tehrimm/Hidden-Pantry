import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('[Unit][AuthValidator][Phone] invalid', () {
    final invalids = ['', '123', '123456', '1234567890123456', 'abc12345', '+++++++'];
    for (var i = 0; i < invalids.length; i++) {
      test('[Unit][AuthValidator][Phone] invalid-$i "${invalids[i]}"', () {
        final res = AuthValidator.validatePhone(invalids[i]);
        expect(res != null, true);
      });
    }
  });

  group('[Unit][AuthValidator][Phone] valid', () {
    final valids = [
      '1234567',
      '1234567890',
      '+1 650 555 1234',
      '(650) 555-1234',
      '0044 20 7946 0958',
      '+92-300-1234567',
      '0092 300 1234567',
    ];
    for (var i = 0; i < valids.length; i++) {
      test('[Unit][AuthValidator][Phone] valid-$i "${valids[i]}"', () {
        final res = AuthValidator.validatePhone(valids[i]);
        expect(res, null);
      });
    }
  });
}

