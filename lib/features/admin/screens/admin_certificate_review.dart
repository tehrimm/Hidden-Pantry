import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class AdminCertificateReviewScreen extends StatelessWidget {
  const AdminCertificateReviewScreen({super.key});

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF433020);
  static const Color tileBg = Color(0xFFF9E3D5);
  static const Color orange = Color(0xFFEF8A54);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    const NutritionistService nutritionistService = NutritionistService();

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            const PatternBackground(),

            // Content
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 80.sh),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: nutritionistService.getPendingNutritionists(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: orange),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40.sw),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80.sw,
                                    height: 80.sw,
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(40.sw),
                                    ),
                                    child: Icon(Icons.error_outline, size: 40.sp, color: Colors.red),
                                  ),
                                  SizedBox(height: 20.sh),
                                  Text(
                                    "Error loading certificates",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final list = snapshot.data ?? [];
                        if (list.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40.sw),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80.sw,
                                    height: 80.sw,
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(40.sw),
                                    ),
                                    child: Icon(Icons.check_circle_outline, size: 40.sp, color: orange),
                                  ),
                                  SizedBox(height: 20.sh),
                                  Text(
                                    "All Clear!",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                  SizedBox(height: 10.sh),
                                  Opacity(
                                    opacity: 0.6,
                                    child: Text(
                                      "No pending certificates to review.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 8.sh),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => SizedBox(height: 16.sh),
                          itemBuilder: (context, index) {
                            final data = list[index];
                            return _PendingNutritionistCard(
                              data: data,
                              onApprove: () => _handleApprove(context, data['uid']),
                              onReject: () => _handleReject(context, data['uid']),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Fixed header – back button
            Positioned(
              left: 30.sw,
              top: 51.sh,
              child: BackButtonWidget(
                onPressed: () => Navigator.pop(context),
                color: brown,
              ),
            ),
            // Fixed header – title
            Positioned(
              left: 0,
              right: 0,
              top: 51.sh,
              height: 50.sh,
              child: Center(
                child: Text(
                  "Review Certificates",
                  style: TextStyle(
                    color: purple,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, String uid) async {
    const nutritionistService = NutritionistService();
    try {
      await nutritionistService.approveNutritionist(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account approved!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, String uid) async {
    final TextEditingController reasonController = TextEditingController();
    final result = await GlassDialog.show<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
        title: Text(
          "Reject Application",
          style: TextStyle(
            color: purple,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
            fontSize: 18.sp,
          ),
        ),
        content: TextField(
          controller: reasonController,
          style: TextStyle(color: purple, fontFamily: "Satoshi", fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: "Reason for rejection (min 10 chars)",
            hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontFamily: "Satoshi", fontSize: 14.sp),
            filled: true,
            fillColor: tileBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.sw),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: purple, fontFamily: "Satoshi", fontSize: 14.sp),
            ),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().length >= 10) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: Text(
              "Reject",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: "Satoshi", fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      const nutritionistService = NutritionistService();
      try {
        await nutritionistService.rejectNutritionist(uid, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account rejected.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }
  }
}

class _PendingNutritionistCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingNutritionistCard({
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  static const Color purple = Color(0xFF462F4D);
  static const Color tileBg = Color(0xFFF9E3D5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.sw),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(20.sw),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + email
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 48.sw,
                height: 48.sw,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(24.sw),
                ),
                child: Icon(Icons.person, color: purple, size: 24.sp),
              ),
              SizedBox(width: 14.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['fullName'] ?? "Unnamed User",
                      style: TextStyle(
                        color: purple,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    SizedBox(height: 2.sh),
                    Text(
                      data['email'] ?? "",
                      style: TextStyle(
                        color: purple.withValues(alpha:0.6),
                        fontSize: 13.sp,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 14.sh),

          // License number
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 10.sh),
            decoration: BoxDecoration(
              color: purple.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(12.sw),
            ),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, color: purple, size: 18.sp),
                SizedBox(width: 10.sw),
                Text(
                  "License: ${data['licenseNumber'] ?? "N/A"}",
                  style: TextStyle(
                    color: purple,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.sh),

          // View Certificate button
          GestureDetector(
            onTap: () async {
              final url = Uri.parse(data['certificateUrl'] ?? "");
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Container(
              width: double.infinity,
              height: 48.sh,
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(14.sw),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, color: Colors.white, size: 18.sp),
                  SizedBox(width: 8.sw),
                  Text(
                    "View Certificate",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12.sh),

          // Approve / Reject row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    height: 48.sh,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(14.sw),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Approve",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.sw),
              Expanded(
                child: GestureDetector(
                  onTap: onReject,
                  child: Container(
                    height: 48.sh,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14.sw),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Reject",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
