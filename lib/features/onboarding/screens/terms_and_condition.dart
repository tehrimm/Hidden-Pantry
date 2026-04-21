import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    // Bottom panel height ONLY when not viewOnly
    final panelHeight = widget.viewOnly ? 0.0 : 160.sh;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      body: SizedBox.expand(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
          child: Stack(
            children: [
              // Background
              Container(color: const Color(0xFFFFF3EB)),

              // Decorative rings
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
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(136.sw, 80.sh),
                      ),
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
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(152.sw, 165.sh),
                      ),
                    ),
                  ),
                ),
              ),

              // Back button
              Positioned(
                left: 30.sw,
                top: MediaQuery.paddingOf(context).top + 30.sh,
                child: GestureDetector(
                onTap: () {
                  if (widget.viewOnly) {
                    // Return to the previous screen (LoadingFour)
                    Navigator.pop(context);
                  } else {
                    // Onboarding flow back
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LoadingFour(),
                        transitionDuration: const Duration(milliseconds: 400),
                        transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      ),
                    );
                  }
                },

                  child: Container(
                    width: 50.sw,
                    height: 50.sw,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9E3D5),
                      borderRadius: BorderRadius.circular(25.sw),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18.sp,
                      color: const Color(0xFF462F4D),
                    ),
                  ),
                ),
              ),

              // Title
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

              // Terms (scrollable) bottom changes based on viewOnly
              Positioned(
                left: 29.sw,
                right: 29.sw,
                top: MediaQuery.paddingOf(context).top + 120.sh,
                bottom: widget.viewOnly ? MediaQuery.paddingOf(context).bottom + 16.sh : panelHeight,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _termsRichText(fontSize: 14.sp),
                ),
              ),

              // Bottom panel ONLY if NOT viewOnly
              if (!widget.viewOnly)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
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
                        // Checkbox row
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
                                  border: Border.all(
                                    color: const Color(0xFF462F4D),
                                    width: 1.5.sw,
                                  ),
                                ),
                                child: agreed
                                    ? Icon(Icons.check,
                                        size: 14.sp,
                                        color: const Color(0xFF462F4D))
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

                        // Button
                        GestureDetector(
                          onTap: agreed
                              ? () {
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const LoadingFive(),
                                      transitionDuration: const Duration(milliseconds: 400),
                                      transitionsBuilder: (_, anim, __, child) =>
                                        FadeTransition(opacity: anim, child: child),
                                    ),
                                  );
                                }
                              : null,
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
      ),
    );
  }

  /// Bolded parts: Flutter doesn't understand *asterisks* by default.
  Widget _termsRichText({required double fontSize}) {
    final base = TextStyle(
      color: const Color(0xFF462F4D),
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      fontFamily: 'Satoshi',
      height: 1.5,
    );

    final h = base.copyWith(fontWeight: FontWeight.w800);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By downloading, accessing, or using '),
          TextSpan(text: 'Hidden Pantry', style: h),
          const TextSpan(
            text:
                ', you agree to comply with and be bound by the following Terms & Conditions. If you do not agree, please discontinue use of the application.\n\n',
          ),
          TextSpan(text: '1. Acceptance of Terms\n', style: h),
          const TextSpan(
            text:
                'By creating an account or using Hidden Pantry, you confirm that you have read, understood, and agreed to these Terms & Conditions and the Privacy Policy.\n\n',
          ),
          TextSpan(text: '2. Purpose of the Application\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry is designed to:\n'
                'Allow users to manually enter or scan ingredients using the device camera. Suggest recipes based on available ingredients and user preferences. '
                'Provide cooking guidance and food-related educational content. Enable users to save recipes and access selected features offline. '
                'Support community interaction through ratings, reviews, and recipe sharing. Offer optional subscription-based nutritionist services.\n\n'
                'Hidden Pantry is not intended to replace professional medical treatment or emergency care.\n\n',
          ),
          TextSpan(text: '3. User Eligibility\n', style: h),
          const TextSpan(
            text:
                'Users must be at least 15 years of age to use the application. Users are responsible for providing accurate and truthful account information. Any activity performed through a user account is the responsibility of the account holder.\n'
                'Hidden Pantry is not responsible for misuse of the application caused by incorrect or false user information.\n\n',
          ),
          TextSpan(text: '4. User Responsibilities\n', style: h),
          const TextSpan(
            text:
                'Users agree to:\n'
                'Provide accurate ingredient, allergy, and dietary preference information. Use the application only for lawful and personal purposes. '
                'Avoid uploading harmful, misleading, offensive, or copyrighted content. Maintain respectful conduct within community features. '
                'Users are solely responsible for their actions and content shared within the application.\n\n',
          ),
          TextSpan(text: '5. Recipes & Nutritional Disclaimer\n', style: h),
          const TextSpan(
            text:
                'Recipes and food-related information are provided for informational purposes only. Nutritional values may be estimates and can vary based on ingredients used. Users must verify ingredients to avoid allergies or dietary conflicts.\n'
                'Hidden Pantry is not responsible for cooking results or food preparation outcomes.\n\n',
          ),
          TextSpan(text: '6. Ingredient Recognition & Detection Model\n', style: h),
          const TextSpan(
            text:
                'Ingredient detection is performed using a custom-built model developed by the Hidden Pantry team. The model is designed to assist users in identifying ingredients from images. Detection accuracy may vary depending on image quality, lighting conditions, and ingredient presentation. In case of incorrect or unclear detection due to these factors, users are advised to switch to manual ingredient entry.\n\n',
          ),
          TextSpan(text: 'Allergy Responsibility Disclaimer\n', style: h),
          const TextSpan(
            text:
                'The ingredient detection model does not cover all possible allergens. Users must personally verify ingredients and allergen information before cooking.\n'
                'Hidden Pantry shall not be held responsible for allergic reactions, health issues, or mishaps resulting from the use of detected or manually entered ingredients.\n\n',
          ),
          TextSpan(text: '8. Subscription to Nutritionist Services\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry may offer paid subscription plans that provide access to:\n'
                'Personalized dietary guidance. Meal planning support. Nutrition-related premium features. Access to verified professional nutritionists.\n\n',
          ),
          TextSpan(text: 'Subscription Terms\n', style: h),
          const TextSpan(
            text:
                'Subscriptions may be billed on a monthly or yearly basis, depending on the selected plan. Payments are processed through the official app store platform. Subscription fees are non-refundable, except where required by law. Subscriptions automatically renew unless canceled before the renewal date.\n\n',
          ),
          TextSpan(text: 'Accidental Subscriptions & Payments\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry shall not be held accountable for any accidental, unintended, or mistaken subscription purchases. Users are responsible for reviewing all subscription details before confirming payment.\n\n',
          ),
          TextSpan(text: 'Payment Responsibility\n', style: h),
          const TextSpan(
            text:
                'If a user adds payment or card information with or without parental knowledge, it is assumed that proper consent has been obtained. Hidden Pantry is not liable for charges, subscription fees, or financial transactions made through the user’s account. All subscription management, cancellation, and refund requests (if applicable) must be handled through the respective app store.\n\n',
          ),
          TextSpan(text: '9. Nutritionist Services & Professional Assurance\n', style: h),
          const TextSpan(
            text:
                'All nutritionists available through Hidden Pantry are verified professionals. Nutritionists are qualified and provide guidance based on accepted health and nutrition standards. Recommendations are tailored using user-provided information and preferences. While guidance is provided by professionals, users remain responsible for following recommendations appropriately and sharing accurate health and dietary information.\n\n',
          ),
          TextSpan(text: '10. User-Generated Content\n', style: h),
          const TextSpan(
            text:
                'Users may submit recipes, reviews, ratings, comments, and tips. By submitting content, users grant Hidden Pantry a non-exclusive, royalty-free right to display and use such content within the application. Hidden Pantry reserves the right to remove content that violates community standards.\n\n',
          ),
          TextSpan(text: '11. Offline Access & Data Storage\n', style: h),
          const TextSpan(
            text:
                'Certain features may be available offline after initial download. Locally stored data may be lost if the application is uninstalled or device storage is cleared. Hidden Pantry is not responsible for data loss caused by device or system issues.\n\n',
          ),
          TextSpan(text: '12. Privacy & Data Protection\n', style: h),
          const TextSpan(
            text:
                'Personal data is handled according to the Privacy Policy. Camera and microphone permissions are used solely for application features. Hidden Pantry does not sell or misuse personal data.\n\n',
          ),
          TextSpan(text: '13. Account Suspension & Termination\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry reserves the right to suspend or terminate accounts that:\n'
                'Violate these Terms & Conditions\n'
                'Misuse subscription features\n'
                'Engage in abusive, fraudulent, or harmful behavior\n'
                'Users may delete their account at any time.\n\n',
          ),
          TextSpan(text: '14. Intellectual Property\n', style: h),
          const TextSpan(
            text:
                'All content, branding, designs, models, and materials within the application are the property of Hidden Pantry. Unauthorized copying, modification, or redistribution is prohibited.\n\n',
          ),
          TextSpan(text: '15. Limitation of Liability\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry shall not be held liable for:\n'
                'Ingredient detection inaccuracies\n'
                'Recipe or nutrition outcomes\n'
                'Allergic reactions or food-related mishaps\n'
                'Accidental or unintended subscription purchases\n'
                'Data loss, service interruptions, or technical issues\n'
                'Use of the application is entirely at the user’s own discretion and risk.\n\n',
          ),
          TextSpan(text: '16. Changes to Terms\n', style: h),
          const TextSpan(
            text:
                'Hidden Pantry may update these Terms & Conditions at any time. Continued use of the application after changes indicates acceptance of the updated terms.\n\n',
          ),
          TextSpan(text: '17. Contact Information\n', style: h),
          const TextSpan(
            text:
                'For questions or support, contact us at:\n'
                'hiddenpantry.support@email.com',
          ),
        ],
      ),
    );
  }
}



