import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/features/user/services/payment_service.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // Logic & Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();

  final _paymentService = PaymentService();
  final _stripeService = StripeService();
  bool _saving = false;
  bool _verifying = false;
  bool _saveForFuture = true;

  // Figma base
  static const double _baseW = 393;
  static const double _baseH = 852;

  // Colors
  static const Color _bg = Color(0xFFFFF3EB);
  static const Color _title = Color(0xFF462F4D);
  static const Color _btn = Color(0xFFF2894F);
  static const Color _btnText = Color(0xFFFFF2EA);
  static const Color _circle = Color(0xFFF9E3D5);
  static const Color _patternStroke = Color(0xFFF5DDCE);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _cvcCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    // Step 1: Tokenize card via Stripe SDK
    setState(() => _verifying = true);

    try {
      // Parse expiry
      final expiryParts = _expiryCtrl.text.trim().split('/');
      final expMonth = expiryParts[0];
      final expYear = expiryParts.length > 1 ? expiryParts[1] : '';

      final pmId = await _stripeService.createPaymentMethod(
        cardNumber: _numberCtrl.text.trim().replaceAll(' ', ''),
        expMonth: expMonth,
        expYear: expYear,
        cvc: _cvcCtrl.text.trim(),
        cardHolderName: _nameCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _verifying = false;
        _saving = true;
      });

      // Step 2: Save card to Firestore with Stripe PM ID
      await _paymentService.saveCard(
        cardNumber: _numberCtrl.text.trim(),
        expiryDate: _expiryCtrl.text.trim(),
        cvv: _cvcCtrl.text.trim(),
        cardHolderName: _nameCtrl.text.trim(),
        stripePaymentMethodId: pmId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Card verified & saved via Stripe!")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StripeService.friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX 1: outer background must match design, not white
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth / _baseW;
          final dx = (c.maxWidth - _baseW * s) / 2;
          // Ensure dy is not negative to prevent UI from going up off-screen
          final dy = math.max(0.0, (c.maxHeight - _baseH * s) / 2);

          double sx(double v) => v * s;
          double sy(double v) => v * s;

          return Stack(
            children: [
              // FIX 2: fill extra space with the same bg to remove white edges
              Positioned.fill(child: Container(color: _bg)),

              SingleChildScrollView(
                child: Container(
                  width: c.maxWidth,
                  height: math.max(c.maxHeight, _baseH * s + dy),
                  child: Stack(
                    children: [
                      Positioned(
                        left: dx,
                        top: dy,
                        width: _baseW * s,
                        height: _baseH * s,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(sx(30)),
                          child: Stack(
                            children: [
                              Positioned.fill(child: Container(color: _bg)),
                              _Pattern(scale: s, stroke: _patternStroke),

                              // Back button
                              Positioned(
                                left: sx(30),
                                top: sy(51),
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: Container(
                                    width: sx(50),
                                    height: sy(50),
                                    decoration: BoxDecoration(
                                      color: _circle,
                                      borderRadius: BorderRadius.circular(sx(25)),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/icons/backButton.png',
                                        width: sx(18),
                                        height: sy(18),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Title
                              Positioned(
                                left: sx(0),
                                right: sx(0),
                                top: sy(55),
                                child: Center(
                                  child: Text(
                                    'Payment Information',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _title,
                                      fontSize: sx(20),
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ),
                              ),

                              // Card image
                              Positioned(
                                left: sx(50),
                                top: sy(158),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(sx(9)),
                                      child: Image.asset(
                                        'assets/Logos/card.png',
                                        width: sx(292),
                                        height: sy(178),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    SizedBox(height: sy(8)),
                                  ],
                                ),
                              ),

                              // Form Fields
                              Positioned(
                                left: sx(30),
                                top: sy(362),
                                width: sx(332),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _InputBox(
                                        scale: s,
                                        width: 332,
                                        height: 70,
                                        hint: 'Holder Name',
                                        controller: _nameCtrl,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                                      ),
                                      SizedBox(height: sy(12)), // Consistent spacing
                                      _InputBox(
                                        scale: s,
                                        width: 332,
                                        height: 70,
                                        hint: 'Card Number',
                                        controller: _numberCtrl,
                                        keyboardType: TextInputType.number,
                                        formatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          _CardNumberFormatter(),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Required';
                                          // 16 digits + 3 spaces = 19 characters
                                          if (v.replaceAll(' ', '').length < 16) return 'Invalid Card Number';
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: sy(12)),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _InputBox(
                                              scale: s,
                                              width: 162,
                                              height: 70,
                                              hint: 'CVC',
                                              controller: _cvcCtrl,
                                              keyboardType: TextInputType.number,
                                              formatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                                LengthLimitingTextInputFormatter(3),
                                              ],
                                              validator: (v) =>
                                                  (v == null || v.trim().length < 3) ? 'Invalid' : null,
                                            ),
                                          ),
                                          SizedBox(width: sx(13)),
                                          Expanded(
                                            child: _InputBox(
                                              scale: s,
                                              width: 162,
                                              height: 70,
                                              hint: 'MM/YY',
                                              controller: _expiryCtrl,
                                              keyboardType: TextInputType.number,
                                              formatters: [
                                                _ExpiryDateFormatter(),
                                              ],
                                              validator: (v) {
                                                if (v == null || v.trim().isEmpty) return 'Required';
                                                if (v.length < 5) return 'Invalid Date';
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: sy(16)),
                                      // Save for future payment toggle
                                      GestureDetector(
                                        onTap: () => setState(() => _saveForFuture = !_saveForFuture),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: sx(20),
                                              height: sy(20),
                                              child: Checkbox(
                                                value: _saveForFuture,
                                                onChanged: (v) => setState(() => _saveForFuture = v ?? true),
                                                activeColor: _btn,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sx(4))),
                                                side: BorderSide(color: _title.withValues(alpha: 0.3), width: 1.5),
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                            SizedBox(width: sx(10)),
                                            Text(
                                              'Save for future payments',
                                              style: TextStyle(
                                                color: _title.withValues(alpha: 0.6),
                                                fontSize: sx(12),
                                                fontFamily: 'Satoshi',
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: sy(20)),
                                      // Save button with verification states
                                      (_verifying || _saving)
                                          ? SizedBox(
                                              width: sx(332),
                                              height: sy(62),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: _btn.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(sx(20)),
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      SizedBox(
                                                        width: sx(16),
                                                        height: sy(16),
                                                        child: CircularProgressIndicator(
                                                          color: _btn,
                                                          strokeWidth: sx(2),
                                                        ),
                                                      ),
                                                      SizedBox(width: sx(10)),
                                                      Text(
                                                        _verifying ? 'Verifying with Stripe...' : 'Saving...',
                                                        style: TextStyle(
                                                          color: _btn,
                                                          fontSize: sx(13),
                                                          fontWeight: FontWeight.w600,
                                                          fontFamily: 'Satoshi',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          : SizedBox(
                                              width: sx(332),
                                              height: sy(62),
                                              child: ElevatedButton(
                                                onPressed: _saveCard,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _btn,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(sx(20)),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Verify & Save Card',
                                                  style: TextStyle(
                                                    color: _btnText,
                                                    fontSize: sx(15),
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'Satoshi',
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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final double scale;
  final double width;
  final double height;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _InputBox({
    required this.scale,
    required this.width,
    required this.height,
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
              width: width * scale,
              height: height * scale,
              decoration: BoxDecoration(
                color: hasError ? _errorBg : _fieldBg,
                borderRadius: BorderRadius.circular(20 * scale),
              ),
              padding: EdgeInsets.symmetric(horizontal: 15 * scale),
              child: Center(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: formatters,
                  onChanged: (val) {
                    state.didChange(val);
                  },
                  style: TextStyle(
                    color: hasError ? _errorText : _text,
                    fontSize: 14 * scale,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: hasError ? _errorText : _text,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: _fieldHint,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      fontFamily: 'Satoshi',
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    // Hide default error text as we show it below
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: EdgeInsets.only(top: 4 * scale, left: 15 * scale),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(
                    color: _errorText,
                    fontSize: 11 * scale,
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

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);

    var newText = '';
    for (var i = 0; i < text.length; i++) {
      newText += text[i];
      if ((i + 1) % 4 == 0 && (i + 1) != 16 && i != text.length - 1) {
        newText += ' ';
      }
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);

    var newText = '';
    for (var i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 1 && text.length > 2) {
        newText += '/';
      }
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}


class _Pattern extends StatelessWidget {
  final double scale;
  final Color stroke;

  const _Pattern({required this.scale, required this.stroke});

  @override
  Widget build(BuildContext context) {
    double sx(double v) => v * scale;
    double sy(double v) => v * scale;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: sx(-154),
            top: sy(-14),
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: sx(271),
                height: sy(159),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(136), sy(80)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sx(-149),
            top: sy(-100),
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: sx(303),
                height: sy(329),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(sx(152), sy(165)),
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



