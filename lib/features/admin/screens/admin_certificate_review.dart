import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminCertificateReviewScreen extends StatelessWidget {
  const AdminCertificateReviewScreen({super.key});

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color brown = Color(0xFF433020);
  static const Color tileBg = Color(0xFFF9E3D5);
  static const Color orange = Color(0xFFEF8A54);

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 80),
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
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: const Icon(Icons.error_outline, size: 40, color: Colors.red),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "Error loading certificates",
                                    style: const TextStyle(
                                      color: purple,
                                      fontSize: 18,
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
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: const Icon(Icons.check_circle_outline, size: 40, color: orange),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "All Clear!",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Opacity(
                                    opacity: 0.6,
                                    child: Text(
                                      "No pending certificates to review.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 14,
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
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
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
              left: 30,
              top: 51,
              child: BackButtonWidget(
                onPressed: () => Navigator.pop(context),
                color: brown,
              ),
            ),
            // Fixed header – title
            const Positioned(
              left: 0,
              right: 0,
              top: 51,
              height: 50,
              child: Center(
                child: Text(
                  "Review Certificates",
                  style: TextStyle(
                    color: purple,
                    fontSize: 24,
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Reject Application",
          style: TextStyle(
            color: purple,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: purple, fontFamily: "Satoshi"),
          decoration: InputDecoration(
            hintText: "Reason for rejection (min 10 chars)",
            hintStyle: TextStyle(color: purple.withValues(alpha:0.4), fontFamily: "Satoshi"),
            filled: true,
            fillColor: tileBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: purple, fontFamily: "Satoshi"),
            ),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().length >= 10) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: const Text(
              "Reject",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + email
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.person, color: purple, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['fullName'] ?? "Unnamed User",
                      style: const TextStyle(
                        color: purple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['email'] ?? "",
                      style: TextStyle(
                        color: purple.withValues(alpha:0.6),
                        fontSize: 13,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // License number
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: purple.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: purple, size: 18),
                const SizedBox(width: 10),
                Text(
                  "License: ${data['licenseNumber'] ?? "N/A"}",
                  style: const TextStyle(
                    color: purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
              height: 48,
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "View Certificate",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Approve / Reject row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Approve",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onReject,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Reject",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
