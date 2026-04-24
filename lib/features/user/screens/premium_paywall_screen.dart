import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/features/user/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isAnnual = false;
  final IAPService _iapService = IAPService();
  bool _isLoadingProducts = true;

  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFEF8A54);
  static const Color _bg = Color(0xFFFFF3EB);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await _iapService.fetchProducts();
    if (mounted) {
      setState(() => _isLoadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const PatternBackground(),
          
          // Glossy Overlays
          Positioned(
            top: -50.sh,
            right: -50.sw,
            child: _GlowCircle(color: _orange.withValues(alpha: 0.15), size: 300.sw),
          ),
          Positioned(
            bottom: -80.sh,
            left: -80.sw,
            child: _GlowCircle(color: _purple.withValues(alpha: 0.1), size: 400.sw),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.sw),
                    child: Column(
                      children: [
                        SizedBox(height: 20.sh),
                        _buildHeroSection(),
                        SizedBox(height: 30.sh),
                        _buildFeatureList(),
                        SizedBox(height: 30.sh),
                        _buildPlanToggle(),
                        if (!_isAnnual) ...[
                          SizedBox(height: 30.sh),
                          _buildTrialTimeline(),
                        ],
                        SizedBox(height: 40.sh),
                      ],
                    ),
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20.sw),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10.sw),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(Icons.close_rounded, color: _purple, size: 24.sw),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _showPrivacyInfo,
                child: Container(
                  padding: EdgeInsets.all(10.sw),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(Icons.info_outline_rounded, color: _purple, size: 24.sw),
                ),
              ),
              SizedBox(width: 12.sw),
              _buildTrialBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBadge() {
    if (_isAnnual) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 8.sh),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: _orange.withValues(alpha: 0.3)),
      ),
      child: Text(
        "7-Day Free Trial",
        style: TextStyle(
          color: _orange,
          fontWeight: FontWeight.w800,
          fontSize: 12.sp,
          fontFamily: 'Satoshi',
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          width: 80.sw,
          height: 80.sw,
          decoration: BoxDecoration(
            color: _orange,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _orange.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.star_rounded, color: Colors.white, size: 45.sw),
        ),
        SizedBox(height: 24.sh),
        Text(
          "Hidden Pantry Premium",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.w900,
            color: _purple,
            fontFamily: 'Satoshi',
            height: 1.2,
          ),
        ),
        SizedBox(height: 12.sh),
        Text(
          "Unlock the ultimate cooking experience with our premium toolkit.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            color: _purple.withValues(alpha: 0.6),
            fontFamily: 'Satoshi',
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    return Column(
      children: [
        _FeatureItem(
          icon: Icons.mic_rounded,
          title: "Voice-Controlled Cooking",
          subtitle: "Navigate recipes hands-free while your hands are busy.",
          color: const Color(0xFF7C4DFF),
        ),
        _FeatureItem(
          icon: Icons.camera_alt_rounded,
          title: "Smart Ingredient Scan",
          subtitle: "Snap a photo of your pantry to get instant recipe ideas.",
          color: const Color(0xFF00BFA5),
        ),
        _FeatureItem(
          icon: Icons.download_done_rounded,
          title: "Unlimited Downloads",
          subtitle: "Save as many recipes as you want for offline access.",
          color: _orange,
        ),
      ],
    );
  }

  Widget _buildTrialTimeline() {
    return Container(
      padding: EdgeInsets.all(20.sw),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24.sw),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How your trial works:",
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: _purple,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 20.sh),
          _TimelineStep(
            icon: Icons.lock_open_rounded,
            title: "Today",
            subtitle: "Instant access to all premium features.",
            isFirst: true,
          ),
          _TimelineStep(
            icon: Icons.mail_outline_rounded,
            title: "Day 5",
            subtitle: "We'll send you a reminder email.",
          ),
          _TimelineStep(
            icon: Icons.credit_card_rounded,
            title: "Day 7",
            subtitle: "Your card is charged Rs. 250 for the first month.",
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToggle() {
    return Container(
      padding: EdgeInsets.all(4.sw),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.sw),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleItem(
              title: "Monthly",
              isSelected: !_isAnnual,
              onTap: () => setState(() => _isAnnual = false),
            ),
          ),
          Expanded(
            child: _ToggleItem(
              title: "Annual",
              isSelected: _isAnnual,
              onTap: () => setState(() => _isAnnual = true),
              badge: "Save 5%",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.sw),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAnnual) ...[
                Text(
                  _getOriginalPriceLabel(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    decoration: TextDecoration.lineThrough,
                    color: _purple.withValues(alpha: 0.3),
                    fontFamily: 'Satoshi',
                  ),
                ),
                SizedBox(width: 10.sw),
              ],
              Text(
                _getPriceLabel(),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: _purple,
                  fontFamily: 'Satoshi',
                ),
              ),
              Text(
                _isAnnual ? " / year" : " / month",
                style: TextStyle(
                  fontSize: 16.sp,
                  color: _purple.withValues(alpha: 0.5),
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
          SizedBox(height: 20.sh),
          _PrimaryButton(
            text: _isAnnual ? "Subscribe Now" : "Start 7-Day Free Trial",
            onPressed: () => _handleSubscription(context),
            isPremium: true,
          ),
          SizedBox(height: 16.sh),
          Text(
            _isAnnual 
              ? "Charged annually. No trial included."
              : "No commitment. Cancel anytime before Day 7.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: _purple.withValues(alpha: 0.4),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  String _getPriceLabel() {
    if (_iapService.products.isEmpty) return _isAnnual ? "Rs. 2850" : "Rs. 250";
    final targetId = _isAnnual ? IAPService.annualID : IAPService.monthlyID;
    try {
      final product = _iapService.products.firstWhere((p) => p.id == targetId);
      return product.price;
    } catch (_) {
      return _isAnnual ? "Rs. 2850" : "Rs. 250";
    }
  }

  String _getOriginalPriceLabel() {
    if (_iapService.products.isEmpty) return "Rs. 3000";
    return _isAnnual ? "Rs. 3000" : ""; 
  }

  void _handleSubscription(BuildContext context) async {
    HapticFeedback.heavyImpact();
    
    // Check for tester first (they don't need real products loaded)
    if (_iapService.isTesterAccount()) {
      await _iapService.buyProduct(
        ProductDetails(
          id: _isAnnual ? IAPService.annualID : IAPService.monthlyID,
          title: 'Premium',
          description: '',
          price: '0',
          rawPrice: 0,
          currencyCode: 'PKR'
        ),
        context: context
      );
      return;
    }

    if (_iapService.products.isEmpty) {
      Toaster.show(context, "Billing service not ready. Please try again.", isError: true);
      return;
    }

    try {
      final targetId = _isAnnual ? IAPService.annualID : IAPService.monthlyID;
      final product = _iapService.products.firstWhere(
        (p) => p.id == targetId, 
        orElse: () => _iapService.products.first
      );

      await _iapService.buyProduct(product, context: context);
    } catch (e) {
      if (context.mounted) {
        Toaster.show(context, "Unable to process payment. Please try again.", isError: true);
      }
    }
  }

  void _showPrivacyInfo() {
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bg.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.sw),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
        ),
        title: Text(
          "Your Privacy Matters",
          style: TextStyle(
            color: _purple,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.sw),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.privacy_tip_rounded, color: _purple, size: 28.sw),
            ),
            SizedBox(height: 20.sh),
            Text(
              "Voice Mode and Smart Scanning do not record or store your data. All processing happens in real-time on your device for your privacy and safety.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _purple.withValues(alpha: 0.7),
                fontSize: 14.sp,
                fontFamily: 'Satoshi',
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.sh),
            _privacyBadge(Icons.cloud_off_rounded, "No audio/image storage"),
            _privacyBadge(Icons.mic_off_rounded, "No background processing"),
            _privacyBadge(Icons.security_rounded, "No external sharing"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Got it",
              style: TextStyle(
                color: _purple.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyBadge(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.sh),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16.sw, color: const Color(0xFF4CAF50)),
          SizedBox(width: 8.sw),
          Text(
            text,
            style: TextStyle(
              color: _purple.withValues(alpha: 0.8),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.sh),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.sw),
            ),
            child: Icon(icon, color: color, size: 24.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF462F4D),
                    fontFamily: 'Satoshi',
                  ),
                ),
                SizedBox(height: 4.sh),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF462F4D).withValues(alpha: 0.5),
                    fontFamily: 'Satoshi',
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPremium;

  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56.sh,
        decoration: BoxDecoration(
          color: isPremium ? const Color(0xFF462F4D) : const Color(0xFFEF8A54),
          borderRadius: BorderRadius.circular(16.sw),
          boxShadow: [
            BoxShadow(
              color: (isPremium ? const Color(0xFF462F4D) : const Color(0xFFEF8A54)).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            fontFamily: 'Satoshi',
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}
class _ToggleItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _ToggleItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12.sh),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12.sw),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF462F4D).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: const Color(0xFF462F4D).withValues(alpha: isSelected ? 1.0 : 0.4),
                fontFamily: 'Satoshi',
              ),
            ),
            if (badge != null) ...[
              SizedBox(width: 6.sw),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.sw, vertical: 2.sh),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF8A54).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.sw),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFEF8A54),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32.sw,
              height: 32.sw,
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFFEF8A54) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF8A54).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 16.sw,
                color: isFirst ? Colors.white : const Color(0xFF462F4D),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40.sh,
                color: const Color(0xFFEF8A54).withValues(alpha: 0.2),
              ),
          ],
        ),
        SizedBox(width: 16.sw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF462F4D),
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 4.sh),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF462F4D).withValues(alpha: 0.6),
                  fontFamily: 'Satoshi',
                  height: 1.3,
                ),
              ),
              if (!isLast) SizedBox(height: 16.sh),
            ],
          ),
        ),
      ],
    );
  }
}
