import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


import 'loading_four.dart';
import 'loading_five.dart';

class TermsAndConditionScreen extends StatefulWidget {
  // Add viewOnly mode (default false)
  final bool viewOnly;

  const TermsAndConditionScreen({
    super.key,
    this.viewOnly = false,
  });

  @override
  State<TermsAndConditionScreen> createState() => _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  bool agreed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: SizedBox.expand(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
          child: Stack(
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
              const _OnboardingBackgroundPattern(),
              
              // Decorative rings (Keep original)
              Positioned(
                left: -154.sw,
                top: -14.sh,
                child: Transform.rotate(
                  angle: 21 * 3.14159 / 180,
                  child: Container(
                    width: 271.sw,
                    height: 159.sh,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF5DDCE)),
                      borderRadius: BorderRadius.all(Radius.elliptical(136.sw, 80.sh)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -149.sw,
                top: -100.sh,
                child: Transform.rotate(
                  angle: 4 * 3.14159 / 180,
                  child: Container(
                    width: 303.sw,
                    height: 329.sh,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF5DDCE)),
                      borderRadius: BorderRadius.all(Radius.elliptical(152.sw, 165.sh)),
                    ),
                  ),
                ),
              ),

              // Content in Column
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(height: isTablet ? 24.sh : 35.sh),
                    _FadeSlideEntry(
                      delayMs: 100,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30.sw),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 50.sw,
                                  height: 50.sw,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9E3D5),
                                    borderRadius: BorderRadius.circular(25.sw),
                                  ),
                                  child: Icon(Icons.arrow_back_ios_new, size: 18.sp, color: const Color(0xFF462F4D)),
                                ),
                              ),
                            ),
                            Text(
                              'Terms and\nCondition',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF462F4D),
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Satoshi',
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30.sh),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 30.sw,
                          right: 30.sw,
                          bottom: widget.viewOnly ? MediaQuery.paddingOf(context).bottom + 16.sh : 20.sh,
                        ),
                        children: _getTermsWidgets(fontSize: 14.sp),
                      ),
                    ),
                    if (!widget.viewOnly)
                      _FadeSlideEntry(
                        delayMs: 800,
                        child: Container(
                          color: const Color(0xFFF9E3D5),
                          padding: EdgeInsets.fromLTRB(
                            26.sw,
                            12.sh,
                            26.sw,
                            MediaQuery.paddingOf(context).bottom + 14.sh,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => agreed = !agreed),
                                    child: Container(
                                      width: 18.sw,
                                      height: 18.sw,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4.sw),
                                        border: Border.all(color: const Color(0xFF462F4D), width: 1.5.sw),
                                      ),
                                      child: agreed
                                          ? Icon(Icons.check, size: 14.sp, color: const Color(0xFF462F4D))
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 10.sw),
                                  Expanded(
                                    child: Text(
                                      'I have read and agree to the Terms and Conditions',
                                      style: TextStyle(
                                        color: const Color(0xFF462F4D),
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                        fontFamily: 'Satoshi',
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.sh),
                              GestureDetector(
                                onTap: agreed ? () => Navigator.pop(context, true) : null,
                                child: Opacity(
                                  opacity: agreed ? 1.0 : 0.55,
                                  child: Container(
                                    width: double.infinity,
                                    height: 62.sh,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2894F),
                                      borderRadius: BorderRadius.circular(20.sw),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Agree and Continue',
                                      style: TextStyle(
                                        color: const Color(0xFFFFF2EA),
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch $urlString");
      }
    } catch (e) {
      debugPrint("Error launching $urlString: $e");
    }
  }

  List<Widget> _getTermsWidgets({required double fontSize}) {
    final base = TextStyle(
      color: const Color(0xFF462F4D),
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      fontFamily: 'Satoshi',
      height: 1.5,
    );
    final h = base.copyWith(fontWeight: FontWeight.w800);
    final linkStyle = base.copyWith(
      color: const Color(0xFFF2894F),
      fontWeight: FontWeight.w700,
    );

    final sections = [
      {
        't': '1. Acceptance of Terms',
        'c': 'These Terms and Conditions ("Terms") constitute a legally binding agreement between you ("User", "you") and Hidden Pantry ("we", "us", "our"). By downloading, installing, accessing, or using the Hidden Pantry mobile application ("the App") or our associated website, you confirm that you have read, understood, and agree to be bound by these Terms.\n\nIf you do not agree to these Terms, you must not access or use our services. We reserve the right to update these Terms at any time, and your continued use constitutes acceptance of any changes.'
      },
      {
        't': '2. Eligibility & Account Registration',
        'c': 'You must be at least 13 years of age (or the minimum age required in your jurisdiction) to use Hidden Pantry. By registering, you confirm that you meet this requirement.\n\nWhen creating an account, you agree to:\n• Provide accurate, current, and complete information\n• Maintain and promptly update your account information\n• Keep your password secure and confidential\n• Accept responsibility for all activity that occurs under your account\n• Notify us immediately of any unauthorised use of your account\n\nWe reserve the right to refuse registration or cancel accounts at our sole discretion.'
      },
      {
        't': '3. User Responsibilities',
        'c': 'As a user of Hidden Pantry, you are responsible for:\n• Using the app in compliance with all applicable laws and regulations\n• Ensuring that any content you post or upload is accurate and does not infringe any third-party rights\n• Respecting the rights and privacy of other users and nutritionists\n• Maintaining the security of your login credentials\n• Any consequences arising from your use of the app or reliance on its content\n\nYou acknowledge that nutritional and dietary advice provided within the app is for informational purposes only and does not constitute professional medical advice. Always consult a qualified healthcare professional for medical concerns.'
      },
      {
        't': '4. Acceptable Use Policy',
        'c': 'You agree not to use Hidden Pantry to:\n• Violate any law or regulation\n• Post content that is unlawful, defamatory, harassing, or obscene\n• Impersonate any person or entity\n• Upload viruses or harmful software\n• Attempt unauthorised access to any part of the app\n• Scrape, crawl, or harvest data without permission\n• Interfere with the integrity or performance of the app\n• Engage in unauthorised commercial activity\n• Send unsolicited communications or spam\n\nViolation may result in immediate account suspension or termination without notice.'
      },
      {
        't': '5. Nutritionist Services',
        'c': 'For Users: Subscriptions to nutritionists provide access to content, meal plans, and consultations. Subscriptions are managed through Google Play Billing or Apple In-App Purchase. Fees and refund policies are governed by platform policies.\n\nFor Nutritionists: Nutritionists agree to provide accurate credentials and comply with professional standards. Hidden Pantry acts solely as a platform connecting them with users and is not responsible for the quality or outcomes of their advice.'
      },
      {
        't': '6. Subscriptions & Payments',
        'c': 'Certain features require a paid subscription. Fees are charged in advance on a recurring basis. Payments are processed by Google Play or Apple. You may cancel at any time through store settings; cancellation takes effect at the end of the current billing period. No partial refunds are issued unless required by law. We may change pricing with reasonable notice.'
      },
      {
        't': '7. Intellectual Property',
        'c': 'All content within Hidden Pantry (design, logos, text, recipes, code) is our exclusive property. You are granted a limited, non-exclusive, revocable licence for personal use only. You may not copy, modify, distribute, reverse engineer, or use our branding without consent. Content uploaded by nutritionists remains their property, but they grant us a licence to display it.'
      },
      {
        't': '8. User-Generated Content',
        'c': 'By submitting content (reviews, comments, profile info), you grant us a worldwide, royalty-free licence to use and distribute it. You represent that you own the content and it does not violate third-party rights. We reserve the right to remove inappropriate content without notice.'
      },
      {
        't': '9. Privacy',
        'c': 'Your use of Hidden Pantry is also governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the app, you consent to the collection and use of your information as described therein.'
      },
      {
        't': '10. Disclaimers',
        'c': 'Hidden Pantry is provided "as is" without warranties. We do not warrant that the app will be uninterrupted, error-free, or that nutritional information is suitable for your specific health conditions. Content is for general info only; always consult a healthcare provider before significant dietary changes.'
      },
      {
        't': '11. Limitation of Liability',
        'c': 'To the fullest extent permitted by law, Hidden Pantry shall not be liable for indirect, incidental, or consequential damages, loss of profits, data, or damages arising from reliance on nutritional advice. Our total liability shall not exceed the amount paid by you in the 12 months preceding the claim.'
      },
      {
        't': '12. Indemnification',
        'c': 'You agree to indemnify and hold harmless Hidden Pantry and its affiliates from any claims, liabilities, or expenses arising out of your use of the app, violation of these Terms, or infringement of third-party rights.'
      },
      {
        't': '13. Account & Data Deletion',
        'c': 'Account Deletion: You may delete your account and all data permanently through "Settings". This action is irreversible.\n\nSpecific Data Deletion: You may delete specific data without deleting your account, including:\n• Recipes: Through "My Recipes"\n• Chat Messages: Through "Clear Chat" in conversations\n• Profile Data: Through Profile Settings\n\nFor more instructions, visit our Data & Account Management Page.'
      },
      {
        't': '14. Termination by Us',
        'c': 'We reserve the right to suspend or terminate your account without notice if you violate these Terms, provide false info, or engage in conduct harmful to others or the platform. Upon termination, your right to use the App ceases immediately.'
      },
      {
        't': '15. Governing Law & Dispute Resolution',
        'c': 'These Terms are governed by applicable law. Any disputes shall first be attempted to be resolved through good-faith negotiation. If unresolved, disputes may be submitted to binding arbitration or competent courts.'
      },
      {
        't': '16. Updates to These Terms',
        'c': 'We may update these Terms at any time. Significant changes will be notified via in-app notification or email. The "Last Updated" date will reflect the most recent version. Continued use constitutes acceptance of revised Terms.'
      },
      {
        't': '17. Severability & Entire Agreement',
        'c': 'If any provision is found unenforceable, it will be limited to the minimum extent necessary. These Terms and our Privacy Policy constitute the entire agreement between you and Hidden Pantry, superseding all prior understandings.'
      },
      {
        't': '18. Contact Us',
        'c': 'If you have any questions or concerns about these Terms, please reach out:\n📧 Email: hiddenpantry.support@gmail.com\n🌐 Website: hiddenpantry.app'
      },
    ];

    return sections.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;
      final isSection9 = index == 8;
      final isSection13 = index == 12;
      final isSection18 = index == 17;

      return _FadeSlideEntry(
        delayMs: 100 + (index * 50),
        child: Padding(
          padding: EdgeInsets.only(bottom: 24.sh),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section['t']!, style: h),
              SizedBox(height: 8.sh),
              if (isSection9)
                RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: base,
                    children: [
                      const TextSpan(text: 'Your use of Hidden Pantry is also governed by our '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _launchURL('https://hiddenpantry.app/privacy'),
                          child: Text('Privacy Policy', style: linkStyle),
                        ),
                      ),
                      const TextSpan(text: ', which is incorporated into these Terms by reference. By using the app, you consent to the collection and use of your information as described therein.'),
                    ],
                  ),
                )
              else if (isSection13)
                RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: base,
                    children: [
                      const TextSpan(text: 'Account Deletion: You may delete your account and all data permanently through "Settings". This action is irreversible.\n\nSpecific Data Deletion: You may delete specific data without deleting your account, including:\n• Recipes: Through "My Recipes"\n• Chat Messages: Through "Clear Chat" in conversations\n• Profile Data: Through Profile Settings\n\nFor more instructions, please visit our '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _launchURL('https://hiddenpantry.app/data-deletion'),
                          child: Text('Data & Account Management Page', style: linkStyle),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                )
              else if (isSection18)
                RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(
                    style: base,
                    children: [
                      const TextSpan(text: 'If you have any questions or concerns about these Terms, please reach out:\n📧 Email: '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _launchURL('mailto:hiddenpantry.support@gmail.com'),
                          child: Text('hiddenpantry.support@gmail.com', style: linkStyle),
                        ),
                      ),
                      const TextSpan(text: '\n🌐 Website: '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _launchURL('https://hiddenpantry.app'),
                          child: Text('hiddenpantry.app', style: linkStyle),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  section['c']!,
                  style: base,
                  textAlign: TextAlign.justify,
                ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _FadeSlideEntry({required this.child, required this.delayMs});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
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
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - _opacity.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _OnboardingBackgroundPattern extends StatelessWidget {
  const _OnboardingBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100.sh,
            right: -100.sw,
            child: _OnboardingFloatingOrb(
              color: const Color(0xFFFFE0D3).withValues(alpha: 0.5),
              size: 400,
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: 100.sh,
            left: -150.sw,
            child: _OnboardingFloatingOrb(
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

class _OnboardingFloatingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _OnboardingFloatingOrb({required this.color, required this.size, required this.duration});

  @override
  State<_OnboardingFloatingOrb> createState() => _OnboardingFloatingOrbState();
}

class _OnboardingFloatingOrbState extends State<_OnboardingFloatingOrb> with SingleTickerProviderStateMixin {
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




