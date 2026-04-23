import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
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

          // Decorative corner shapes
          Positioned(
            top: -30.sh, right: -30.sw,
            child: Container(width: 120.sw, height: 120.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _orange.withValues(alpha: 0.06))),
          ),
          Positioned(
            bottom: -40.sh, left: -40.sw,
            child: Container(width: 160.sw, height: 160.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _purple.withValues(alpha: 0.04))),
          ),
          Positioned(
            top: 200.sh, left: 16.sw,
            child: Container(width: 10.sw, height: 10.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _orange.withValues(alpha: 0.15))),
          ),
          Positioned(
            top: 320.sh, right: 20.sw,
            child: Transform.rotate(angle: math.pi / 4,
              child: Container(width: 16.sw, height: 16.sw,
                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3.sw)))),
          ),
          
          // Main Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 96.sh),
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
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _orange,
                                  strokeWidth: 2.5,
                                ),
                              );
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

                            int animIndex = 0;
                            return ListView(
                              padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
                              children: [
                                if (active.isNotEmpty) ...[
                                  _FadeSlideEntry(
                                    delayMs: 100,
                                    child: _sectionHeader('Active'),
                                  ),
                                  SizedBox(height: 10.sh),
                                  ...active.map((doc) {
                                    animIndex++;
                                    return _FadeSlideEntry(
                                      delayMs: 100 + (animIndex * 120),
                                      child: _subscriptionCard(doc),
                                    );
                                  }),
                                  SizedBox(height: 24.sh),
                                ],
                                if (expired.isNotEmpty) ...[
                                  _FadeSlideEntry(
                                    delayMs: 100 + (animIndex * 120) + 100,
                                    child: _sectionHeader('Past'),
                                  ),
                                  SizedBox(height: 10.sh),
                                  ...expired.map((doc) {
                                    animIndex++;
                                    return _FadeSlideEntry(
                                      delayMs: 100 + (animIndex * 120),
                                      child: _subscriptionCard(doc),
                                    );
                                  }),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

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
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Row(
      children: [
        Container(
          width: 4.sw,
          height: 18.sh,
          decoration: BoxDecoration(
            color: label == 'Active' ? _green : Colors.grey,
            borderRadius: BorderRadius.circular(2.sw),
          ),
        ),
        SizedBox(width: 10.sw),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _purple.withValues(alpha: 0.5),
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'Satoshi',
            letterSpacing: 1.5,
          ),
        ),
      ],
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

    // Determine tier icon
    IconData tierIcon = Icons.star_border_rounded;
    Color tierColor = _orange;
    final planStr = plan.toString().toLowerCase();
    if (planStr.contains('platinum')) {
      tierIcon = Icons.diamond_rounded;
      tierColor = const Color(0xFF7C4DFF);
    } else if (planStr.contains('gold')) {
      tierIcon = Icons.star_rounded;
      tierColor = const Color(0xFFFFC107);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.sw),
          onTap: () => HapticFeedback.lightImpact(),
          child: Padding(
            padding: EdgeInsets.all(20.sw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Avatar circle with gradient
                    Container(
                      width: 48.sw,
                      height: 48.sw,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            tierColor.withValues(alpha: 0.2),
                            tierColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(tierIcon, color: tierColor, size: 24.sw),
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
                          SizedBox(height: 3.sh),
                          Text(
                            plan,
                            style: TextStyle(
                              color: _purple.withValues(alpha: 0.45),
                              fontSize: 13.sp,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge with dot
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.sw),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.sw,
                            height: 6.sw,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.sw),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.sh),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _purple.withValues(alpha: 0.0),
                        _purple.withValues(alpha: 0.08),
                        _purple.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.sh),

                // Price & expiry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (price != null)
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Rs. ${double.tryParse(price.toString())?.toStringAsFixed(0) ?? "0"}',
                              style: TextStyle(
                                color: _purple,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                            TextSpan(
                              text: ' / $interval',
                              style: TextStyle(
                                color: _purple.withValues(alpha: 0.4),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
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
                          color: _purple.withValues(alpha: 0.45),
                          fontSize: 12.sp,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),

                // Show remaining days for cancelled subscriptions
                if (isCancelled && expiry != null && expiry.isAfter(DateTime.now())) ...[        
                  SizedBox(height: 14.sh),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 12.sh),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14.sw),
                      border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.5)),
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
                    height: 46.sh,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _confirmCancel(doc.id, expiry);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: BorderSide(color: _red.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.sw)),
                      ),
                      child: Text(
                        'Cancel Subscription',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Satoshi'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(String docId, DateTime? expiry) async {
    final confirm = await GlassDialog.show<bool>(
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
      child: _FadeSlideEntry(
        delayMs: 200,
        child: Padding(
          padding: EdgeInsets.all(40.sw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90.sw,
                height: 90.sw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _orange.withValues(alpha: 0.15),
                      _orange.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.subscriptions_outlined, color: _orange, size: 38.sw),
              ),
              SizedBox(height: 28.sh),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _purple.withValues(alpha: 0.55),
                  fontSize: 15.sp,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── Staggered Fade+Slide Animation Widget ───
class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, this.delayMs = 0});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
