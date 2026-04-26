import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserStatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> updateStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> statusData = {
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    try {
      // We try both collections because we don't know the role here easily without a query,
      // but we can optimize by checking where the user document exists or using a shared field.
      // For now, let's try to determine the role or just update both if they exist.
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).update(statusData);
      }

      final nutritionistDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
      if (nutritionistDoc.exists) {
        await _firestore.collection('nutritionists').doc(user.uid).update(statusData);
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Stream<DocumentSnapshot> getStatusStream(String uid, bool isNutritionist) {
    final collection = isNutritionist ? 'nutritionists' : 'users';
    return _firestore.collection(collection).doc(uid).snapshots();
  }
}
