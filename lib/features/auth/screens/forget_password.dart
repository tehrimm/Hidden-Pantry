import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'login_user.dart'; 
import 'forget_password_email.dart';
import 'forget_password_phone.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
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

  double _scale(BuildContext context, double v) {
    final size = MediaQuery.of(context).size;
    final base = math.min(size.width / 393.0, size.height / 852.0);
    final clamped = base.clamp(0.85, 1.20);
    return v * clamped;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final s = (double v) => _scale(context, v);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(s(30)),
          child: Stack(
            children: [
              const PatternBackground(),

              // Main content
              Padding(
                padding: EdgeInsets.only(
                  left: s(30),
                  right: s(30),
                  top: mq.padding.top + s(51),
                  bottom: s(22),
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
                    SizedBox(height: s(38)),


                    SizedBox(
                      width: s(260),
                      child: Text(
                        "Verification Method",
                        style: TextStyle(
                          color: purple,
                          fontSize: s(40),
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: s(12)),

                    SizedBox(
                      width: s(280),
                      child: Text(
                        "Choose one way where you want us to send an OTP",
                        style: TextStyle(
                          color: purple,
                          fontSize: s(15),
                          fontFamily: "Satoshi",
                        ),
                      ),
                    ),

                    SizedBox(height: s(28)),

                    // Option cards (responsive row)
                    Row(
                      children: [
                        Expanded(
                          child: _OptionCard(
                            scale: s,
                            title: "Email",
                            subtitle: "your@email.com",
                            icon: Image.asset(
                              "assets/icons/gmail.png",
                              width: s(18),
                              height: s(18),
                              fit: BoxFit.contain,
                            ),
                            selected: _selected == 0,
                            onTap: () => setState(() => _selected = 0),
                          ),
                        ),
                        SizedBox(width: s(16)),
                        Expanded(
                          child: _OptionCard(
                            scale: s,
                            title: "Phone",
                            subtitle: "+Areacode \nXXX XXXXXXX",
                            icon: Icon(
                              Icons.phone_in_talk_rounded,
                              size: s(18),
                              color: Colors.white,
                            ),
                            selected: _selected == 1,
                            onTap: () => setState(() => _selected = 1),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: s(40)),

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
                          width: s(221),
                          height: s(62),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(s(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Next",
                                style: TextStyle(
                                  color: btnText,
                                  fontSize: s(12),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                              SizedBox(width: s(8)),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: s(12),
                                color: btnText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: s(14)),
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
  final double Function(double) scale;
  final String title;
  final String subtitle;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.scale,
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
    final s = scale;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: s(173),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(s(30)),
          border: Border.all(
            color: selected ? selectRing : Colors.transparent,
            width: s(2),
          ),
        ),
        padding: EdgeInsets.all(s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: s(46),
              height: s(47),
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(s(10)),
              ),
              alignment: Alignment.center,
              child: icon,
            ),

            SizedBox(height: s(22)),

            Text(
              title,
              style: TextStyle(
                color: brown,
                fontSize: s(20),
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
            SizedBox(height: s(6)),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: brown,
                fontSize: s(12),
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



