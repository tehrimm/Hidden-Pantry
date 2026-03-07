import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/auth_validator.dart';

void main() {
  group('[Unit][AuthValidator][Name] invalid', () {
    final invalids = ['', '  ', 'ab', '1john', 'john@doe', 'john#', '.john'];
    for (var i = 0; i < invalids.length; i++) {
      test('[Unit][AuthValidator][Name] invalid-$i "${invalids[i]}"', () {
        final res = AuthValidator.validateFullName(invalids[i]);
        expect(res != null, true);
      });
    }
  });

  group('[Unit][AuthValidator][Name] valid', () {
    final valids = ['John Doe', 'Mary-Jane Watson', 'O Connor', 'Jean-Luc Picard', "D'Angelo Russell"];
    for (var i = 0; i < valids.length; i++) {
      test('[Unit][AuthValidator][Name] valid-$i "${valids[i]}"', () {
        final res = AuthValidator.validateFullName(valids[i]);
        expect(res, null);
      });
    }
  });
}

