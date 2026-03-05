import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/screens/payment_setting.dart';

/// Full-screen payment error result.
/// Shows reason card, retry, try another method, and support link.
class PaymentErrorScreen extends StatefulWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final String planName;
  final double price;
  final String interval;

  const PaymentErrorScreen({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.planName,
    required this.price,
    required this.interval,
  });

  @override
  State<PaymentErrorScreen> createState() => _PaymentErrorScreenState();
}

class _PaymentErrorScreenState extends State<PaymentErrorScreen> {
  bool _retrying = false;

  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFEF8A54);
  static const Color _red = Color(0xFFE53935);

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
                onPressed: () => Navigator.pop(context),
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

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error Icon
                    _AnimatedErrorIcon(),
                    const SizedBox(height: 28),

                    // Headline
                    Text(
                      "Payment Unsuccessful",
                      style: TextStyle(
                        color: _purple,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We couldn't process your payment.\nDon't worry, you haven't been charged.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _purple.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Reason Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _red.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.info_outline_rounded, color: _red, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'What happened',
                                style: TextStyle(
                                  color: _purple,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.errorMessage,
                            style: TextStyle(
                              color: _purple.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontFamily: 'Satoshi',
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, color: _orange, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _getGuidance(widget.errorMessage),
                                    style: TextStyle(
                                      color: _purple.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontFamily: 'Satoshi',
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Retry Payment (idempotent)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _retrying
                            ? null
                            : () {
                                setState(() => _retrying = true);
                                widget.onRetry();
                                // The parent handles navigation after retry
                              },
                        icon: _retrying
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(
                          _retrying ? 'Retrying...' : 'Retry Payment',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          disabledBackgroundColor: _orange.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Try Another Method
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PaymentSettingScreen()),
                          );
                        },
                        icon: Icon(Icons.swap_horiz_rounded, size: 20, color: _purple),
                        label: Text(
                          'Try Another Method',
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
                    const SizedBox(height: 20),

                    // Support Link
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact support@hiddenpantry.app for help')),
                        );
                      },
                      icon: Icon(Icons.support_agent_rounded, size: 18, color: _purple.withValues(alpha: 0.5)),
                      label: Text(
                        'Contact Support',
                        style: TextStyle(
                          color: _purple.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontFamily: 'Satoshi',
                          decoration: TextDecoration.underline,
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

  String _getGuidance(String error) {
    final msg = error.toLowerCase();
    if (msg.contains('declined') || msg.contains('card')) {
      return 'Try checking your card details, ensuring sufficient balance, or use a different card.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Check your internet connection and try again.';
    }
    if (msg.contains('expired')) {
      return 'Your card may have expired. Please update your payment method.';
    }
    return 'Try again in a moment, or use a different payment method.';
  }
}

/// Animated X icon that scales in with bounce.
class _AnimatedErrorIcon extends StatefulWidget {
  @override
  State<_AnimatedErrorIcon> createState() => _AnimatedErrorIconState();
}

class _AnimatedErrorIconState extends State<_AnimatedErrorIcon>
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
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 52),
      ),
    );
  }
}
