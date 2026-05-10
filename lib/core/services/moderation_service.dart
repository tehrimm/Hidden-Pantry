import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal();

  /// Report a piece of content (recipe, review, comment, etc.)
  Future<void> reportContent({
    required String contentType, // 'recipe', 'review', 'user'
    required String contentId,
    required String authorId,
    required String reason,
    String? additionalDetails,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('reports').add({
      'reporterId': user.uid,
      'reporterEmail': user.email,
      'contentType': contentType,
      'contentId': contentId,
      'authorId': authorId,
      'reason': reason,
      'details': additionalDetails,
      'status': 'pending', // pending, reviewed, dismissed
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Block a user so their content is hidden from the current user
  Future<void> blockUser(String userIdToBlock) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
    }, SetOptions(merge: true));
  }

  /// Unblock a user
  Future<void> unblockUser(String userIdToUnblock) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'blockedUsers': FieldValue.arrayRemove([userIdToUnblock]),
    });
  }

  /// Get list of blocked user IDs for the current user
  Future<List<String>> getBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null || data['blockedUsers'] == null) return [];

    return List<String>.from(data['blockedUsers']);
  }
}
