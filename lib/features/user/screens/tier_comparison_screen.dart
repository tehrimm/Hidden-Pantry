import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class TierComparisonScreen extends StatefulWidget {
  final String nutritionistId;
  final Map<String, dynamic> nutritionistData;
  final int currentTier; // 0=Free, 1=Silver, 2=Gold

  const TierComparisonScreen({
    super.key,
    required this.nutritionistId,
    required this.nutritionistData,
    required this.currentTier,
  });

  @override
  State<TierComparisonScreen> createState() => _TierComparisonScreenState();
}

class _TierComparisonScreenState extends State<TierComparisonScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];
  late int _localCurrentTier;
  StreamSubscription<QuerySnapshot>? _subListener;

  @override
  void initState() {
    super.initState();
    _localCurrentTier = widget.currentTier;
    _loadPlans();
    _startTierListener();
  }

  @override
  void dispose() {
    _subListener?.cancel();
    super.dispose();
  }

  bool _isCancelling = false;

  void _startTierListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subListener = FirebaseFirestore.instance
        .collection("subscriptions")
        .where("userId", isEqualTo: user.uid)
        .where("nutritionistId", isEqualTo: widget.nutritionistId)
        .snapshots()
        .listen((query) {
      if (query.docs.isEmpty) return;

      final now = DateTime.now();
      int highestTier = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final status = data["status"] as String?;
        final expiry = (data["expiryDate"] as Timestamp?)?.toDate();

        bool isActive = (status == "active") || (status == "trialing") || (expiry != null && expiry.isAfter(now));

        if (isActive) {
          int currentDocTier = 0;
          dynamic rawTier = data["tierLevel"];
          if (rawTier is num) currentDocTier = rawTier.toInt();
          else if (rawTier is String) currentDocTier = int.tryParse(rawTier) ?? 0;
          
          if (currentDocTier == 0) currentDocTier = 1;

          if (currentDocTier > highestTier) highestTier = currentDocTier;
        }
      }

      if (mounted && highestTier > 0 && highestTier != _localCurrentTier) {
        setState(() {
          _localCurrentTier = highestTier;
        });
      }
    });
  }

  Future<void> _loadPlans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(widget.nutritionistId)
          .collection("subscription_plans")
          .where("isActive", isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> loadedPlans = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        
        // Ensure tierLevel exists for legacy plans
        if (data['tierLevel'] == null) {
          final title = (data['title'] ?? '').toString().toLowerCase();
          if (title.contains('platinum')) {
            data['tierLevel'] = 3;
          } else if (title.contains('gold')) {
            data['tierLevel'] = 2;
          } else {
            data['tierLevel'] = 1;
          }
        }
        return data;
      }).toList();

      // Sort by tierLevel in Dart
      loadedPlans.sort((a, b) => (a['tierLevel'] as int).compareTo(b['tierLevel'] as int));

      if (mounted) {
        setState(() {
          _plans = loadedPlans;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text("Cancel Subscription?", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: const Text("You will keep your access until the end of the current billing period."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No", style: TextStyle(color: purple, fontSize: 14.sp))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text("Yes, Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14.sp))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      // Find the subscription doc for this user and nutritionist
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snap = await FirebaseFirestore.instance
          .collection("subscriptions")
          .where("userId", isEqualTo: user.uid)
          .where("nutritionistId", isEqualTo: widget.nutritionistId)
          .where("status", isEqualTo: "active")
          .get();

      if (snap.docs.isEmpty) {
        throw Exception("No active subscription found to cancel.");
      }

      // Find the one with highest tierLevel
      QueryDocumentSnapshot? bestDoc;
      int highestTier = -1;

      for (var doc in snap.docs) {
        final data = doc.data();
        int tier = 0;
        dynamic rawTier = data["tierLevel"];
        if (rawTier is num) tier = rawTier.toInt();
        else if (rawTier is String) tier = int.tryParse(rawTier) ?? 0;
        
        if (tier >= highestTier) {
          highestTier = tier;
          bestDoc = doc;
        }
      }

      final subDocId = bestDoc!.id;
      await StripeService().cancelSubscription(subscriptionDocId: subDocId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subscription cancelled successfully.")),
        );
        Navigator.pop(context, "refresh");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cancellation failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 10.sh),
                  child: Row(
                    children: [
                      BackButtonWidget(onPressed: () => Navigator.pop(context), color: const Color(0xFF433020)),
                      const Spacer(),
                      Text(
                        "Subscription Plans",
                        style: TextStyle(
                          color: purple,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      const Spacer(),
                      SizedBox(width: 40.sw),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _loading 
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: EdgeInsets.all(20.sw),
                          children: [
                            Text(
                              "Choose Your Tier",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: purple,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w900,
                                fontFamily: "Satoshi",
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Select a plan to unlock exclusive content from ${widget.nutritionistData['fullName'] ?? 'this expert'}.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 14.sp),
                            ),
                            SizedBox(height: 30.sh),
                            
                             // Free Tier Card (Static)
                            _tierCard(
                              title: "Free Community",
                              price: "Rs. 0",
                              tierLevel: 0,
                              benefits: ["Public Tips", "Basic Feed Access"],
                              color: const Color(0xFFB0B0B0),
                              isCurrent: _localCurrentTier == 0,
                            ),

                             ..._plans.map((plan) {
                                final tier = plan['tierLevel'] ?? 1;
                                final isPlatinum = tier == 3;
                                final isGold = tier == 2;
                                
                                // Standard professional tier colors
                                final tierColor = isPlatinum 
                                    ? const Color(0xFF4B0082) // Platinum: Indigo
                                    : (isGold 
                                        ? const Color(0xFFDAA520) // Gold: Goldenrod
                                        : const Color(0xFF708090)); // Silver: Slate
                                
                                return _tierCard(
                                  title: plan['title'] ?? "Tier $tier",
                                  price: "Rs. ${plan['price']} / ${plan['interval'] ?? 'mo'}",
                                  tierLevel: tier,
                                  benefits: (plan['benefits'] as List? ?? []).map((b) => b['title'].toString()).toList(),
                                  color: tierColor,
                                  cardColor: Colors.white, // Keep cards clean and readable
                                  isCurrent: _localCurrentTier == tier,
                                  planData: plan,
                                );
                              }),
                            
                            SizedBox(height: 20.sh),
                            Center(
                              child: Text(
                                "Secure Payment Processing via Stripe Connect",
                                style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11.sp, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: 10.sh),
                            Image.asset('assets/icons/stripe_badge.png', height: 20.sh, errorBuilder: (_, __, ___) => Container()), // Hidden if not exists
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierCard({
    required String title,
    required String price,
    required int tierLevel,
    required List<String> benefits,
    required Color color,
    Color cardColor = Colors.white,
    bool isCurrent = false,
    Map<String, dynamic>? planData,
  }) {
    final bool isUpgrade = tierLevel > widget.currentTier && widget.currentTier > 0;
    final bool isNewSub = widget.currentTier == 0 && tierLevel > 0;
    
    // Tier-specific text colors for elements inside the card
    final Color accentColor = color;

    return Container(
      margin: EdgeInsets.only(bottom: 20.sh),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(
          color: isCurrent ? orange : accentColor.withValues(alpha:0.2),
          width: isCurrent ? 2.sw : 1.sw
        ),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 15.sw, offset: Offset(0, 8.sh)),
        ],
      ),
      child: Column(
        children: [
          // Banner for badge
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8.sh, horizontal: 16.sw),
            decoration: BoxDecoration(
              color: isCurrent ? orange : accentColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.sw)),
            ),
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.check_circle_rounded : Icons.star_rounded, 
                  color: isCurrent ? Colors.white : accentColor, 
                  size: 18.sw
                ),
                SizedBox(width: 8.sw),
                Text(
                  isCurrent ? "CURRENT PLAN" : (isUpgrade ? "UPGRADE" : (isNewSub ? "SELECT PLAN" : "AVAILABLE")),
                  style: TextStyle(
                    color: isCurrent ? Colors.white : accentColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.sw,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.sw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(color: purple, fontSize: 22.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                        ),
                        SizedBox(width: 8.sw),
                        Icon(
                          tierLevel == 3 ? Icons.diamond_rounded : (tierLevel == 2 ? Icons.star_rounded : Icons.star_half_rounded), 
                          color: accentColor,
                          size: 20.sw,
                        ),
                      ],
                    ),
                    if (tierLevel > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8.sw),
                      ),
                      child: Text(
                        tierLevel == 3 ? "PLATINUM" : (tierLevel == 2 ? "GOLD" : "SILVER"),
                        style: TextStyle(color: accentColor, fontSize: 10.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.sh),
                Text(
                  price,
                  style: TextStyle(color: orange, fontSize: 24.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                ),
                if (isUpgrade) 
                  Padding(
                    padding: EdgeInsets.only(top: 4.sh),
                    child: Text(
                      "*Upgrades are pro-rated. You'll only pay the difference for the remaining days of your current cycle.",
                      style: TextStyle(color: orange.withValues(alpha:0.8), fontSize: 11.sp, fontStyle: FontStyle.italic),
                    ),
                  ),
                SizedBox(height: 20.sh),
                ...benefits.map((b) => Padding(
                  padding: EdgeInsets.only(bottom: 8.sh),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: accentColor.withValues(alpha:0.6), size: 16.sw),
                      SizedBox(width: 10.sw),
                      Expanded(child: Text(b, style: TextStyle(color: purple.withValues(alpha:0.8), fontSize: 14.sp))),
                    ],
                  ),
                )),
                SizedBox(height: 24.sh),
                
                if (tierLevel > 0 && !isCurrent)
                  SizedBox(
                    width: double.infinity,
                    height: 50.sh,
                    child: ElevatedButton(
                      onPressed: () => _handleSubscribe(planData!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isUpgrade || isNewSub) ? purple : Colors.white,
                        foregroundColor: (isUpgrade || isNewSub) ? Colors.white : purple,
                        elevation: 0,
                        side: (isUpgrade || isNewSub) ? BorderSide.none : BorderSide(color: purple.withValues(alpha:0.2)),

                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.sw)),
                      ),
                      child: Text(
                        isUpgrade ? "Proceed to Upgrade" : (isNewSub ? "Subscribe Now" : "Switch to this Tier"),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                      ),
                    ),
                  )
                else if (isCurrent && tierLevel > 0)
                  Column(
                    children: [
                      Center(
                        child: Text(
                          "Your Active Plan",
                          style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontSize: 16.sp),
                        ),
                      ),
                      SizedBox(height: 12.sh),
                      TextButton(
                        onPressed: _isCancelling ? null : _cancelSubscription,
                        child: _isCancelling 
                           ? SizedBox(width: 20.sw, height: 20.sw, child: CircularProgressIndicator(strokeWidth: 2.sw))
                           : Text("Cancel Subscription", style: TextStyle(color: Colors.red, fontSize: 13.sp)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(Map<String, dynamic> plan) {
    Navigator.pop(context, plan);
  }
}
