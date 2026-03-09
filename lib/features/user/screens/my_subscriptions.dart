import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFEF8A54);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _red = Color(0xFFE53935);
  static const Color _cardColor = Color(0xFFF9E3D5);

  final _stripeService = StripeService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final topPad = MediaQuery.of(context).padding.top;

    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          // Fixed Header
          Positioned(
            left: 30.sw,
            top: topPad + 36.sh,
            child: BackButtonWidget(color: _purple),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topPad + 36.sh,
            height: 50.sh,
            child: Center(
              child: Text(
                'My Subscriptions',
                style: TextStyle(
                  color: _purple,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 96.sh), // Standardized gap for fixed header
                Expanded(
                  child: uid == null
                      ? _emptyState('Please sign in to view your subscriptions.')
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('subscriptions')
                              .where('userId', isEqualTo: uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return _emptyState('Error loading subscriptions.');
                            }

                            final docs = snapshot.data?.docs ?? [];
                            
                            // Sort client-side by startDate descending
                            docs.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aDate = aData['startDate'] as Timestamp?;
                              final bDate = bData['startDate'] as Timestamp?;
                              if (aDate == null || bDate == null) return 0;
                              return bDate.compareTo(aDate);
                            });

                            if (docs.isEmpty) {
                              return _emptyState(
                                "No subscriptions yet.\nBrowse nutritionists and subscribe to a plan!",
                              );
                            }

                            // Group by nutritionist to show only the highest active tier or latest expired per expert
                            final active = <QueryDocumentSnapshot>[];
                            final expired = <QueryDocumentSnapshot>[];
                            
                            final Map<String, List<QueryDocumentSnapshot>> groupedByNut = {};
                            for (final doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final nutId = data['nutritionistId'] as String?;
                              if (nutId != null) {
                                groupedByNut.putIfAbsent(nutId, () => []).add(doc);
                              }
                            }

                            for (final entry in groupedByNut.entries) {
                              final nutDocs = entry.value;
                              QueryDocumentSnapshot? bestActiveDoc;
                              QueryDocumentSnapshot? latestExpiredDoc;
                              int highestTier = -1;
                              DateTime? latestExp;

                              for (final doc in nutDocs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final status = data['status'] as String?;
                                final isCancelled = data['isCancelled'] == true;
                                final expiryTs = data['expiryDate'];
                                DateTime? exp;
                                if (expiryTs is Timestamp) exp = expiryTs.toDate();
                                else if (expiryTs is String) exp = DateTime.tryParse(expiryTs);
                                
                                final stillValid = exp != null && exp.isAfter(DateTime.now());

                                bool isActive = status == 'active' || status == 'pending' || status == 'downgrading' || status == 'trialing' || (isCancelled && stillValid);

                                if (isActive) {
                                  int currentDocTier = 0;
                                  dynamic rawTier = data['tierLevel'];
                                  if (rawTier is num) currentDocTier = rawTier.toInt();
                                  else if (rawTier is String) currentDocTier = int.tryParse(rawTier) ?? 0;
                                  
                                  if (currentDocTier == 0) {
                                      final planTitle = (data['planId'] ?? '').toString().toLowerCase();
                                      if (planTitle.contains('platinum')) currentDocTier = 3;
                                      else if (planTitle.contains('gold')) currentDocTier = 2;
                                      else currentDocTier = 1;
                                  }

                                  // If there are multiple active tiers, pick the highest.
                                  // If they are the same tier, pick the one with a later expiry or just the first encountered
                                  if (currentDocTier > highestTier) {
                                    highestTier = currentDocTier;
                                    bestActiveDoc = doc;
                                  }
                                } else {
                                  if (latestExp == null || (exp != null && exp.isAfter(latestExp))) {
                                    latestExp = exp;
                                    latestExpiredDoc = doc;
                                  }
                                }
                              }

                              if (bestActiveDoc != null) {
                                active.add(bestActiveDoc);
                              } else if (latestExpiredDoc != null) {
                                expired.add(latestExpiredDoc);
                              }
                            }

                            return ListView(
                              padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
                              children: [
                                if (active.isNotEmpty) ...[
                                  _sectionHeader('Active'),
                                  SizedBox(height: 10.sh),
                                  ...active.map((doc) => _subscriptionCard(doc)),
                                  SizedBox(height: 24.sh),
                                ],
                                if (expired.isNotEmpty) ...[
                                  _sectionHeader('Past'),
                                  SizedBox(height: 10.sh),
                                  ...expired.map((doc) => _subscriptionCard(doc)),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label,
      style: TextStyle(
        color: _purple.withValues(alpha: 0.5),
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        fontFamily: 'Satoshi',
        letterSpacing: 1.sw,
      ),
    );
  }

  Widget _subscriptionCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isActive = data['status'] == 'active' || data['status'] == 'pending';
    final isCancelled = data['isCancelled'] == true;
    final storedName = data['nutritionistName'] as String?;
    final plan = data['planId'] ?? 'Plan';
    final price = data['price'];
    final interval = data['interval'] ?? 'month';
    final expiryTs = data['expiryDate'];
    final nutritionistId = data['nutritionistId'] as String?;
    DateTime? expiry;
    if (expiryTs is Timestamp) {
      expiry = expiryTs.toDate();
    } else if (expiryTs is String) {
      expiry = DateTime.tryParse(expiryTs);
    }

    // If name not stored, fetch from nutritionists collection
    if (storedName == null || storedName.isEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: nutritionistId != null
            ? FirebaseFirestore.instance.collection('nutritionists').doc(nutritionistId).get()
            : null,
        builder: (context, snap) {
          String fetchedName = 'Nutritionist';
          if (snap.hasData && snap.data!.exists) {
            final nutData = snap.data!.data() as Map<String, dynamic>?;
            fetchedName = nutData?['fullName'] ?? 'Nutritionist';
          }
          return _buildSubscriptionCard(
            doc: doc, name: fetchedName, plan: plan, price: price,
            interval: interval, expiry: expiry, isActive: isActive, isCancelled: isCancelled,
          );
        },
      );
    }

    return _buildSubscriptionCard(
      doc: doc, name: storedName, plan: plan, price: price,
      interval: interval, expiry: expiry, isActive: isActive, isCancelled: isCancelled,
    );
  }

  Widget _buildSubscriptionCard({
    required QueryDocumentSnapshot doc,
    required String name,
    required String plan,
    required dynamic price,
    required String interval,
    required DateTime? expiry,
    required bool isActive,
    required bool isCancelled,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    Color statusColor = isActive ? (isCancelled ? Colors.amber.shade700 : _green) : Colors.grey;
    String statusText = isActive
        ? (isCancelled ? 'Cancelling' : 'Active')
        : 'Expired';

    return Container(
      margin: EdgeInsets.only(bottom: 14.sh),
      padding: EdgeInsets.all(20.sw),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20.sw),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.04),
            blurRadius: 16.sw,
            offset: Offset(0, 4.sh),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Avatar
              Container(
                width: 46.sw,
                height: 46.sw,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.sw),
                ),
                child: Icon(Icons.person_rounded, color: _orange, size: 24.sw),
              ),
              SizedBox(width: 14.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: _purple,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    SizedBox(height: 2.sh),
                    Text(
                      plan,
                      style: TextStyle(
                        color: _purple.withValues(alpha: 0.5),
                        fontSize: 13.sp,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.sw),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.sh),
          Divider(color: _purple.withValues(alpha: 0.06), height: 1.sh),
          SizedBox(height: 16.sh),

          // Price & expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price != null ? 'Rs. ${double.tryParse(price.toString())?.toStringAsFixed(2) ?? "0.00"} / $interval' : '',
                style: TextStyle(
                  color: _purple.withValues(alpha: 0.7),
                  fontSize: 14.sp,
                  fontFamily: 'Satoshi',
                ),
              ),
              if (expiry != null)
                Text(
                  isActive
                      ? (isCancelled
                          ? (data['status'] == 'downgrading' ? 'Active until ${_formatDate(expiry)} (Downgrading)' : 'Ends ${_formatDate(expiry)}')
                          : 'Renews ${_formatDate(expiry)}')
                      : 'Ended ${_formatDate(expiry)}',
                  style: TextStyle(
                    color: _purple.withValues(alpha: 0.5),
                    fontSize: 12.sp,
                    fontFamily: 'Satoshi',
                  ),
                ),
            ],
          ),

          // Show remaining days for cancelled subscriptions
          if (isCancelled && expiry != null && expiry.isAfter(DateTime.now())) ...[        
            SizedBox(height: 12.sh),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 10.sh),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12.sw),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: Colors.amber.shade700, size: 18.sw),
                  SizedBox(width: 10.sw),
                  Expanded(
                    child: Text(
                      '${expiry.difference(DateTime.now()).inDays} days remaining — access until ${_formatDate(expiry)}',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cancel button for active, non-cancelled
          if (isActive && !isCancelled) ...[
            SizedBox(height: 16.sh),
            SizedBox(
              width: double.infinity,
              height: 44.sh,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(doc.id, expiry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: BorderSide(color: _red.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
                ),
                child: Text(
                  'Cancel Subscription',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Satoshi'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(String docId, DateTime? expiry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.sw)),
        title: Text('Cancel Subscription?', style: TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: Text(
          expiry != null
              ? 'You will still have access until ${_formatDate(expiry)}. You will not be charged again.'
              : 'Are you sure you want to cancel?',
          style: TextStyle(color: _purple.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: _purple, fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _stripeService.cancelSubscription(subscriptionDocId: docId);
      if (mounted) {
        Toaster.show(context, 'Subscription cancelled. You retain access until the end of the billing period.');
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, StripeService.friendlyError(e), isError: true);
      }
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.sw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.sw,
              height: 80.sw,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.subscriptions_outlined, color: _orange, size: 36.sw),
            ),
            SizedBox(height: 24.sh),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _purple.withValues(alpha: 0.6),
                fontSize: 15.sp,
                fontFamily: 'Satoshi',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
