import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/user/services/payment_service.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'payment_method.dart';
import 'add_wallet_screen.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class PaymentSettingScreen extends StatefulWidget {
  const PaymentSettingScreen({super.key});

  @override
  State<PaymentSettingScreen> createState() => _PaymentSettingScreenState();
}

class _PaymentSettingScreenState extends State<PaymentSettingScreen> {
  final PaymentService _paymentService = const PaymentService();

  List<Map<String, dynamic>> _methods = [];
  bool _loading = true;

  static const Color bg = Color(0xFFFFF3EB);
  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFF2894F);
  static const Color cardBg = Color(0xFFF9E3D5);
  static const Color fieldBg = Color(0xFFFDECE4);

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() => _loading = true);
    try {
      final list = await _paymentService.getCards();
      if (!mounted) return;
      setState(() {
        _methods = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Toaster.show(context, "Error loading methods: $e", isError: true);
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      await _paymentService.setDefaultPaymentMethod(id);
      _loadMethods();
    } catch (e) {
      if (!mounted) return;
      Toaster.show(context, "Error: $e", isError: true);
    }
  }

  Future<void> _deleteMethod(Map<String, dynamic> method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                "Remove Payment Method",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: purple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to remove this payment method?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: purple.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontFamily: "Satoshi",
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: purple,
                        side: BorderSide(color: purple.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text("Remove", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;
    try {
      await _paymentService.deleteCard(method['id']);
      _loadMethods();
    } catch (e) {
      if (!mounted) return;
      Toaster.show(context, "Error: $e", isError: true);
    }
  }

  void _openAddCard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
    ).then((_) => _loadMethods());
  }

  void _openAddWallet(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddWalletScreen(walletType: type)),
    ).then((_) => _loadMethods());
  }

  // ─── Helpers ───
  IconData _typeIcon(String? type) {
    switch (type) {
      case "easypaisa": return Icons.account_balance_wallet_rounded;
      case "jazzcash": return Icons.account_balance_wallet_rounded;
      default: return Icons.credit_card_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case "easypaisa": return const Color(0xFF00A651);
      case "jazzcash": return const Color(0xFFE30613);
      default: return orange;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case "easypaisa": return "Easypaisa";
      case "jazzcash": return "JazzCash";
      default: return "Card";
    }
  }

  String _getCardBrand(String? number) {
    if (number == null || number.isEmpty) return "Visa";
    final clean = number.replaceAll(' ', '');
    if (clean.startsWith('5')) return "Mastercard";
    return "Visa";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),

          // Header
          Positioned(
            left: 30, top: 51,
            child: BackButtonWidget(
              onPressed: () => Navigator.pop(context),
              color: purple,
            ),
          ),
          Positioned(
            left: 0, right: 0,
            top: 51,
            height: 50,
            child: const Center(
              child: Text(
                'Payment Methods',
                style: TextStyle(
                  color: purple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: orange))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      children: [
                        // ─── Add Payment Options ───
                        _sectionHeader("Add Payment Method"),
                        const SizedBox(height: 12),
                        _addOptionTile(
                          icon: Icons.credit_card_rounded,
                          color: orange,
                          title: "Add Debit/Credit Card",
                          onTap: _openAddCard,
                        ),
                        const SizedBox(height: 10),
                        _addOptionTile(
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF00A651),
                          title: "Add Easypaisa",
                          onTap: () => _openAddWallet("easypaisa"),
                        ),
                        const SizedBox(height: 10),
                        _addOptionTile(
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFFE30613),
                          title: "Add JazzCash",
                          onTap: () => _openAddWallet("jazzcash"),
                        ),
                        const SizedBox(height: 28),

                        // ─── Saved Methods ───
                        _sectionHeader(
                          "Saved Methods",
                          trailing: "${_methods.length} saved",
                        ),
                        const SizedBox(height: 12),

                        if (_methods.isEmpty)
                          _emptyState()
                        else
                          ..._methods.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _savedMethodTile(m),
                              )),

                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets ───

  Widget _sectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: purple,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: "Satoshi",
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              color: purple.withValues(alpha: 0.4),
              fontSize: 12,
              fontFamily: "Satoshi",
            ),
          ),
      ],
    );
  }

  Widget _addOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: subtitle != null ? 70 : 62,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Satoshi",
                    ),
                  ),
                  if (subtitle != null) ...[  
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Satoshi",
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: purple.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _savedMethodTile(Map<String, dynamic> m) {
    final type = m["type"] as String?;
    final isDefault = m["isDefault"] == true;
    final name = type == "card"
        ? (m["cardHolderName"] ?? "Card")
        : (m["accountName"] ?? "Account");
    final masked = m["maskedNumber"] ?? "****";
    final label = type == "card" ? _getCardBrand(m["cardNumber"]) : _typeLabel(type);

    return GestureDetector(
      onTap: () => _setDefault(m['id']),
      onLongPress: () => _deleteMethod(m),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDefault ? orange.withValues(alpha: 0.08) : cardBg,
          borderRadius: BorderRadius.circular(18),
          border: isDefault
              ? Border.all(color: orange.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _typeColor(type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: purple,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "DEFAULT",
                            style: TextStyle(
                              color: orange,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Satoshi",
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$label · $masked",
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            GestureDetector(
              onTap: () => _deleteMethod(m),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.credit_card_off_rounded, size: 48, color: purple.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text(
              "No payment methods saved yet",
              style: TextStyle(
                color: purple.withValues(alpha: 0.4),
                fontSize: 14,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
