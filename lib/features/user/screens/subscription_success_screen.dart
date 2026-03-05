import 'package:flutter/material.dart';

/// Full-screen subscription success result.
/// Shows plan summary, CTAs to chat or go home, and close button.
class SubscriptionSuccessScreen extends StatelessWidget {
  final String planName;
  final double price;
  final String interval;
  final DateTime expiryDate;
  final String nutritionistName;
  final String nutritionistId;
  final Map<String, dynamic> nutritionistData;

  const SubscriptionSuccessScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.interval,
    required this.expiryDate,
    required this.nutritionistName,
    required this.nutritionistId,
    required this.nutritionistData,
  });

  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFEF8A54);
  static const Color _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: _purple, size: 20),
                ),
              ),
            ),

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    _AnimatedCheckIcon(),
                    const SizedBox(height: 28),

                    // Headline
                    Text(
                      "You're All Set! 🎉",
                      style: TextStyle(
                        color: _purple,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Welcome message
                    Text(
                      "Welcome to your premium subscription with $nutritionistName. "
                      "You now have full access to personalized nutrition guidance.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _purple.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontFamily: 'Satoshi',
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Plan Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Plan name
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.star_rounded, color: _orange, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: TextStyle(
                                        color: _purple,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rs. ${price.toStringAsFixed(2)} / $interval',
                                      style: TextStyle(
                                        color: _purple.withValues(alpha: 0.5),
                                        fontSize: 13,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Divider(color: _purple.withValues(alpha: 0.08), height: 1),
                          const SizedBox(height: 18),

                          // Next Renewal
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Next Renewal',
                                style: TextStyle(
                                  color: _purple.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              Text(
                                _formatDate(expiryDate),
                                style: TextStyle(
                                  color: _purple,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Manage button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                // Navigate to My Subscriptions would go here
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _purple,
                                side: BorderSide(color: _purple.withValues(alpha: 0.15)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Manage Subscription',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Satoshi'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Primary CTA: Go to Chat
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Pop to nutritionist details, the chat access is already unlocked
                          Navigator.of(context).pop(); // back to nutritionist details
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                        label: const Text(
                          'Go to Nutritionist Chat',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Secondary CTA: Browse Home
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        icon: Icon(Icons.home_rounded, size: 20, color: _purple),
                        label: Text(
                          'Browse Home Screen',
                          style: TextStyle(
                            color: _purple,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _purple,
                          side: BorderSide(color: _purple.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Animated check circle that scales in with a bounce effect.
class _AnimatedCheckIcon extends StatefulWidget {
  @override
  State<_AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<_AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4CAF50),
              const Color(0xFF66BB6A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
      ),
    );
  }
}
