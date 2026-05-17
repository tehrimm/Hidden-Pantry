import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserStatusService {
  static UserStatusService? _instance;
  
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription? _authSub;

  UserStatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  factory UserStatusService.instance() {
    _instance ??= UserStatusService();
    return _instance!;
  }

  /// Starts a global listener to update status on login/logout
  void startGlobalListener() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        updateStatus(true);
      }
    });
  }

  void stopGlobalListener() {
    _authSub?.cancel();
  }

  Future<void> updateStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> statusData = {
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    try {
      final batch = _firestore.batch();
      
      final userRef = _firestore.collection('users').doc(user.uid);
      final nutRef = _firestore.collection('nutritionists').doc(user.uid);

      // Check both collections in parallel
      final results = await Future.wait([userRef.get(), nutRef.get()]);
      
      bool updated = false;
      if (results[0].exists) {
        batch.update(userRef, statusData);
        updated = true;
      }
      if (results[1].exists) {
        batch.update(nutRef, statusData);
        updated = true;
      }

      if (updated) await batch.commit();
    } catch (e) {
      debugPrint('Status update error for ${user.uid}: $e');
    }
  }

  Stream<DocumentSnapshot> getStatusStream(String uid, bool isNutritionist) {
    final collection = isNutritionist ? 'nutritionists' : 'users';
    return _firestore.collection(collection).doc(uid).snapshots();
  }
}
