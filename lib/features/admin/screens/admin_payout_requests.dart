import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/widgets/app_dialog.dart';

class AdminPayoutRequestsScreen extends StatefulWidget {
  const AdminPayoutRequestsScreen({super.key});

  @override
  State<AdminPayoutRequestsScreen> createState() => _AdminPayoutRequestsScreenState();
}

class _AdminPayoutRequestsScreenState extends State<AdminPayoutRequestsScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color tileBg = const Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildRequestsList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(30.sw, isTablet ? 24.sh : 35.sh, 30.sw, 25.sh),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BackButtonWidget(onPressed: () => Navigator.pop(context)),
          SizedBox(width: 16.sw),
          Text(
            "Payment Requests",
            style: TextStyle(
              color: purple,
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("withdrawal_requests")
          .where("status", whereIn: ["pending", "processing"])
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _errorState(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _emptyState();

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20.sw),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _requestTile(doc.id, data);
          },
        );
      },
    );
  }

  Widget _requestTile(String docId, Map<String, dynamic> data) {
    final String name = data["nutritionistName"] ?? "Unknown";
    final double amount = (data["amount"] ?? 0.0).toDouble();
    final Timestamp? ts = data["timestamp"] as Timestamp?;
    final String dateStr = ts != null ? DateFormat('MMM d, h:mm a').format(ts.toDate()) : "N/A";
    final Map<String, dynamic> method = data["payoutMethod"] ?? {};

    return Container(
      margin: EdgeInsets.only(bottom: 16.sh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.sw),
          onTap: () => _showDetails(docId, name, amount, method, data),
          child: Padding(
            padding: EdgeInsets.all(20.sw),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.sw),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.payments_rounded, color: orange, size: 24.sw),
                ),
                SizedBox(width: 16.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: purple,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                        ),
                      ),
                      SizedBox(height: 4.sh),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: purple.withValues(alpha: 0.5),
                          fontSize: 12.sp,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Rs. ${amount.toInt()}",
                      style: TextStyle(
                        color: purple,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    SizedBox(height: 4.sh),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                      decoration: BoxDecoration(
                        color: (data["status"] == "processing" ? Colors.blue : orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.sw),
                      ),
                      child: Text(
                        (data["status"] ?? "PENDING").toString().toUpperCase(),
                        style: TextStyle(
                          color: data["status"] == "processing" ? Colors.blue : orange,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(String docId, String name, double amount, Map<String, dynamic> method, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.sw),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40.sw, height: 4.sh, decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2.sw)))),
            SizedBox(height: 24.sh),
            Text("Payout Details", style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
            SizedBox(height: 24.sh),
            
            _detailRow("Nutritionist", name),
            _detailRow("Amount", "Rs. ${amount.toInt()}"),
            _detailRow("Method", method["method"] ?? "N/A"),
            if (method["bankName"] != null) _detailRow("Bank", method["bankName"]),
            _detailRow("Account Name", method["accountHolderName"] ?? "N/A"),
            
            SizedBox(height: 12.sh),
            _copyableDetail("Account / IBAN", method["accountNumber"] ?? "N/A"),
            
            SizedBox(height: 32.sh),
            if (data["status"] == "pending")
              Padding(
                padding: EdgeInsets.only(bottom: 16.sh),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _markAsProcessing(docId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.sh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                    ),
                    child: const Text("Mark as Processing", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(docId, data["nutritionistId"], amount),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 16.sh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                    ),
                    child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(width: 16.sw),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _markAsPaid(docId, name, amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16.sh),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                    ),
                    child: const Text("Mark as Paid", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.sh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 14.sp, fontFamily: "Satoshi")),
          Text(value, style: TextStyle(color: purple, fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        ],
      ),
    );
  }

  Widget _copyableDetail(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.sw),
        border: Border.all(color: purple.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp, fontFamily: "Satoshi")),
                SizedBox(height: 4.sh),
                Text(value, style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              Toaster.show(context, "Copied to clipboard!");
            },
            icon: Icon(Icons.copy_rounded, color: orange, size: 20.sw),
          ),
        ],
      ),
    );
  }

  void _markAsProcessing(String docId) async {
    try {
      await FirebaseFirestore.instance.collection("withdrawal_requests").doc(docId).update({
        "status": "processing",
        "processedAt": FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        Toaster.show(context, "Request marked as processing");
      }
    } catch (e) {
      Toaster.show(context, "Error: $e", isError: true);
    }
  }

  void _rejectRequest(String docId, String nutritionistId, double amount) async {
    final bool? confirm = await AppDialog.show<bool>(
      context: context,
      title: "Reject Request",
      contentText: "Are you sure you want to reject this request? The amount Rs. ${amount.toInt()} will be refunded to the nutritionist.",
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reject", style: TextStyle(color: Colors.red))),
      ],
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // 1. Mark as rejected
        batch.update(FirebaseFirestore.instance.collection("withdrawal_requests").doc(docId), {
          "status": "rejected",
          "rejectedAt": FieldValue.serverTimestamp(),
        });

        // 2. Refund to nutritionist
        batch.update(FirebaseFirestore.instance.collection("nutritionists").doc(nutritionistId), {
          "totalEarnings": FieldValue.increment(amount),
          "pendingPayout": FieldValue.increment(-amount),
        });

        await batch.commit();
        if (mounted) {
          Navigator.pop(context);
          Toaster.show(context, "Request rejected and amount refunded");
        }
      } catch (e) {
        Toaster.show(context, "Error: $e", isError: true);
      }
    }
  }

  void _markAsPaid(String docId, String name, double amount) async {
    final TextEditingController proofCtrl = TextEditingController();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.sw)),
        title: Text("Confirm Payment", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter Transaction ID or Proof Reference for Rs. ${amount.toInt()} payment to $name:", 
              style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 14.sp)),
            SizedBox(height: 16.sh),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDECE4).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16.sw),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: TextField(
                controller: proofCtrl,
                cursorColor: purple,
                style: TextStyle(color: purple, fontSize: 14.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "e.g. TRX-123456789",
                  hintStyle: TextStyle(color: const Color(0xFFBFA89A), fontSize: 14.sp),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 12.sh),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () {
              if (proofCtrl.text.trim().isEmpty) {
                Toaster.show(context, "Proof reference is required", isError: true);
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
              elevation: 0,
            ),
            child: const Text("Confirm Paid"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final proofValue = proofCtrl.text.trim();
      try {
        final batch = FirebaseFirestore.instance.batch();
        final requestRef = FirebaseFirestore.instance.collection("withdrawal_requests").doc(docId);
        
        // 1. Mark request as paid
        batch.update(requestRef, {
          "status": "paid",
          "paidAt": FieldValue.serverTimestamp(),
          "proof": proofValue,
        });

        // 2. Add to payout history
        final proofRef = FirebaseFirestore.instance.collection("payout_history").doc();
        
        // Fetch nutritionist ID from original request
        final requestDoc = await requestRef.get();
        final nutritionistId = requestDoc.data()?["nutritionistId"];

        batch.set(proofRef, {
          "nutritionistId": nutritionistId,
          "amount": amount,
          "timestamp": FieldValue.serverTimestamp(),
          "status": "completed",
          "requestId": docId,
          "proof": proofValue,
        });

        // 3. Update nutritionist's pending payout
        final nutritionistRef = FirebaseFirestore.instance.collection("nutritionists").doc(nutritionistId);
        batch.update(nutritionistRef, {
          "pendingPayout": FieldValue.increment(-amount),
          "totalPaidOut": FieldValue.increment(amount),
        });

        await batch.commit();
        if (mounted) {
          Navigator.pop(context); // Close details sheet
          Toaster.show(context, "Payment marked as completed!");
        }
      } catch (e) {
        Toaster.show(context, "Error: $e", isError: true);
      }
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64.sw, color: purple.withValues(alpha: 0.1)),
          SizedBox(height: 16.sh),
          Text("No pending payout requests", style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 14.sp, fontFamily: "Satoshi")),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(child: Text("Error: $error", style: TextStyle(color: Colors.red, fontSize: 13.sp)));
  }
}
