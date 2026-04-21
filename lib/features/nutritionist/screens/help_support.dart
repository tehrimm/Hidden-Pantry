import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);

  final List<Map<String, String>> _faqs = [
    {
      "q": "How do I create a subscription plan?",
      "a": "Go to your Dashboard, tap the '+' button to create a new subscription plan. You can set a title, price, billing interval, and benefits for each tier (Silver, Gold, Platinum)."
    },
    {
      "q": "How do subscribers find me?",
      "a": "Once your profile is approved and active, you'll appear in the Discovery section. Users can browse nutritionists by domain, ratings, and subscriber count."
    },
    {
      "q": "How do I receive payments?",
      "a": "Payments are processed through Stripe Connect. Go to Settings > Payouts & Earnings to view your earnings and manage your connected Stripe account."
    },
    {
      "q": "Can I share meal plans with clients?",
      "a": "Yes! In any chat with a subscriber, tap the '+' button to create a new meal plan or share one from your saved plans library."
    },
    {
      "q": "How do I schedule a consultation?",
      "a": "In the chat with your client, tap the '+' button and select 'Schedule Meeting'. Pick a date, time, and add optional notes. Your client will receive the invite and can add it to their calendar."
    },
    {
      "q": "What happens if my SaaS subscription expires?",
      "a": "If your platform subscription payment is overdue, your profile will be hidden from discovery. Your existing subscribers will retain access until their billing period ends."
    },
    {
      "q": "How do I edit my profile?",
      "a": "Go to Settings > Edit Profile. You can update your name, bio, organization, domain, and profile photo."
    },
    {
      "q": "Can I upload my own recipes?",
      "a": "Yes! Navigate to My Recipes from your settings, then tap the '+' button to start uploading a new recipe with images, ingredients, and step-by-step instructions."
    },
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const Positioned.fill(child: PatternBackground()),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.only(left: 20.sw, right: 20.sw, top: 36.sh, bottom: 10.sh),
                  child: Row(
                    children: [
                      BackButtonWidget(onPressed: () => Navigator.pop(context)),
                      SizedBox(width: 14.sw),
                      Text(
                        "Help & Support",
                        style: TextStyle(color: purple, fontSize: 22.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 6.sh),
                    children: [
                      // Contact Support Card
                      Container(
                        padding: EdgeInsets.all(22.sw),
                        decoration: BoxDecoration(
                          color: purple,
                          borderRadius: BorderRadius.circular(22.sw),
                          boxShadow: [
                            BoxShadow(color: purple.withValues(alpha: 0.2), blurRadius: 16.sw, offset: Offset(0, 6.sh)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56.sw,
                              height: 56.sw,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16.sw),
                              ),
                              child: Icon(Icons.headset_mic_rounded, color: Colors.white, size: 28.sw),
                            ),
                            SizedBox(height: 14.sh),
                            Text(
                              "Need Help?",
                              style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                            ),
                            SizedBox(height: 6.sh),
                            Text(
                              "Our support team is available to help you with any questions or issues.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.sp, height: 1.4),
                            ),
                            SizedBox(height: 18.sh),
                            GestureDetector(
                              onTap: () => _showContactDialog(),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: orange,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text("Contact Us", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 28.sh),

                      // FAQ Section Header
                      Text(
                        "Frequently Asked Questions",
                        style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                      SizedBox(height: 16.sh),

                      // FAQ Items
                      ...List.generate(_faqs.length, (index) {
                        final faq = _faqs[index];
                        final isExpanded = _expandedIndex == index;

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.sh),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16.sw),
                            boxShadow: [
                              BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 8.sw, offset: Offset(0, 2.sh)),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16.sw),
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? null : index;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.all(18.sw),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32.sw,
                                          height: 32.sw,
                                          decoration: BoxDecoration(
                                            color: orange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10.sw),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Q",
                                              style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontSize: 14.sp),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12.sw),
                                        Expanded(
                                          child: Text(
                                            faq["q"]!,
                                            style: TextStyle(
                                              color: purple,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: "Satoshi",
                                            ),
                                          ),
                                        ),
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(Icons.keyboard_arrow_down_rounded, color: purple.withValues(alpha: 0.4), size: 22.sw),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: EdgeInsets.only(top: 14.sh, left: 44.sw),
                                        child: Text(
                                          faq["a"]!,
                                          style: TextStyle(
                                            color: purple.withValues(alpha: 0.7),
                                            fontSize: 13.sp,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 200),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      SizedBox(height: 20.sh),

                      // Quick Links Section
                      Text(
                        "Quick Links",
                        style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                      SizedBox(height: 14.sh),
                      _quickLinkTile(
                        icon: Icons.description_rounded,
                        title: "Terms of Service",
                        subtitle: "Review our terms and conditions",
                        onTap: () => _launchUrl("https://arched-sunbeam-478306-u3.web.app/terms"),
                      ),
                      _quickLinkTile(
                        icon: Icons.privacy_tip_rounded,
                        title: "Privacy Policy",
                        subtitle: "How we handle your data",
                        onTap: () => _launchUrl("https://arched-sunbeam-478306-u3.web.app/privacy"),
                      ),
                      _quickLinkTile(
                        icon: Icons.info_rounded,
                        title: "About Hidden Pantry",
                        subtitle: "Learn more about our platform",
                        onTap: () => _launchUrl("https://arched-sunbeam-478306-u3.web.app/about"),
                      ),

                      SizedBox(height: 40.sh),
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

  Widget _quickLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.sh),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 8.sw, offset: Offset(0, 2.sh)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.sw),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.sw, vertical: 16.sh),
            child: Row(
              children: [
                Container(
                  width: 42.sw,
                  height: 42.sw,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Icon(icon, color: orange, size: 20.sw),
                ),
                SizedBox(width: 14.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 14.sp, fontFamily: "Satoshi")),
                      SizedBox(height: 2.sh),
                      Text(subtitle, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14.sw, color: purple.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) Toaster.show(context, 'Could not launch $urlString', isError: true);
    }
  }

  void _showContactDialog() {
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.sw)),
        title: Text("Contact Support", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi", fontSize: 18.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Reach out to us and we'll get back to you within 24 hours.",
              style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 14.sp, height: 1.4),
            ),
            SizedBox(height: 20.sh),
            _contactOption(
              icon: Icons.email_rounded,
              label: "Email",
              value: "support@hiddenpantry.app",
            ),
            SizedBox(height: 10.sh),
            _contactOption(
              icon: Icons.language_rounded,
              label: "Website",
              value: "hiddenpantry.app",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: purple.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _contactOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 14.sh),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.sw),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 6.sw, offset: Offset(0, 2.sh)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38.sw,
            height: 38.sw,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.sw),
            ),
            child: Icon(icon, color: orange, size: 18.sw),
          ),
          SizedBox(width: 14.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 11.sp, fontWeight: FontWeight.bold)),
                Text(value, style: TextStyle(color: purple, fontSize: 14.sp, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
