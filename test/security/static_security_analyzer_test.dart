import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security Static Analysis Security Tool (SAST) Scanner', () {
    test('HP-01 & HP-05: Scanning firestore.rules for hardcoded admin identities and key exposure overrides', () {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue, reason: 'firestore.rules must exist for audit scanning');
      
      final content = file.readAsStringSync();
      
      // HP-01 Check: Ensure hardcoded email and UID support accounts are purged
      final hasHardcodedEmail = content.contains('hiddenpantry.support@gmail.com');
      final hasHardcodedUid = content.contains('K35k8MPFWSbmKo3CTe8Wz8waZAS2');
      
      expect(hasHardcodedEmail, isFalse, 
          reason: 'VULNERABILITY DETECTED (HP-01): Hardcoded administrative email support backdoor remains in rules.');
      expect(hasHardcodedUid, isFalse, 
          reason: 'VULNERABILITY DETECTED (HP-01): Hardcoded administrative UID backdoor remains in rules.');
          
      // HP-05 Check: Ensure E2EE user keys collection is isolated and isAdmin() bypass is purged
      final keyCollectionBlock = RegExp(r'match\s+/user_keys/\{userId\}\s*\{([\s\S]*?)\}');
      final matches = keyCollectionBlock.allMatches(content);
      expect(matches.isNotEmpty, isTrue, reason: 'E2EE keys collection path must be defined for scanning');
      
      for (final match in matches) {
        final blockContent = match.group(1) ?? '';
        final hasAdminOverride = blockContent.contains('isAdmin()');
        expect(hasAdminOverride, isFalse, 
            reason: 'VULNERABILITY DETECTED (HP-05): Administrative bypass override detected in client-side private key backup rules.');
      }
      
      print('🟢 SAST SCAN SUCCESS: firestore.rules passed all administrative access and cryptographic isolation checks!');
    });

    test('HP-02: Scanning storage.rules for dangerous global recursive wildcard fallbacks', () {
      final file = File('storage.rules');
      expect(file.existsSync(), isTrue, reason: 'storage.rules must exist for audit scanning');
      
      final content = file.readAsStringSync();
      
      // HP-02 Check: Ensure match /{allPaths=**} is purged or restricted
      final hasGlobalWildcard = content.contains('match /{allPaths=**}');
      final hasGlobalBypass = content.contains('allow read, write: if isAuthenticated()') && hasGlobalWildcard;
      
      expect(hasGlobalBypass, isFalse, 
          reason: 'VULNERABILITY DETECTED (HP-02): Permissive global catch-all write fallback is active.');
          
      print('🟢 SAST SCAN SUCCESS: storage.rules passed all storage bucket directory isolation checks!');
    });

    test('HP-04: Scanning AndroidManifest.xml for unencrypted HTTP cleartext permission attributes', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist for audit scanning');
      
      final content = file.readAsStringSync();
      
      // HP-04 Check: Ensure usesCleartextTraffic is disabled
      final hasCleartextAllowed = content.contains('android:usesCleartextTraffic="true"');
      
      expect(hasCleartextAllowed, isFalse, 
          reason: 'VULNERABILITY DETECTED (HP-04): Manifest explicitly allows unencrypted cleartext HTTP traffic.');
          
      print('🟢 SAST SCAN SUCCESS: AndroidManifest.xml passed all transport security and cleartext audit gates!');
    });
  });
}
