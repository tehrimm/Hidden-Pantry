import 'package:cloud_firestore/cloud_firestore.dart';

class Nutritionist {
  final String uid;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? licenseNumber;
  final String? certificateUrl;
  final String? organizationName;
  final String? expiryDate;
  final String verificationStatus; // pending, approved, rejected
  final String? rejectionReason;
  final DateTime? rejectionDate;
  final bool hasLoggedInAfterRejection;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? stripeConnectedAccountId;

  const Nutritionist({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.licenseNumber,
    this.certificateUrl,
    this.organizationName,
    this.expiryDate,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.rejectionDate,
    this.hasLoggedInAfterRejection = false,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.stripeConnectedAccountId,
  });

  bool get isApproved => verificationStatus.toLowerCase() == 'approved';
  bool get isPending => verificationStatus.toLowerCase() == 'pending';
  bool get isRejected => verificationStatus.toLowerCase() == 'rejected';

  Nutritionist copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? licenseNumber,
    String? certificateUrl,
    String? organizationName,
    String? expiryDate,
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
      organizationName: organizationName ?? this.organizationName,
      expiryDate: expiryDate ?? this.expiryDate,
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

  factory Nutritionist.fromJson(Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    final created = _toDate(json['createdAt']) ?? DateTime.now();
    final updated = _toDate(json['updatedAt']) ?? created;

    return Nutritionist(
      uid: json['uid'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      licenseNumber: json['licenseNumber'],
      certificateUrl: json['certificateUrl'],
      organizationName: json['organizationName'],
      expiryDate: json['expiryDate'],
      verificationStatus: json['verificationStatus'] ?? 'pending',
      rejectionReason: json['rejectionReason'],
      rejectionDate: _toDate(json['rejectionDate']),
      hasLoggedInAfterRejection: (json['hasLoggedInAfterRejection'] as bool?) ?? false,
      lastLoginAt: _toDate(json['lastLoginAt']),
      createdAt: created,
      updatedAt: updated,
      stripeConnectedAccountId: json['stripeConnectedAccountId'],
    );
  }

  Map<String, dynamic> toJson() {
    Timestamp _ts(DateTime dt) => Timestamp.fromDate(dt);

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
      'rejectionDate': rejectionDate != null ? _ts(rejectionDate!) : null,
      'hasLoggedInAfterRejection': hasLoggedInAfterRejection,
      'lastLoginAt': lastLoginAt != null ? _ts(lastLoginAt!) : null,
      'createdAt': _ts(createdAt),
      'updatedAt': _ts(updatedAt),
      'stripeConnectedAccountId': stripeConnectedAccountId,
    }..removeWhere((key, value) => value == null);
  }
}

