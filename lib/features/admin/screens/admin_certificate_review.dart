import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

class AdminCertificateReviewScreen extends StatefulWidget {
  final NutritionistService? nutritionistService;
  const AdminCertificateReviewScreen({super.key, this.nutritionistService});

  @override
  State<AdminCertificateReviewScreen> createState() => _AdminCertificateReviewScreenState();
}

class _AdminCertificateReviewScreenState extends State<AdminCertificateReviewScreen> with TickerProviderStateMixin {
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFEF8A54);
  static const Color surface = Color(0xFFFDECE4);

  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Stream<List<Map<String, dynamic>>> _pendingStream;
  late NutritionistService _nutritionistService;

  @override
  void initState() {
    super.initState();
    _nutritionistService = widget.nutritionistService ?? const NutritionistService();
    _pendingStream = _nutritionistService.getPendingNutritionists();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding') ||
                  Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _headerController.forward();
    } else {
      _headerController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          // Decorative Animated Background Elements removed per user request

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 20.sh),
                
                // Animated Header
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22.sw, 20.sh, 22.sw, 0),
                    child: Row(
                      children: [
                        BackButtonWidget(
                          onPressed: () => Navigator.pop(context),
                          color: purple,
                        ),
                        SizedBox(width: 16.sw),
                        Container(
                          padding: EdgeInsets.all(12.sw),
                          decoration: BoxDecoration(
                            color: orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16.sw),
                          ),
                          child: Icon(Icons.verified_user_rounded, color: orange, size: 28.sw),
                        ),
                        SizedBox(width: 16.sw),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Certificates",
                                style: TextStyle(
                                  color: purple,
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: "Satoshi",
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                "Review professional credentials",
                                style: TextStyle(
                                  color: purple.withValues(alpha: 0.5),
                                  fontSize: 13.sp,
                                  fontFamily: "Satoshi",
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 30.sh),

                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _pendingStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: orange,
                            strokeWidth: 3.sw,
                          ),
                        );
                      }
                      
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return _EmptyState();
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(22.sw, 0, 22.sw, 40.sh),
                        physics: const BouncingScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => SizedBox(height: 20.sh),
                        itemBuilder: (context, index) {
                          final card = _PendingNutritionistCard(
                              data: list[index],
                              onApprove: () => _handleApprove(context, list[index]['uid']),
                              onReject: () => _handleReject(context, list[index]['uid']),
                            );

                          bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding') ||
                                        Platform.environment.containsKey('FLUTTER_TEST');
                          if (isTest) return card;

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 500 + (index * 150)),
                            curve: Curves.easeOutQuart,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 40 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: card,
                          );
                        },
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

  Future<void> _handleApprove(BuildContext context, String uid) async {
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.sw)),
        title: Text("Approve Expert", style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
        content: Text("Are you sure you want to approve this professional? They will gain full platform access immediately.", 
          style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 14.sp, fontFamily: "Satoshi")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw))),
            child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _nutritionistService.approveNutritionist(uid);
        if (context.mounted) {
          _showModernSnack(context, "Account approved successfully!", isError: false);
        }
      } catch (e) {
        if (context.mounted) {
          _showModernSnack(context, "Approval failed: $e", isError: true);
        }
      }
    }
  }

  Future<void> _handleReject(BuildContext context, String uid) async {
    final TextEditingController reasonController = TextEditingController();
    final result = await GlassDialog.show<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32.sw),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.sw),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22.sw),
            ),
            SizedBox(width: 12.sw),
            Text(
              "Reject Application",
              style: TextStyle(
                color: purple,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
                fontSize: 20.sp,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please provide a specific reason for rejection to help the applicant improve.",
              style: TextStyle(
                color: purple.withValues(alpha: 0.6),
                fontSize: 14.sp,
                fontFamily: "Satoshi",
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.sh),
            TextField(
              controller: reasonController,
              style: TextStyle(color: purple, fontFamily: "Satoshi", fontSize: 15.sp, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "E.g. Blurred certificate, Expired license...",
                hintStyle: TextStyle(color: purple.withValues(alpha: 0.3), fontFamily: "Satoshi", fontSize: 14.sp),
                filled: true,
                fillColor: purple.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.sw),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(18.sw),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: purple.withValues(alpha: 0.5), fontFamily: "Satoshi", fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.sw),
            child: ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().length >= 5) {
                  Navigator.pop(context, reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 12.sh),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
              ),
              child: const Text("Confirm Rejection", style: TextStyle(fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _nutritionistService.rejectNutritionist(uid, result);
        if (context.mounted) {
          _showModernSnack(context, "Application rejected.", isError: false);
        }
      } catch (e) {
        if (context.mounted) {
          _showModernSnack(context, "Error: $e", isError: true);
        }
      }
    }
  }

  void _showModernSnack(BuildContext context, String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 12.sh),
          decoration: BoxDecoration(
            color: isError ? Colors.redAccent : const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(16.sw),
            boxShadow: [
              BoxShadow(
                color: (isError ? Colors.redAccent : const Color(0xFF4CAF50)).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20.sp),
              SizedBox(width: 12.sw),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.sp, fontFamily: "Satoshi"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingNutritionistCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingNutritionistCard({
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingNutritionistCard> createState() => _PendingNutritionistCardState();
}

class _PendingNutritionistCardState extends State<_PendingNutritionistCard> {
  bool _isPressed = false;
  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFEF8A54);
  static const Color surface = Color(0xFFFDECE4);

  @override
  Widget build(BuildContext context) {

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          padding: EdgeInsets.all(24.sw),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(32.sw),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60.sw,
                    height: 60.sw,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [purple, const Color(0xFF2D1E32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: purple.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 28.sw),
                  ),
                  SizedBox(width: 16.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['fullName'] ?? "Nutritionist Candidate",
                          style: TextStyle(
                            color: purple,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Satoshi",
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4.sh),
                        Text(
                          widget.data['email'] ?? "No email provided",
                          style: TextStyle(
                            color: purple.withValues(alpha: 0.4),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 6.sh),
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.sw),
                      border: Border.all(color: orange.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      "NEW",
                      style: TextStyle(
                        color: orange,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.sh),

              // Info Grid
              Container(
                padding: EdgeInsets.all(18.sw),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24.sw),
                ),
                child: Row(
                  children: [
                    _infoItem(Icons.badge_outlined, "LICENSE", widget.data['licenseNumber'] ?? "N/A"),
                    Container(width: 1.5, height: 24.sh, color: purple.withValues(alpha: 0.05)),
                    _infoItem(Icons.calendar_today_outlined, "APPLIED", "Just now"),
                  ],
                ),
              ),

              SizedBox(height: 24.sh),

              // View Certificate (Primary)
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(widget.data['certificateUrl'] ?? "");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56.sh,
                  decoration: BoxDecoration(
                    color: purple,
                    borderRadius: BorderRadius.circular(18.sw),
                    boxShadow: [
                      BoxShadow(color: purple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, color: Colors.white, size: 20.sw),
                      SizedBox(width: 12.sw),
                      Flexible(
                        child: Text(
                          "Review Credentials",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Satoshi",
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16.sh),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      "Reject",
                      Colors.redAccent.withValues(alpha: 0.08),
                      Colors.redAccent,
                      widget.onReject,
                    ),
                  ),
                  SizedBox(width: 14.sw),
                  Expanded(
                    child: _actionBtn(
                      "Approve",
                      const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      const Color(0xFF4CAF50),
                      widget.onApprove,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.sp, color: purple.withValues(alpha: 0.4)),
              SizedBox(width: 6.sw),
              Text(
                label,
                style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 11.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 4.sh),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: purple, fontSize: 13.sp, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.sh,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16.sw),
          border: Border.all(color: text.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            fontFamily: "Satoshi",
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}



class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF462F4D);
    final orange = const Color(0xFFEF8A54);

    bool isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding') ||
                  Platform.environment.containsKey('FLUTTER_TEST');

    final icon = Container(
                width: 160.sw,
                height: 160.sw,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECE4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: orange.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 10),
                  ],
                ),
                child: Icon(Icons.verified_outlined, size: 80.sp, color: orange),
              );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 50.sw),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isTest)
              icon
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: icon,
              ),
            SizedBox(height: 30.sh),
            Text(
              "No pending experts",
              style: TextStyle(
                color: purple,
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                fontFamily: "Satoshi",
              ),
            ),
            SizedBox(height: 12.sh),
            Text(
              "All certificates have been reviewed. You're completely caught up!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: purple.withValues(alpha: 0.5),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                fontFamily: "Satoshi",
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
