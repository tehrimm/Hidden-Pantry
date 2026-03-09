
import 'package:flutter/material.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'login_user.dart'; 
import 'forget_password_email.dart';
import 'forget_password_phone.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
 // (create later or comment for now)


class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  // 0 = email, 1 = phone
  int _selected = 0;

  // UI colors (from your design)
  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);

  static const Color orange = Color(0xFFF2894F);
  static const Color btnText = Color(0xFFFFF2EA);


  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.sw),
          child: Stack(
            children: [
              const PatternBackground(),

              // Main content
              Padding(
                padding: EdgeInsets.only(
                  left: 30.sw,
                  right: 30.sw,
                  top: mq.padding.top + 36.sh,
                  bottom: 22.sh,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BackButtonWidget(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                        );
                      },
                    ),
                    SizedBox(height: 38.sh),


                    SizedBox(
                      width: 260.sw,
                      child: Text(
                        "Verification Method",
                        style: TextStyle(
                          color: purple,
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: 12.sh),

                    SizedBox(
                      width: 280.sw,
                      child: Text(
                        "Choose one way where you want us to send an OTP",
                        style: TextStyle(
                          color: purple,
                          fontSize: 15.sp,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: 28.sh),

                    // Option cards (responsive row)
                    Row(
                      children: [
                        Expanded(
                           child: _OptionCard(
                            title: "Email",
                            subtitle: "your@email.com",
                            icon: Image.asset(
                              "assets/icons/gmail.png",
                              width: 18.sw,
                              height: 18.sw,
                              fit: BoxFit.contain,
                            ),
                            selected: _selected == 0,
                            onTap: () => setState(() => _selected = 0),
                          ),
                        ),
                        SizedBox(width: 16.sw),
                        Expanded(
                          child: _OptionCard(
                            title: "Phone",
                            subtitle: "+Areacode \nXXX XXXXXXX",
                            icon: Icon(
                              Icons.phone_in_talk_rounded,
                              size: 18.sw,
                              color: Colors.white,
                            ),
                            selected: _selected == 1,
                            onTap: () => setState(() => _selected = 1),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40.sh),

                    // Next button aligned right (like your UI)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
onTap: () {
  if (_selected == 0) {
    // Email selected
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgetPasswordEmailScreen(),
      ),
    );
  } else {
    // Phone selected (OTP flow later)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgetPasswordPhoneScreen(),
      ),
    );
  }
},

                        child: Container(
                          width: 221.sw,
                          height: 62.sh,
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(20.sw),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Next",
                                style: TextStyle(
                                  color: btnText,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                              SizedBox(width: 8.sw),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12.sp,
                                color: btnText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 14.sh),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color cardBg = Color(0xFFF9E3D5);
  static const Color orange = Color(0xFFF2894F);
  static const Color brown = Color(0xFF74503C);
  static const Color selectRing = Color(0xFF462F4D);

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 173.sh,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(30.sw),
          border: Border.all(
            color: selected ? selectRing : Colors.transparent,
            width: 2.sw,
          ),
        ),
        padding: EdgeInsets.all(16.sw),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: 46.sw,
              height: 47.sh,
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(10.sw),
              ),
              alignment: Alignment.center,
              child: icon,
            ),

            SizedBox(height: 22.sh),

            Text(
              title,
              style: TextStyle(
                color: brown,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
            SizedBox(height: 6.sh),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: brown,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
      ),
    );
  }
}



