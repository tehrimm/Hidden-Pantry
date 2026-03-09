import 'package:flutter/material.dart';

class CreateCookbookBottomSheet extends StatefulWidget {
  final Function(String title, String description) onSave;

  const CreateCookbookBottomSheet({super.key, required this.onSave});

  @override
  State<CreateCookbookBottomSheet> createState() => _CreateCookbookBottomSheetState();
}

class _CreateCookbookBottomSheetState extends State<CreateCookbookBottomSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The user provided a 335 width but we'll adapt to screen width
    return Container(
      width: double.infinity,
      height: 377,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Handle/Bar at top
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: Container(
                width: 96,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF74503C),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          
          const Positioned(
            top: 41,
            left: 0,
            right: 0,
            child: Text(
              'Create new cookbook',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF462F4D),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Satoshi',
              ),
            ),
          ),

          // Title Input
          Positioned(
            left: 19,
            top: 98,
            right: 19,
            child: Container(
              height: 61,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _titleCtrl,
                style: const TextStyle(
                  color: Color(0xFF462F4D),
                  fontSize: 14,
                  fontFamily: 'Satoshi',
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Title',
                  labelStyle: TextStyle(
                    color: Color(0xFF462F4D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    fontFamily: 'Satoshi',
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ),

          // Description Input
          Positioned(
            left: 19,
            top: 167,
            right: 19,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _descCtrl,
                maxLines: 4,
                style: const TextStyle(
                  color: Color(0xFF462F4D),
                  fontSize: 14,
                  fontFamily: 'Satoshi',
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Description',
                  labelStyle: TextStyle(
                    color: Color(0xFF462F4D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    fontFamily: 'Satoshi',
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Back/Close Button
          Positioned(
            left: 19,
            bottom: 13,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 52,
                height: 53,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/back_button.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Save Button
          Positioned(
            left: 79,
            bottom: 13,
            right: 19,
            child: GestureDetector(
              onTap: () {
                if (_titleCtrl.text.trim().isNotEmpty) {
                  widget.onSave(_titleCtrl.text.trim(), _descCtrl.text.trim());
                  Navigator.pop(context);
                }
              },
              child: Container(
                height: 53,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2894F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFFFF2EA),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Satoshi',
                    ),
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



