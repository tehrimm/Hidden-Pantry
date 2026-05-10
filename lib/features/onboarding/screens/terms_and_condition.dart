import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    final panelHeight = widget.viewOnly ? 0.0 : 160.sh;

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

              // Animated Title & Back
              _FadeSlideEntry(
                delayMs: 100,
                child: Stack(
                  children: [
                    Positioned(
                      left: 30.sw,
                      top: MediaQuery.paddingOf(context).top + 30.sh,
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
                    Positioned(
                      left: 120.sw,
                      top: MediaQuery.paddingOf(context).top + 20.sh,
                      child: SizedBox(
                        width: 220.sw,
                        child: Text(
                          'Terms and\nCondition',
                          style: TextStyle(
                            color: const Color(0xFF462F4D),
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Satoshi',
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Scrollable Terms
              Positioned(
                left: 29.sw,
                right: 29.sw,
                top: MediaQuery.paddingOf(context).top + 120.sh,
                bottom: widget.viewOnly ? MediaQuery.paddingOf(context).bottom + 16.sh : panelHeight,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: _getTermsWidgets(fontSize: 14.sp),
                ),
              ),

              // Bottom Panel (Animated)
              if (!widget.viewOnly)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FadeSlideEntry(
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
                ),
            ],
          ),
        ),
      ),
    );
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

    final sections = [
  {
    't': 'Overview',
    'c': 'By downloading, accessing, or using Hidden Pantry, you agree to comply with and be bound by the following Terms & Conditions. Hidden Pantry is a platform designed to support smart cooking, nutrition, and professional dietary guidance.'
  },
  {
    't': '1. Acceptance of Terms',
    'c': 'By creating an account, you confirm that you have read, understood, and agreed to these Terms & Conditions. This includes acceptance of our hybrid RSA-AES encryption protocols used for secure communication.'
  },
  {
    't': '2. Messaging & Encryption (E2EE)',
    'c': 'Hidden Pantry prioritizes user privacy. All messages between nutritionists and clients are protected by End-to-End Encryption (E2EE). Private keys are stored locally on your device and are never shared with our servers. While we provide the infrastructure, we cannot read or decrypt your private conversations.'
  },
  {
    't': '3. Nutritionist Services & Fees',
    'c': 'Hidden Pantry facilitates connections with verified nutritionists. For all paid services and subscriptions processed through the platform, a 10% platform commission is applied to support platform maintenance, development, and security. Users are responsible for reviewing individual nutritionist plans before purchase.'
  },
  {
    't': '4. Voice Mode & Smart Scanning',
    'c': 'Our Smart Scanning and Voice-Controlled cooking features process data in real-time. To maintain privacy, audio inputs and pantry images are not stored on our servers unless explicitly enabled by the user for synchronization or personalization purposes.'
  },
  {
    't': '5. Subscriptions & Billing',
    'c': 'Subscriptions are managed through our secure billing system. Plans may be offered on a monthly, quarterly, or yearly basis. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current billing period. Pricing and features may vary depending on the selected plan.'
  },
  {
    't': '6. Payments, Refunds & Disputes',
    'c': 'All payments are securely processed through third-party payment providers. Hidden Pantry does not store or have access to your payment details. Refund policies are defined by individual nutritionists unless otherwise stated. In case of disputes, users may contact our support team for assistance.'
  },
  {
    't': '7. User Responsibilities',
    'c': 'Users agree to provide accurate and up-to-date health, dietary, and personal information. Hidden Pantry is not responsible for any health issues, allergic reactions, or consequences resulting from inaccurate information or misuse of the platform’s recommendations.'
  },
  {
    't': '8. Account & Data Deletion',
    'c': 'You may delete your account at any time through the Profile Settings. Account deletion is permanent and removes all personal data, recipes, and history. Additionally, you can delete specific content like uploaded recipes or clear chat history without deleting your entire account. For detailed instructions, visit hiddenpantry.app/delete-account.'
  },
  {
    't': '9. Limitation of Liability',
    'c': 'Hidden Pantry provides nutritional guidance and recommendations for informational purposes only. We do not guarantee medical outcomes. Users are encouraged to consult licensed healthcare professionals for serious medical conditions. Hidden Pantry shall not be held liable for any damages arising from the use of the platform.'
  },
  {
    't': '10. Privacy Policy',
    'c': 'User data is handled in accordance with our Privacy Policy. By using Hidden Pantry, you consent to the collection, processing, and use of information as described in our privacy practices.'
  },
  {
    't': '11. Changes to Terms',
    'c': 'Hidden Pantry reserves the right to update or modify these Terms & Conditions at any time. Continued use of the platform after any changes constitutes acceptance of the revised terms.'
  },
  {
    't': '12. AI Recommendations',
    'c': 'Recipe suggestions, ingredient analysis, and nutritional recommendations generated by Hidden Pantry are based on algorithmic processing and should not be considered professional medical advice.'
  },
  {
    't': '13. Contact & Support',
    'c': 'For questions regarding these Terms & Conditions, billing, or data-related concerns, please contact our support team at hiddenpantry.support@gmail.com.'
  },
];

    return sections.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;
      return Padding(
        padding: EdgeInsets.only(bottom: 24.sh),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section['t']!, style: h),
            SizedBox(height: 8.sh),
            Text(section['c']!, style: base),
          ],
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




