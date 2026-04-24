import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

class PayoutManagementScreen extends StatefulWidget {
  const PayoutManagementScreen({super.key});

  @override
  State<PayoutManagementScreen> createState() => _PayoutManagementScreenState();
}

class _PayoutManagementScreenState extends State<PayoutManagementScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color tileBg = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const Positioned.fill(child: PatternBackground()),

          // Decorative corner shapes
          Positioned(
            top: -30.sh, right: -30.sw,
            child: Container(width: 120.sw, height: 120.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.06))),
          ),
          Positioned(
            bottom: -40.sh, left: -40.sw,
            child: Container(width: 160.sw, height: 160.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: purple.withValues(alpha: 0.04))),
          ),

          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection("nutritionists").doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading wallet: ${snapshot.error}", style: TextStyle(color: purple, fontFamily: "Satoshi")));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text("Nutritionist profile not found.", style: TextStyle(color: purple, fontFamily: "Satoshi")));
                }
                
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final double total = (data["totalEarnings"] ?? 0.0).toDouble();

                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.only(left: 20.sw, right: 20.sw, top: 36.sh, bottom: 10.sh),
                      child: Row(
                        children: [
                          BackButtonWidget(onPressed: () => Navigator.pop(context)),
                          SizedBox(width: 14.sw),
                          Text(
                            "Earnings & Fees",
                            style: TextStyle(color: purple, fontSize: 22.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Content
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 6.sh),
                        children: [
                          _FadeSlideEntry(
                            delayMs: 100,
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection("subscriptions")
                                  .where("nutritionistId", isEqualTo: user?.uid)
                                  .where("status", isEqualTo: "active")
                                  .snapshots(),
                              builder: (context, subSnap) {
                                double projectedMonthly = 0;
                                if (subSnap.hasData) {
                                  for (var doc in subSnap.data!.docs) {
                                    final d = doc.data() as Map<String, dynamic>;
                                    projectedMonthly += (d["price"] ?? 0).toDouble();
                                  }
                                }
                                return _balanceCard(total, projectedMonthly, data);
                              }
                            ),
                          ),
                          SizedBox(height: 24.sh),
                          
                          _FadeSlideEntry(
                            delayMs: 200,
                            child: _membershipSection(data),
                          ),
                          SizedBox(height: 24.sh),
                          
                          _FadeSlideEntry(
                            delayMs: 300,
                            child: _stripeConnectSection(data),
                          ),

                          _FadeSlideEntry(
                            delayMs: 300,
                            child: Text("Earnings History", style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
                          ),
                          SizedBox(height: 16.sh),
                          
                          _FadeSlideEntry(
                            delayMs: 400,
                            child: _earningsHistoryList(user?.uid),
                          ),
                          SizedBox(height: 100.sh), // Bottom padding
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(double total, double projected, Map<String, dynamic> data) {
    final String? stripeId = data["stripeAccountId"];
    final bool isLinked = stripeId != null && stripeId.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(28.sw),
      decoration: BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.circular(32.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.2), blurRadius: 20.sw, offset: Offset(0, 10.sh)),
        ],
      ),
      child: Column(
        children: [
          Text("TOTAL EARNINGS", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontFamily: "Satoshi")),
          SizedBox(height: 8.sh),
          Text("Rs. ${total.toInt()}", style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
          if (projected > 0) ...[
            SizedBox(height: 12.sh),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 8.sh),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.sw),
              ),
              child: Text(
                "POTENTIAL MONTHLY: Rs. ${projected.toInt()}",
                style: TextStyle(color: orange, fontSize: 11.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
          SizedBox(height: 28.sh),
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: isLinked ? Colors.green.withValues(alpha: 0.2) : orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.sw),
              border: Border.all(color: isLinked ? Colors.green.withValues(alpha: 0.3) : orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLinked ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: isLinked ? Colors.greenAccent : orange,
                  size: 16.sw,
                ),
                SizedBox(width: 8.sw),
                Flexible(
                  child: Text(
                    isLinked ? "Stripe Connected - Direct Payments Active" : "Connect Stripe to receive payments",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.sh),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 8.sh),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.sw),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, color: orange, size: 14.sw),
                SizedBox(width: 6.sw),
                Flexible(
                  child: Text(
                    "Hidden Pantry deducts a 10% platform fee from each transaction.",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.sp, fontFamily: "Satoshi"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsHistoryList(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(uid)
          .collection("earnings_history")
          .orderBy("timestamp", descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _emptyMinorState("Error loading: ${snapshot.error}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(20.sw),
            child: Center(child: Text("Loading items...", style: TextStyle(color: purple, fontSize: 13.sp, fontFamily: "Satoshi"))),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _emptyMinorState("No earnings recorded yet.");

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data["timestamp"] as Timestamp?)?.toDate() ?? DateTime.now();
            return _historyTile(
              title: data["userName"] ?? "Subscriber",
              subtitle: "${data["planTitle"]} subscription",
              amount: "+Rs. ${data["amount"]}",
              date: DateFormat('MMM d, yyyy').format(date),
              isPositive: true,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _historyTile({required String title, required String subtitle, required String amount, required String date, bool isPositive = true, Color? statusColor}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 8.sw, offset: Offset(0, 2.sh)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.sw)),
            child: Icon(isPositive ? Icons.add_rounded : Icons.south_west_rounded, color: isPositive ? Colors.green : orange, size: 20.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: "Satoshi")),
              SizedBox(height: 2.sh),
              Text(subtitle, style: TextStyle(color: statusColor ?? purple.withValues(alpha: 0.5), fontSize: 12.sp, fontFamily: "Satoshi")),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount, style: TextStyle(color: isPositive ? Colors.green : purple, fontWeight: FontWeight.w900, fontSize: 14.sp, fontFamily: "Satoshi")),
            SizedBox(height: 2.sh),
            Text(date, style: TextStyle(color: purple.withValues(alpha: 0.3), fontSize: 11.sp, fontFamily: "Satoshi")),
          ]),
        ],
      ),
    );
  }

  Widget _emptyMinorState(String msg) {
    return Center(child: Padding(padding: EdgeInsets.all(20.sw), child: Text(msg, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 13.sp, fontFamily: "Satoshi"))));
  }

  Widget _membershipSection(Map<String, dynamic> data) {
    final bool isActive = data["isActive"] ?? true;
    final expiry = (data["membershipExpiry"] as Timestamp?)?.toDate();
    final isTester = FirebaseAuth.instance.currentUser?.email == 'hiddenpantry50@gmail.com';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.sw),
        border: Border.all(color: isActive ? Colors.white : orange.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 10.sw, offset: Offset(0, 4.sh)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14.sw),
            decoration: BoxDecoration(
              color: isActive ? purple.withValues(alpha: 0.1) : orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.sw),
            ),
            child: Icon(
              isActive ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: isActive ? purple : orange,
              size: 24.sw,
            ),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Platform Membership",
                  style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                ),
                SizedBox(height: 4.sh),
                Text(
                  isActive 
                    ? (expiry != null ? "Active until ${DateFormat('MMM d').format(expiry)}" : "Status: Active")
                    : "Status: Inactive (Profile Hidden)",
                  style: TextStyle(
                    color: isActive ? purple.withValues(alpha: 0.6) : orange,
                    fontSize: 12.sp,
                    fontFamily: "Satoshi",
                    fontWeight: isActive ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final iap = IAPService();
              
              // Helper to handle membership payment
              void startMembershipFlow() async {
                 if (iap.products.isEmpty && !isTester) {
                  await iap.fetchProducts();
                }
                
                ProductDetails? product;
                try {
                  product = iap.products.firstWhere((p) => p.id == IAPService.nutritionistMembershipID);
                } catch (_) {
                  // Fallback for tester if product list empty
                  if (isTester) {
                    product = ProductDetails(
                      id: IAPService.nutritionistMembershipID,
                      title: 'Membership',
                      description: '',
                      price: 'Rs. 500',
                      rawPrice: 500,
                      currencyCode: 'PKR'
                    );
                  }
                }

                if (product != null) {
                  await iap.buyProduct(product, context: context);
                } else {
                  if (mounted) Toaster.show(context, "Membership service unavailable.", isError: true);
                }
              }

              if (isActive) {
                // Show info or allow early renewal
                Toaster.show(context, "Your membership is active!");
              } else {
                startMembershipFlow();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
              decoration: BoxDecoration(
                color: isActive ? purple.withValues(alpha: 0.1) : orange,
                borderRadius: BorderRadius.circular(12.sw),
                boxShadow: isActive ? [] : [BoxShadow(color: orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text(
                isActive ? "Renew" : "Pay Fee",
                style: TextStyle(
                  color: isActive ? purple : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripeConnectSection(Map<String, dynamic> data) {
    final String? stripeId = data["stripeAccountId"];
    final bool isLinked = stripeId != null && stripeId.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 18.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 10.sw, offset: Offset(0, 4.sh)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14.sw),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.sw)),
            child: Icon(Icons.account_balance_rounded, color: orange, size: 24.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked ? "Stripe Connected" : "Link Stripe Account",
                  style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                ),
                SizedBox(height: 4.sh),
                Text(
                  isLinked 
                    ? "Direct payments enabled" 
                    : "Payments go directly to your bank",
                  style: TextStyle(color: purple.withValues(alpha: 0.6), fontSize: 12.sp, fontFamily: "Satoshi"),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              try {
                final url = await StripeService().onboardNutritionist();
                await StripeService().launchStripeUrl(url);
              } catch (e) {
                if (context.mounted) Toaster.show(context, StripeService.friendlyError(e), isError: true);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [orange, const Color(0xFFFFA06A)]),
                borderRadius: BorderRadius.circular(12.sw),
                boxShadow: [BoxShadow(color: orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text(isLinked ? "Manage" : "Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
            ),
          ),
        ],
      ),
    );
  }
}

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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
  }
}
