import 'package:flutter_test/flutter_test.dart';

class MethodsState {
  final List<String> ids;
  final String? defaultId;
  const MethodsState(this.ids, this.defaultId);
}

MethodsState addMethod(MethodsState s, String id) {
  final ids = [...s.ids, id];
  final defaultId = s.ids.isEmpty ? id : s.defaultId;
  return MethodsState(ids, defaultId);
}

MethodsState removeMethod(MethodsState s, String id) {
  final remaining = [...s.ids]..remove(id);
  String? nextDefault = s.defaultId;
  if (s.defaultId == id) {
    nextDefault = remaining.isNotEmpty ? remaining.first : null;
  }
  return MethodsState(remaining, nextDefault);
}

void main() {
  group('Business: Wallet/Card default rules', () {
    test('First added becomes default', () {
      final s0 = MethodsState(const [], null);
      final s1 = addMethod(s0, 'm1');
      expect(s1.defaultId, 'm1');
    });
    test('Second added keeps first as default', () {
      final s1 = MethodsState(const ['m1'], 'm1');
      final s2 = addMethod(s1, 'm2');
      expect(s2.defaultId, 'm1');
    });
    test('Removing default promotes next oldest', () {
      final s = MethodsState(const ['m1', 'm2', 'm3'], 'm1');
      final s2 = removeMethod(s, 'm1');
      expect(s2.defaultId, 'm2');
      expect(s2.ids, ['m2', 'm3']);
    });
    test('Removing only method clears default', () {
      final s = MethodsState(const ['m1'], 'm1');
      final s2 = removeMethod(s, 'm1');
      expect(s2.defaultId, isNull);
      expect(s2.ids, isEmpty);
    });
  });
}

