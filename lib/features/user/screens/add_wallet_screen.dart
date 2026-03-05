import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/services/payment_service.dart';

class AddWalletScreen extends StatefulWidget {
  final String walletType; // "easypaisa" or "jazzcash"

  const AddWalletScreen({super.key, required this.walletType});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _paymentService = const PaymentService();
  bool _saving = false;
  bool _verifying = false;

  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _purple = Color(0xFF462F4D);
  static const Color _orange = Color(0xFFF2894F);

  String get _title => widget.walletType == "easypaisa" ? "Easypaisa" : "JazzCash";
  Color get _brandColor => widget.walletType == "easypaisa"
      ? const Color(0xFF00A651)
      : const Color(0xFFE30613);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Step 1: Verify payment via API (simulated)
    setState(() => _verifying = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate API verification
    if (!mounted) return;
    setState(() => _verifying = false);

    // Step 2: Save wallet
    setState(() => _saving = true);
    try {
      await _paymentService.saveWallet(
        phoneNumber: _phoneCtrl.text.trim(),
        accountName: _nameCtrl.text.trim(),
        walletType: widget.walletType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$_title account verified & saved!")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const PatternBackground(),

          // Header
          Positioned(
            left: 30,
            top: 51,
            child: BackButtonWidget(color: _purple),
          ),
          Positioned(
            left: 0, right: 0,
            top: 51, height: 50,
            child: Center(
              child: Text(
                "Add $_title",
                style: const TextStyle(
                  color: _purple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Satoshi",
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand icon
                      Center(
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: _brandColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: _brandColor,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 32),

                      // Phone number field — matching card form error style
                      _StyledInput(
                        hint: "Phone Number (03XX XXXXXXX)",
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (v.trim().length < 11) return "Enter a valid 11-digit number";
                          if (!v.startsWith("03")) return "Number must start with 03";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Account name field — matching card form error style
                      _StyledInput(
                        hint: "Account Holder Name",
                        controller: _nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Required" : null,
                      ),
                      const SizedBox(height: 36),

                      // Save button with verification states
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: (_verifying || _saving)
                            ? Container(
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(
                                          color: _orange,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _verifying ? "Verifying with $_title..." : "Saving...",
                                        style: TextStyle(
                                          color: _orange,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: "Satoshi",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  "Verify & Save $_title",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "Satoshi",
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled input matching the card form's error states
class _StyledInput extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _StyledInput({
    required this.hint,
    this.controller,
    this.keyboardType,
    this.formatters,
    this.validator,
  });

  static const Color _fieldBg = Color(0xFFFDECE4);
  static const Color _fieldHint = Color(0xFFBFA89A);
  static const Color _errorBg = Color(0xFFFFE0DD);
  static const Color _errorText = Color(0xFFFD3250);
  static const Color _text = Color(0xFF462F4D);

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      initialValue: controller?.text ?? '',
      builder: (FormFieldState<String> state) {
        final bool hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 62,
              decoration: BoxDecoration(
                color: hasError ? _errorBg : _fieldBg,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: formatters,
                  onChanged: (val) => state.didChange(val),
                  style: TextStyle(
                    color: hasError ? _errorText : _text,
                    fontSize: 14,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: hasError ? _errorText : _text,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: _fieldHint,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 15),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: _errorText,
                    fontSize: 11,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
