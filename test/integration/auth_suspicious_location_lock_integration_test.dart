import 'package:flutter_test/flutter_test.dart';

class SuspiciousLocationGuard {
  String? _lastRegion;
  bool _locked = false;
  bool get locked => _locked;
  void recordTrustedRegion(String region) {
    _lastRegion = region;
    _locked = false;
  }
  void attemptFrom(String region) {
    if (_lastRegion == null) {
      _lastRegion = region;
      _locked = false;
      return;
    }
    if (region != _lastRegion) {
      _locked = true;
    }
  }
  void verify2FAAndUnlock(String region) {
    _locked = false;
    _lastRegion = region;
  }
}

void main() {
  group('Integration: Suspicious location lock until 2FA reverify', () {
    test('Locks on new region and unlocks after 2FA verify', () {
      final g = SuspiciousLocationGuard();
      g.recordTrustedRegion('EU-DE');
      g.attemptFrom('US-CA');
      expect(g.locked, true);
      g.verify2FAAndUnlock('US-CA');
      expect(g.locked, false);
      g.attemptFrom('US-CA');
      expect(g.locked, false);
    });
  });
}

