import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore CRUD for payment methods (cards & wallets).
class PaymentService {
  const PaymentService();

  CollectionReference<Map<String, dynamic>> _ref() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('payment_methods');
  }

  // ─── Cards ─────────────────────────────────────────────

  Future<void> saveCard({
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardHolderName,
    String? stripePaymentMethodId,
  }) async {
    final masked = '**** **** **** ${cardNumber.replaceAll(' ', '').substring(cardNumber.replaceAll(' ', '').length - 4)}';

    final data = {
      'type': 'card',
      'maskedNumber': masked,
      'expiryDate': expiryDate,
      'cardHolderName': cardHolderName,
      'isDefault': false,
      'isVerified': stripePaymentMethodId != null,
      'stripePaymentMethodId': stripePaymentMethodId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = _ref();

    // If this is the first method, make it default
    final existing = await ref.limit(1).get();
    if (existing.docs.isEmpty) {
      data['isDefault'] = true;
    }

    await ref.add(data);
  }

  // ─── Wallets (Easypaisa / JazzCash) ────────────────────

  Future<void> saveWallet({
    required String phoneNumber,
    required String accountName,
    required String walletType, // 'easypaisa' | 'jazzcash'
  }) async {
    final masked = '${phoneNumber.substring(0, 4)}*****${phoneNumber.substring(phoneNumber.length - 2)}';

    final data = {
      'type': walletType,
      'maskedNumber': masked,
      'accountName': accountName,
      'phone': phoneNumber,
      'isDefault': false,
      'isVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = _ref();
    final existing = await ref.limit(1).get();
    if (existing.docs.isEmpty) {
      data['isDefault'] = true;
    }

    await ref.add(data);
  }

  // ─── Read ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCards() async {
    final snap = await _ref().orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, dynamic>?> getDefaultPaymentMethod() async {
    final snap = await _ref().where('isDefault', isEqualTo: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return {'id': d.id, ...d.data()};
  }

  // ─── Update ────────────────────────────────────────────

  Future<void> setDefaultPaymentMethod(String id) async {
    final ref = _ref();
    final all = await ref.get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in all.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == id});
    }
    await batch.commit();
  }

  // ─── Delete ────────────────────────────────────────────

  Future<void> deleteCard(String id) async {
    final ref = _ref();
    final docRef = ref.doc(id);
    final doc = await docRef.get();
    final wasDefault = doc.data()?['isDefault'] == true;

    await docRef.delete();

    // Promote next method to default if the deleted one was default
    if (wasDefault) {
      final remaining = await ref.orderBy('createdAt').limit(1).get();
      if (remaining.docs.isNotEmpty) {
        await remaining.docs.first.reference.update({'isDefault': true});
      }
    }
  }
}
