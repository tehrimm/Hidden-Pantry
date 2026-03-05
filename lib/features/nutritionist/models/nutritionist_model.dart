import 'package:cloud_firestore/cloud_firestore.dart';

class Nutritionist {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String licenseNumber;
  final String certificateUrl;
  final String? organizationName;
  final String? expiryDate;
  final String verificationStatus; // "pending" | "approved" | "rejected"
  final String? rejectionReason;
  final DateTime? rejectionDate;
  final bool hasLoggedInAfterRejection;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? stripeConnectedAccountId;

  Nutritionist({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.licenseNumber,
    required this.certificateUrl,
    this.organizationName,
    this.expiryDate,
    required this.verificationStatus,
    this.rejectionReason,
    this.rejectionDate,
    required this.hasLoggedInAfterRejection,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.stripeConnectedAccountId,
  });

  factory Nutritionist.fromJson(Map<String, dynamic> json) {
    return Nutritionist(
      uid: json['uid'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      licenseNumber: json['licenseNumber'] as String,
      certificateUrl: json['certificateUrl'] as String,
      organizationName: json['organizationName'] as String?,
      expiryDate: json['expiryDate'] as String?,
      verificationStatus: json['verificationStatus'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      rejectionDate: json['rejectionDate'] != null
          ? (json['rejectionDate'] as Timestamp).toDate()
          : null,
      hasLoggedInAfterRejection: json['hasLoggedInAfterRejection'] as bool? ?? false,
      lastLoginAt: json['lastLoginAt'] != null
          ? (json['lastLoginAt'] as Timestamp).toDate()
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      stripeConnectedAccountId: json['stripeConnectedAccountId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'licenseNumber': licenseNumber,
      'certificateUrl': certificateUrl,
      'organizationName': organizationName,
      'expiryDate': expiryDate,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'rejectionDate': rejectionDate != null ? Timestamp.fromDate(rejectionDate!) : null,
      'hasLoggedInAfterRejection': hasLoggedInAfterRejection,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stripeConnectedAccountId': stripeConnectedAccountId,
    };
  }

  Nutritionist copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? licenseNumber,
    String? certificateUrl,
    String? verificationStatus,
    String? rejectionReason,
    DateTime? rejectionDate,
    bool? hasLoggedInAfterRejection,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? stripeConnectedAccountId,
  }) {
    return Nutritionist(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectionDate: rejectionDate ?? this.rejectionDate,
      hasLoggedInAfterRejection: hasLoggedInAfterRejection ?? this.hasLoggedInAfterRejection,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stripeConnectedAccountId: stripeConnectedAccountId ?? this.stripeConnectedAccountId,
    );
  }

  bool get isPending => verificationStatus == 'pending';
  bool get isApproved => verificationStatus == 'approved';
  bool get isRejected => verificationStatus == 'rejected';
}



