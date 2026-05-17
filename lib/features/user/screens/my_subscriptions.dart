import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/widgets/app_dialog.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/features/user/screens/premium_paywall_screen.dart';


class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  int _pastLimit = 3;
  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFEF8A54);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _red = Color(0xFFE53935);



  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final topPad = MediaQuery.of(context).padding.top;

    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF3EB), Color(0xFFF6DFD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.4, 1.0],
              ),
            ),
          ),

          // Decorative Orbs
          const _SubBackgroundPattern(),

          const PatternBackground(),

          // Glossy Overlays
          Positioned(
            top: -50.sh,
            right: -50.sw,
            child: _GlowCircle(color: _orange.withValues(alpha: 0.1), size: 350.sw),
          ),
          Positioned(
            bottom: -80.sh,
            left: -80.sw,
            child: _GlowCircle(color: _purple.withValues(alpha: 0.08), size: 450.sw),
          ),
          Positioned(
            top: 250.sh,
            left: -20.sw,
            child: _GlowCircle(color: _orange.withValues(alpha: 0.05), size: 200.sw),
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

                            // Categorize subscriptions
                            QueryDocumentSnapshot? appSub;
                            final Map<String, List<QueryDocumentSnapshot>> groupedByNut = {};

                            for (final doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final planId = (data['planId'] ?? '').toString();
                              
                              if (planId == 'platform_premium') {
                                // Keep only the most recent platform sub if multiple exist
                                if (appSub == null) {
                                  appSub = doc;
                                }
                              } else {
                                final nutId = data['nutritionistId'] as String?;
                                if (nutId != null) {
                                  groupedByNut.putIfAbsent(nutId, () => []).add(doc);
                                }
                              }
                            }

                            // Process nutritionist groups
                            final activeNuts = <QueryDocumentSnapshot>[];
                            final expiredNuts = <QueryDocumentSnapshot>[];
                            
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
                                bool isActive = status == 'active' || status == 'trialing' || (isCancelled && stillValid);

                                if (isActive) {
                                  int currentDocTier = 1;
                                  dynamic rawTier = data['tierLevel'];
                                  if (rawTier is num) currentDocTier = rawTier.toInt();
                                  if (currentDocTier > highestTier) {
                                    highestTier = currentDocTier;
                                    bestActiveDoc = doc;
                                  }
                                } else if (latestExp == null || (exp != null && exp.isAfter(latestExp))) {
                                  latestExp = exp;
                                  latestExpiredDoc = doc;
                                }
                              }
                              if (bestActiveDoc != null) activeNuts.add(bestActiveDoc);
                              else if (latestExpiredDoc != null) expiredNuts.add(latestExpiredDoc);
                            }

                            int animIndex = 0;
                            return ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
                              children: [
                                // 1. App Subscription Section
                                if (appSub != null) ...[
                                  _FadeSlideEntry(
                                    delayMs: 150,
                                    child: _sectionHeader('Platform Plan'),
                                  ),
                                  SizedBox(height: 12.sh),
                                  _FadeSlideEntry(
                                    delayMs: 300,
                                    child: _appSubscriptionCard(appSub),
                                  ),
                                  SizedBox(height: 36.sh),
                                ],

                                // 2. Nutritionists Section
                                if (activeNuts.isNotEmpty) ...[
                                  _FadeSlideEntry(
                                    delayMs: 400,
                                    child: _sectionHeader('Active Nutritionist Plans'),
                                  ),
                                  SizedBox(height: 12.sh),
                                  ...activeNuts.map((doc) {
                                    animIndex++;
                                    return _FadeSlideEntry(
                                      delayMs: 400 + (animIndex * 100),
                                      child: _subscriptionCard(doc),
                                    );
                                  }),
                                  SizedBox(height: 28.sh),
                                ],
                                
                                if (expiredNuts.isNotEmpty) ...[
                                  _FadeSlideEntry(
                                    delayMs: 500 + (animIndex * 100),
                                    child: _sectionHeader('Past Subscriptions'),
                                  ),
                                  SizedBox(height: 12.sh),
                                  ...expiredNuts.take(_pastLimit).map((doc) {
                                    animIndex++;
                                    return _FadeSlideEntry(
                                      delayMs: 500 + (animIndex * 100),
                                      child: _subscriptionCard(doc),
                                    );
                                  }),
                                  if (expiredNuts.length > _pastLimit)
                                    Padding(
                                      padding: EdgeInsets.only(top: 12.sh, bottom: 20.sh),
                                      child: Center(
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            setState(() {
                                              _pastLimit += 5;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(20.sw),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 12.sh),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(20.sw),
                                              border: Border.all(color: _purple.withValues(alpha: 0.1)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Load More History (${expiredNuts.length - _pastLimit})',
                                                  style: TextStyle(
                                                    color: _purple,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w800,
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                ),
                                                SizedBox(width: 8.sw),
                                                Icon(Icons.keyboard_arrow_down_rounded, color: _purple, size: 16.sw),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                SizedBox(height: 40.sh),
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
    return Padding(
      padding: EdgeInsets.only(left: 4.sw),
      child: Row(
        children: [
          Container(
            width: 3.sw,
            height: 14.sh,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_orange, _orange.withValues(alpha: 0.3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4.sw),
            ),
          ),
          SizedBox(width: 12.sw),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _purple.withValues(alpha: 0.4),
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
              fontFamily: 'Satoshi',
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: 12.sw),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_purple.withValues(alpha: 0.1), _purple.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
        ],
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

  Widget _appSubscriptionCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String?;
    final expiryTs = data['expiryDate'];
    DateTime? expiry;
    if (expiryTs is Timestamp) expiry = expiryTs.toDate();
    
    // 🛡️ FALLBACK: If trial and expiry missing, calculate from trial logic
    if (expiry == null && status == 'trialing') {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // This is a simplified fallback; ideally we'd pass the userDoc down
        // For now, we'll try to find 'trialExpiry' or similar in data
        final trialExp = data['trialExpiry'];
        if (trialExp is Timestamp) expiry = trialExp.toDate();
      }
    }
    
    final isActive = status == 'active' || status == 'trialing';
    final isCancelled = data['isCancelled'] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 24.sh),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.sw),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(32.sw),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32.sw),
                    onTap: () {
                       HapticFeedback.mediumImpact();
                       _showSubscriptionDetails(doc);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(26.sw),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.sw),
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18.sw),
                                ),
                                child: Icon(Icons.auto_awesome_rounded, color: _orange, size: 28.sw),
                              ),
                              _miniStatusBadge(
                                isActive ? (isCancelled ? 'Cancelling' : 'Premium') : 'Expired',
                                isActive ? (isCancelled ? Colors.amber.shade700 : _orange) : Colors.grey
                              ),
                            ],
                          ),
                          SizedBox(height: 24.sh),
                          Text(
                            "Hidden Pantry Premium",
                            style: TextStyle(
                              color: _purple,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                          SizedBox(height: 6.sh),
                          Text(
                            "Voice Mode, Smart Scanning, and offline access.",
                            style: TextStyle(
                              color: _purple.withValues(alpha: 0.5),
                              fontSize: 14.sp,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 24.sh),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 12.sh),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16.sw),
                              border: Border.all(color: _orange.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_rounded, color: _orange, size: 14.sw),
                                SizedBox(width: 8.sw),
                                Text(
                                  expiry != null 
                                    ? (status == 'trialing' 
                                        ? "Trial ends ${_formatDate(expiry)}" 
                                        : (isCancelled ? "Access till ${_formatDate(expiry)}" : "Renews ${_formatDate(expiry)}"))
                                    : "Premium Active",
                                  style: TextStyle(
                                    color: _purple,
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
                    ),
                  ),
                ),
                
                // Upgrade / Change Plan Button
                if (isActive && !isCancelled) ...[
                  Container(
                    margin: EdgeInsets.fromLTRB(26.sw, 0, 26.sw, 12.sh),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52.sh,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_orange, _orange.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(18.sw),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Upgrade / Change Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Satoshi',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Cancel Button
                if (isActive && !isCancelled) ...[
                  Container(
                    margin: EdgeInsets.fromLTRB(26.sw, 0, 26.sw, 26.sh),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _confirmCancel(doc.id, expiry);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52.sh,
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18.sw),
                          border: Border.all(color: _red.withValues(alpha: 0.1)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel Subscription',
                          style: TextStyle(
                            color: _red,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Satoshi',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Renew Button (Platform)
                if (isActive && isCancelled) ...[
                  Container(
                    margin: EdgeInsets.fromLTRB(26.sw, 0, 26.sw, 26.sh),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _confirmRenew(doc.id);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52.sh,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_orange, _orange.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(18.sw),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Renew Subscription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Satoshi',
                            letterSpacing: 0.5,
                          ),
                        ),
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

  Widget _statusBadge(String text, bool active) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 8.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          fontFamily: 'Satoshi',
          letterSpacing: 0.5,
        ),
      ),
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
      margin: EdgeInsets.only(bottom: 16.sh),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.sw),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24.sw),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24.sw),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSubscriptionDetails(doc);
                },
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
                            width: 52.sw,
                            height: 52.sw,
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
                            ),
                            child: Icon(tierIcon, color: tierColor, size: 26.sw),
                          ),
                          SizedBox(width: 16.sw),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: _purple,
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                SizedBox(height: 2.sh),
                                Text(
                                  plan,
                                  style: TextStyle(
                                    color: _purple.withValues(alpha: 0.4),
                                    fontSize: 13.sp,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _miniStatusBadge(statusText, statusColor),
                        ],
                      ),
                      SizedBox(height: 20.sh),
                      Container(height: 1, color: _purple.withValues(alpha: 0.05)),
                      SizedBox(height: 16.sh),

                      // Price & expiry
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (price != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Billing Amount",
                                  style: TextStyle(color: _purple.withValues(alpha: 0.3), fontSize: 10.sp, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2.sh),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Rs. ${double.tryParse(price.toString())?.toStringAsFixed(0) ?? "0"}',
                                        style: TextStyle(
                                          color: _purple,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' / $interval',
                                        style: TextStyle(
                                          color: _purple.withValues(alpha: 0.4),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (expiry != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isActive ? (isCancelled ? "Access till" : "Next Payment") : "Ended On",
                                  style: TextStyle(color: _purple.withValues(alpha: 0.3), fontSize: 10.sp, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2.sh),
                                Text(
                                  _formatDate(expiry),
                                  style: TextStyle(
                                    color: _purple,
                                    fontSize: 14.sp,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // Show remaining days for cancelled subscriptions
                      if (isCancelled && expiry != null && expiry.isAfter(DateTime.now())) ...[        
                        SizedBox(height: 16.sh),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 14.sh),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(18.sw),
                            border: Border.all(color: _orange.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, color: _orange, size: 18.sw),
                              SizedBox(width: 12.sw),
                              Expanded(
                                child: Text(
                                  'Access ends in ${expiry.difference(DateTime.now()).inDays} days. No further charges.',
                                  style: TextStyle(
                                    color: _orange,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
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
                        SizedBox(height: 20.sh),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _confirmCancel(doc.id, expiry);
                          },
                          child: Container(
                            width: double.infinity,
                            height: 52.sh,
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(18.sw),
                              border: Border.all(color: _red.withValues(alpha: 0.1)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Cancel Subscription',
                              style: TextStyle(
                                color: _red,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Satoshi',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Renew Button (Nutritionist)
                      if (isActive && isCancelled) ...[
                        SizedBox(height: 20.sh),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _confirmRenew(doc.id);
                          },
                          child: Container(
                            width: double.infinity,
                            height: 52.sh,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_orange, _orange.withValues(alpha: 0.8)]),
                              borderRadius: BorderRadius.circular(18.sw),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Renew Subscription',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Satoshi',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(String docId, DateTime? expiry) async {
    final dateStr = expiry != null ? _formatDate(expiry) : "the end of the current period";
    await AppDialog.show(
      context: context,
      title: "Cancel Subscription",
      contentText: "Are you sure you want to cancel your subscription? You will continue to have full access until $dateStr, and you won't be charged again.",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Keep Plan", style: TextStyle(color: _purple, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await FirebaseFirestore.instance.collection('subscriptions').doc(docId).update({
                'isCancelled': true,
                'cancelledAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Toaster.show(context, "Your plan will remain active until $dateStr.");
              }
            } catch (e) {
              if (mounted) {
                Toaster.show(context, "Failed to cancel subscription: $e", isError: true);
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
          child: const Text("Yes, Cancel"),
        ),
      ],
    );
  }

  Future<void> _confirmRenew(String docId) async {
    await AppDialog.show(
      context: context,
      title: "Renew Subscription",
      contentText: "Would you like to renew and resume your subscription? Your billing will continue as normal.",
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: _purple, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await FirebaseFirestore.instance.collection('subscriptions').doc(docId).update({
                'isCancelled': false,
                'reactivatedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Toaster.show(context, "Your subscription has been successfully reactivated!");
              }
            } catch (e) {
              if (mounted) {
                Toaster.show(context, "Failed to renew subscription: $e", isError: true);
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
          child: const Text("Renew Now"),
        ),
      ],
    );
  }

  void _showSubscriptionDetails(QueryDocumentSnapshot doc) {
    GlassDialog.show(
      context: context,
      builder: (context) => _SubscriptionDetailsDialog(doc: doc),
    );
  }

  Widget _miniStatusBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.sw),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          fontFamily: 'Satoshi',
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: _FadeSlideEntry(
        delayMs: 300,
        child: Padding(
          padding: EdgeInsets.all(40.sw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100.sw,
                height: 100.sw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple.withValues(alpha: 0.05),
                ),
                child: Center(
                  child: Container(
                    width: 70.sw,
                    height: 70.sw,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          _orange.withValues(alpha: 0.2),
                          _orange.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(Icons.subscriptions_rounded, color: _orange, size: 32.sw),
                  ),
                ),
              ),
              SizedBox(height: 32.sh),
              Text(
                "Subscription Hub",
                style: TextStyle(
                  color: _purple,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 12.sh),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _purple.withValues(alpha: 0.4),
                  fontSize: 15.sp,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  String _formatDate(dynamic date) {
    if (date == null) return "N/A";
    DateTime? dt;
    if (date is DateTime) dt = date;
    else if (date is Timestamp) dt = date.toDate();
    else if (date is String) dt = DateTime.tryParse(date);
    if (dt == null) return "N/A";
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SubscriptionDetailsDialog extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _SubscriptionDetailsDialog({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final planTitle = data['planTitle'] ?? (data['planId'] == 'platform_premium' ? 'Hidden Pantry Premium' : 'Nutritionist Plan');
    final status = data['status'] as String? ?? 'active';
    final isActive = status == 'active' || status == 'trialing';
    
    return AlertDialog(
      backgroundColor: const Color(0xFFFFF3EB).withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.sw),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(planTitle, style: TextStyle(color: const Color(0xFF462F4D), fontWeight: FontWeight.bold, fontSize: 18.sp)),
          SizedBox(height: 4.sh),
          Text(
            isActive ? "Subscription Details" : "Subscription History",
            style: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.5), fontSize: 12.sp),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("Status", status.toUpperCase(), isActive ? Colors.green : Colors.grey),
              _infoRow("Billing Interval", data['interval'] ?? 'month', const Color(0xFF462F4D)),
              _infoRow("Started On", _formatDate(data['startDate']), const Color(0xFF462F4D)),
              if (data['expiryDate'] != null)
                _infoRow(isActive ? "Renews On" : "Ended On", _formatDate(data['expiryDate']), const Color(0xFF462F4D)),
              
              SizedBox(height: 24.sh),
              Text("Payment History", style: TextStyle(color: const Color(0xFF462F4D), fontWeight: FontWeight.bold, fontSize: 14.sp)),
              SizedBox(height: 12.sh),
              _historyList('payments'),
              
              SizedBox(height: 24.sh),
              Text("Plan Changes", style: TextStyle(color: const Color(0xFF462F4D), fontWeight: FontWeight.bold, fontSize: 14.sp)),
              SizedBox(height: 12.sh),
              _historyList('plan_changes'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Color(0xFF462F4D))),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.sh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.6), fontSize: 13.sp)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13.sp, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _historyList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('subscriptionId', isEqualTo: doc.id)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text("No records found.", style: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.4), fontSize: 12.sp));
        }
        return Column(
          children: snapshot.data!.docs.map((h) {
            final hData = h.data() as Map<String, dynamic>;
            final date = _formatDate(hData['createdAt']);
            
            if (collection == 'payments') {
              return Padding(
                padding: EdgeInsets.only(bottom: 6.sh),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(date, style: TextStyle(fontSize: 12.sp, color: const Color(0xFF462F4D))),
                    Text("Rs. ${hData['amount']} (${hData['status']})", 
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
                  ],
                ),
              );
            } else {
              return Padding(
                padding: EdgeInsets.only(bottom: 6.sh),
                child: Text(
                  "$date: Changed from ${hData['fromPlan']} to ${hData['toPlan']}",
                  style: TextStyle(fontSize: 12.sp, color: const Color(0xFF462F4D).withValues(alpha: 0.7)),
                ),
              );
            }
          }).toList(),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return "N/A";
    DateTime? dt;
    if (date is Timestamp) dt = date.toDate();
    else if (date is String) dt = DateTime.tryParse(date);
    if (dt == null) return "N/A";
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
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

class _SubBackgroundPattern extends StatelessWidget {
  const _SubBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _SubFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _SubFloatingOrb(
              color: const Color(0xFFEF8A54).withValues(alpha: 0.1),
              size: 500,
              duration: const Duration(seconds: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _SubFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_SubFloatingOrb> createState() => _SubFloatingOrbState();
}

class _SubFloatingOrbState extends State<_SubFloatingOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(math.cos(angle) * 30, math.sin(angle) * 50),
          child: Container(
            width: widget.size.sw,
            height: widget.size.sw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}
