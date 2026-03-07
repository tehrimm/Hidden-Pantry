import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('[Unit][AuthValidator][Password] invalid', () {
    final invalids = ['', '   ', 'short', '1234567'];
    for (var i = 0; i < invalids.length; i++) {
      test('[Unit][AuthValidator][Password] invalid-$i "${invalids[i]}"', () {
        final res = AuthValidator.validatePassword(invalids[i]);
        expect(res != null, true);
      });
    }
  });

  group('[Unit][AuthValidator][Password] valid', () {
    final valids = ['12345678', 'password8', 'P@ssw0rd123', 'abcdefghijk'];
    for (var i = 0; i < valids.length; i++) {
      test('[Unit][AuthValidator][Password] valid-$i "${valids[i]}"', () {
        final res = AuthValidator.validatePassword(valids[i]);
        expect(res, null);
      });
    }
  });
}

