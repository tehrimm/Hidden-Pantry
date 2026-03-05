import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String recipeId;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String comment;
  final String? imageUrl;
  final double rating;
  final int likes;
  final List<String> likedBy; // List of user UIDs who liked
  final DateTime createdAt;
  final List<Review> replies; // Nested replies

  Review({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.comment,
    this.imageUrl,
    required this.rating,
    this.likes = 0,
    this.likedBy = const [],
    required this.createdAt,
    this.replies = const [],
  });

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }

  factory Review.fromJson(Map<String, dynamic> json, {String? docId}) {
    return Review(
      id: docId ?? json['id'] ?? '',
      recipeId: json['recipeId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',
      userImageUrl: json['userImageUrl'] ?? '',
      comment: json['comment'] ?? '',
      imageUrl: json['imageUrl'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      likes: json['likes'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      createdAt: _parseDate(json['createdAt']),
      replies: [],
    );
  }

  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      recipeId: data['recipeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userImageUrl: data['userImageUrl'] ?? '',
      comment: data['comment'] ?? '',
      imageUrl: data['imageUrl'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: _parseDate(data['createdAt']),
      replies: [], // Handle replies separately or as sub-collection
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'comment': comment,
      'imageUrl': imageUrl,
      'rating': rating,
      'likes': likes,
      'likedBy': likedBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}



