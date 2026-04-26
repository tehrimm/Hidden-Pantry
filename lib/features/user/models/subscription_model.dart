import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String id;
  final String planName;
  final double price;
  final String interval;
  final DateTime expiryDate;
  final String nutritionistId;
  final String status;

  SubscriptionModel({
    required this.id,
    required this.planName,
    required this.price,
    required this.interval,
    required this.expiryDate,
    required this.nutritionistId,
    this.status = 'active',
  });

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      id: doc.id,
      planName: data['planName'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      interval: data['interval'] ?? 'month',
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      nutritionistId: data['nutritionistId'] ?? '',
      status: data['status'] ?? 'active',
    );
  }

  int daysRemaining([DateTime? now]) {
    final reference = now ?? DateTime.now();
    if (expiryDate.isBefore(reference)) return 0;
    return expiryDate.difference(reference).inDays;
  }

  bool isActive([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return (status == 'active' || status == 'trialing') && daysRemaining(reference) > 0;
  }
}
