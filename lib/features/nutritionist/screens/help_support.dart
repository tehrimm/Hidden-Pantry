import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      BackButtonWidget(onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 14),
                      Text(
                        "Help & Support",
                        style: TextStyle(color: purple, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    children: [
                      // Contact Support Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: purple,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: purple.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Need Help?",
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Our support team is available to help you with any questions or issues.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 18),
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

                      const SizedBox(height: 28),

                      // FAQ Section Header
                      Text(
                        "Frequently Asked Questions",
                        style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                      const SizedBox(height: 16),

                      // FAQ Items
                      ...List.generate(_faqs.length, (index) {
                        final faq = _faqs[index];
                        final isExpanded = _expandedIndex == index;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? null : index;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: orange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Q",
                                              style: TextStyle(color: orange, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            faq["q"]!,
                                            style: TextStyle(
                                              color: purple,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: "Satoshi",
                                            ),
                                          ),
                                        ),
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(Icons.keyboard_arrow_down_rounded, color: purple.withValues(alpha: 0.4), size: 22),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(top: 14, left: 44),
                                        child: Text(
                                          faq["a"]!,
                                          style: TextStyle(
                                            color: purple.withValues(alpha: 0.7),
                                            fontSize: 13,
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

                      const SizedBox(height: 20),

                      // Quick Links Section
                      Text(
                        "Quick Links",
                        style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                      const SizedBox(height: 14),
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

                      const SizedBox(height: 40),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: orange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: "Satoshi")),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: purple.withValues(alpha: 0.3)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text("Contact Support", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Reach out to us and we'll get back to you within 24 hours.",
              style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            _contactOption(
              icon: Icons.email_rounded,
              label: "Email",
              value: "support@hiddenpantry.app",
            ),
            const SizedBox(height: 10),
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
            child: Text("Close", style: TextStyle(color: purple.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: orange, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold)),
                Text(value, style: TextStyle(color: purple, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
