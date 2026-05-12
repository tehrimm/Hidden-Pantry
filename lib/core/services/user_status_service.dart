import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserStatusService {
  static UserStatusService? _instance;
  
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserStatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  factory UserStatusService.instance() {
    _instance ??= UserStatusService();
    return _instance!;
  }

  Future<void> updateStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> statusData = {
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).update(statusData);
      }
    } catch (e) {
      debugPrint('Status update skipped for users collection: $e');
    }

    try {
      final nutritionistDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
      if (nutritionistDoc.exists) {
        await _firestore.collection('nutritionists').doc(user.uid).update(statusData);
      }
    } catch (e) {
      debugPrint('Status update skipped for nutritionists collection: $e');
    }
  }

  Stream<DocumentSnapshot> getStatusStream(String uid, bool isNutritionist) {
    final collection = isNutritionist ? 'nutritionists' : 'users';
    return _firestore.collection(collection).doc(uid).snapshots();
  }
}
