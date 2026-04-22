import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class PayoutManagementScreen extends StatefulWidget {
  const PayoutManagementScreen({super.key});

  @override
  State<PayoutManagementScreen> createState() => _PayoutManagementScreenState();
}

class _PayoutManagementScreenState extends State<PayoutManagementScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color brown = const Color(0xFF433020);
  final Color tileBg = const Color(0xFFF9E3D5);
  final Color orange = const Color(0xFFEF8A54);


  // Removed withdrawal logic as per direct payment model

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.sw),
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const _PayoutBackgroundPattern(),
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
                        // Fixed Header
                        Padding(
                          padding: EdgeInsets.only(left: 22.sw, right: 22.sw, top: 16.sh, bottom: 20.sh),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 50.sw,
                                  height: 50.sw,
                                  decoration: BoxDecoration(
                                    color: tileBg,
                                    borderRadius: BorderRadius.circular(25.sw),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sw, color: brown),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "Earnings & Fees",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        ),

                        // Scrollable Content
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.symmetric(horizontal: 22.sw),
                            children: [
                              StreamBuilder<QuerySnapshot>(
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
                              SizedBox(height: 24.sh),
                              _stripeConnectSection(data),
                              SizedBox(height: 24.sh),
                              _saasStatusSection(data),
                              SizedBox(height: 32.sh),
                              Text("Platform Payment History", style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                              SizedBox(height: 16.sh),
                              _platformPaymentHistoryList(user?.uid),
                              SizedBox(height: 32.sh),
                              Text("Earnings History", style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                              SizedBox(height: 16.sh),
                              _earningsHistoryList(user?.uid),
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
        ),
      ),
    );
  }



  Widget _balanceCard(double total, double projected, Map<String, dynamic> data) {
    final String? stripeId = data["stripeAccountId"];
    final bool isLinked = stripeId != null && stripeId.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(28.sw),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purple, const Color(0xFF63456D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.2), blurRadius: 20.sw, offset: Offset(0, 10.sh)),
        ],
      ),
      child: Column(
        children: [
          Text("TOTAL EARNINGS", style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontFamily: "Satoshi")),
          SizedBox(height: 8.sh),
          Text("Rs. ${total.toInt()}", style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
          if (projected > 0) ...[
            SizedBox(height: 8.sh),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10.sw),
              ),
              child: Text(
                "POTENTIAL MONTHLY: Rs. ${projected.toInt()}",
                style: TextStyle(color: orange, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
          SizedBox(height: 28.sh),
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: isLinked ? Colors.green.withValues(alpha:0.2) : orange.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(12.sw),
              border: Border.all(color: isLinked ? Colors.green.withValues(alpha:0.3) : orange.withValues(alpha:0.3)),
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
          SizedBox(height: 12.sh),
          Text(
            "* Funds are transferred directly to your Stripe account.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10.sp, fontFamily: "Satoshi"),
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
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _emptyMinorState("Error loading: ${snapshot.error}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(20.sw),
            child: Center(child: Text("Loading items...", style: TextStyle(color: Color(0xFF462F4D), fontSize: 13.sp, fontFamily: "Satoshi"))),
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
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10.sw, offset: Offset(0, 4.sh)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.sw),
            decoration: BoxDecoration(color: const Color(0xFFFFF2EA), shape: BoxShape.circle),
            child: Icon(isPositive ? Icons.add_rounded : Icons.south_west_rounded, color: isPositive ? Colors.green : orange, size: 20.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: "Satoshi")),
              Text(subtitle, style: TextStyle(color: statusColor ?? purple.withValues(alpha:0.4), fontSize: 11.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount, style: TextStyle(color: isPositive ? Colors.green : purple, fontWeight: FontWeight.w900, fontSize: 14.sp, fontFamily: "Satoshi")),
            Text(date, style: TextStyle(color: purple.withValues(alpha:0.3), fontSize: 11.sp, fontFamily: "Satoshi")),
          ]),
        ],
      ),
    );
  }

  Widget _emptyMinorState(String msg) {
    return Center(child: Padding(padding: EdgeInsets.all(20.sw), child: Text(msg, style: TextStyle(color: purple.withValues(alpha:0.3), fontSize: 13.sp, fontFamily: "Satoshi"))));
  }

  Widget _stripeConnectSection(Map<String, dynamic> data) {
    final String? stripeId = data["stripeAccountId"];
    final bool isLinked = stripeId != null && stripeId.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 16.sh),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(24.sw),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(color: const Color(0xFFFFF2EA), borderRadius: BorderRadius.circular(16.sw)),
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
                Text(
                  isLinked 
                    ? "Direct payments enabled" 
                    : "Payments go directly to your bank",
                  style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 12.sp, fontFamily: "Satoshi"),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
                try {
                  final url = await StripeService().onboardNutritionist();
                  await StripeService().launchStripeUrl(url);
                } catch (e) {
                  Toaster.show(context, StripeService.friendlyError(e), isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
                padding: EdgeInsets.symmetric(horizontal: 16.sw),
              ),
              child: Text(isLinked ? "Manage" : "Setup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
            ),
          ],
        ),
      );
    }

    Widget _saasStatusSection(Map<String, dynamic> data) {
      final String status = data["saasStatus"] ?? "unpaid";
      final bool isActive = status == "active";

      return Container(
        padding: EdgeInsets.all(20.sw),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.withValues(alpha:0.1) : orange.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(24.sw),
          border: Border.all(color: isActive ? Colors.green.withValues(alpha:0.2) : orange.withValues(alpha:0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isActive ? Icons.check_circle_rounded : Icons.warning_rounded, color: isActive ? Colors.green : orange, size: 20.sw),
                SizedBox(width: 8.sw),
                Text(
                  "Platform Membership",
                  style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 15.sp),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : orange,
                    borderRadius: BorderRadius.circular(8.sw),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.sh),
            Text(
              isActive 
                ? "Your profile is active and visible to all users." 
                : "Pay the monthly platform fee to keep your profile visible.",
              style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 12.sp),
            ),
            if (!isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final url = await StripeService().subscribeToPlatform();
                      await StripeService().launchStripeUrl(url);
                    } catch (e) {
                      Toaster.show(context, "Error: $e", isError: true);
                    }
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
                ),
                child: Text("Pay Platform Fee (Rs. 1,200)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _platformPaymentHistoryList(String? uid) {
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("platform_payments")
          .where("nutritionistId", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(24.sw),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(20.sw),
            ),
            child: Center(
              child: Text("No platform payments recorded", style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 13.sp)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final payment = docs[index].data() as Map<String, dynamic>;
            final amount = (payment["amount"] ?? 0.0);
            final type = payment["type"] == "initial_saas_payment" ? "Initial Charge" : "Renewal";
            final date = (payment["createdAt"] as Timestamp?)?.toDate();
            final formattedDate = date != null ? "${date.day}/${date.month}/${date.year}" : "...";

            return Container(
              margin: EdgeInsets.only(bottom: 12.sh),
              padding: EdgeInsets.all(16.sw),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.sw),
                border: Border.all(color: Colors.grey.withValues(alpha:0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.sw),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12.sw),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: Colors.green, size: 20.sw),
                  ),
                  SizedBox(width: 16.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                        Text(formattedDate, style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 12.sp)),
                      ],
                    ),
                  ),
                  Text(
                    "Rs. ${amount.toInt()}",
                    style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontSize: 14.sp),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PayoutBackgroundPattern extends StatelessWidget {
  const _PayoutBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    final stroke = const Color(0xFFF5DDCE);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: (-154).sw,
            top: (-14).sh,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271.sw,
                height: 159.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(136.sw, 80.sh),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: (-149).sw,
            top: (-100).sh,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303.sw,
                height: 329.sh,
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(152.sw, 165.sh),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
