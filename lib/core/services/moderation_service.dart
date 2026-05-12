import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

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
    Map<String, dynamic>? metadata, // Added metadata for extra IDs (e.g., parentReviewId)
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
      'metadata': metadata, // Store metadata
      'status': 'pending', // pending, reviewed, dismissed
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Block a user so their content is hidden from the current user
  Future<void> blockUser(String userIdToBlock, {String? authorName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> updateData = {
      'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
    };

    if (authorName != null || photoUrl != null) {
      updateData['blockedUserProfiles'] = {
        userIdToBlock: {
          'name': authorName,
          'photoUrl': photoUrl,
        }
      };
    }

    await _firestore.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
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

  /// Get the cached profiles of blocked users
  Future<Map<String, dynamic>> getBlockedUserProfiles() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return {};

    final data = doc.data();
    if (data == null || data['blockedUserProfiles'] == null) return {};

    return data['blockedUserProfiles'] as Map<String, dynamic>;
  }
  /// Get all pending reports grouped by contentId with counts
  Future<List<Map<String, dynamic>>> getReportSummary() async {
    final snapshot = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .get();

    final Map<String, Map<String, dynamic>> summary = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final contentId = data['contentId'] as String;

      if (!summary.containsKey(contentId)) {
        summary[contentId] = {
          'contentId': contentId,
          'contentType': data['contentType'],
          'authorId': data['authorId'],
          'reason': data['reason'], // First reason
          'reportCount': 0,
          'reports': [],
        };
      }
      summary[contentId]!['reportCount']++;
      summary[contentId]!['reports'].add({'id': doc.id, ...data});
      // Carry over metadata to summary
      if (data['metadata'] != null) {
        summary[contentId]!['metadata'] = data['metadata'];
      }
    }

    return summary.values.toList();
  }

  /// Suspend a user for a specific number of days
  Future<void> suspendUser(String userId, int days) async {
    final until = DateTime.now().add(Duration(days: days));
    await _firestore.collection('users').doc(userId).update({
      'suspendedUntil': Timestamp.fromDate(until),
    });
  }

  /// Dismiss all reports for a contentId
  Future<void> dismissReports(String contentId) async {
    final snapshot = await _firestore
        .collection('reports')
        .where('contentId', isEqualTo: contentId)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'reviewed'});
    }
    await batch.commit();
  }

  /// Delete content, mark reports as reviewed, and send warning notification
  Future<void> takeAction(String contentType, String contentId, String action, String authorId) async {
      if (contentType == 'review') {
        await _firestore.collection('reviews').doc(contentId).delete();
      } else if (contentType == 'recipe') {
        await _firestore.collection('recipes').doc(contentId).delete();
      } else if (contentType == 'reply') {
        // Find the report to get parentReviewId from metadata
        final reportSnap = await _firestore
            .collection('reports')
            .where('contentId', isEqualTo: contentId)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        
        if (reportSnap.docs.isNotEmpty) {
          final metadata = reportSnap.docs.first.data()['metadata'] as Map<String, dynamic>?;
          final reviewId = metadata?['parentReviewId'] as String?;
          if (reviewId != null) {
            await _firestore
                .collection('reviews')
                .doc(reviewId)
                .collection('replies')
                .doc(contentId)
                .delete();
          }
        }
      }
      
      await dismissReports(contentId);

      // Send warning notification to the author
      try {
        await NotificationService().sendNotification(
          recipientId: authorId,
          title: "Content Removed & Warning",
          body: "Your $contentType has been removed due to community reports. Please review our community guidelines. Further violations may result in account suspension.",
          type: NotificationType.admin_alert,
          playSound: true,
        );
      } catch (e) {
        print("Failed to send warning notification: $e");
      }
    }
}
