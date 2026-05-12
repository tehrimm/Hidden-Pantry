import 'package:flutter/material.dart';

class ShareRecipePostDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Function(String message, int tier) onPost;

  const ShareRecipePostDialog({
    super.key,
    required this.recipe,
    required this.onPost,
  });

  @override
  State<ShareRecipePostDialog> createState() => _ShareRecipePostDialogState();
}

class _ShareRecipePostDialogState extends State<ShareRecipePostDialog> {
  final TextEditingController _controller = TextEditingController();
  int _selectedTier = 0; // 0: Free, 1: Silver, 2: Gold, 3: Platinum
  bool _isPosting = false;

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipeName = widget.recipe['name'] ?? widget.recipe['title'] ?? 'Recipe';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFF3EB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Share Recipe",
              style: TextStyle(
                color: purple,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: "Satoshi",
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Sharing: $recipeName",
              style: TextStyle(
                color: purple.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: TextStyle(color: purple, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Add a message (optional)...",
                hintStyle: TextStyle(color: purple.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFFFFF3EB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: purple.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: purple.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: orange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Visibility Tier",
              style: TextStyle(
                color: purple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: "Satoshi",
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tierChip(0, "Free", Icons.public_rounded),
                _tierChip(1, "Silver", Icons.star_half_rounded),
                _tierChip(2, "Gold", Icons.star_rounded),
                _tierChip(3, "Platinum", Icons.diamond_rounded),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: purple.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPosting
                        ? null
                        : () async {
                            setState(() => _isPosting = true);
                            await widget.onPost(_controller.text, _selectedTier);
                            if (mounted) Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isPosting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierChip(int tier, String label, IconData icon) {
    final bool isSelected = _selectedTier == tier;
    final Color tierColor = tier == 3 
        ? const Color(0xFF4B0082) 
        : tier == 2 
          ? const Color(0xFFDAA520) 
          : tier == 1 
            ? const Color(0xFF708090) 
            : purple;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedTier = tier);
      },
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : tierColor),
      selectedColor: tierColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : tierColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFFF9E3D5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? tierColor : tierColor.withValues(alpha: 0.2)),
      ),
      showCheckmark: false,
    );
  }
}
