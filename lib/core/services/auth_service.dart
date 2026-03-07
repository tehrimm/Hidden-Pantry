import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logAuthError('registerWithEmail', e);
      rethrow;
    }
  }

  Future<UserCredential?> loginWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logAuthError('loginWithEmail', e);
      rethrow;
    }
  }

  // Diagnostic helper for DEVELOPER_ERROR and other common issues
  void _logAuthError(String context, dynamic error) {
    debugPrint('[AuthService] Error in $context: $error');
    final errStr = error.toString();
    if (errStr.contains('10') || errStr.contains('DEVELOPER_ERROR')) {
       debugPrint('---------------------------------------------------------');
       debugPrint('⚠️ [AuthService] DEVELOPER_ERROR (Code 10) Detected!');
       debugPrint('Possible causes:');
       debugPrint('1. SHA-1 fingerprint mismatch in Firebase Console.');
       debugPrint('2. google-services.json is outdated or missing.');
       debugPrint('3. App ID / Package name mismatch.');
       debugPrint('Action: Re-check your Firebase Android config and SHA-1 keys.');
       debugPrint('---------------------------------------------------------');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }
}


