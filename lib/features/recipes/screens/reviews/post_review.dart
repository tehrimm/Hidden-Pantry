import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

import '../../models/recipe.dart';
import '../../services/recipe_service.dart';

class PostReviewScreen extends StatefulWidget {
  final Recipe recipe;

  const PostReviewScreen({super.key, required this.recipe});

  @override
  State<PostReviewScreen> createState() => _PostReviewScreenState();
}

class _PostReviewScreenState extends State<PostReviewScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final RecipeService _recipeService = RecipeService();

  double _rating = 5.0;
  XFile? _image;
  bool _isSubmitting = false;
  bool _hasReviewed = false;
  bool _checkedReviewed = false;

  @override
  void initState() {
    super.initState();
    _precheck();
  }

  Future<void> _precheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _checkedReviewed = true;
      });
      return;
    }
    try {
      final exists = await _recipeService.hasUserReviewed(widget.recipe.id, user.uid);
      if (mounted) {
        setState(() {
          _hasReviewed = exists;
          _checkedReviewed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkedReviewed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateRating(double dx, double totalWidth) {
    double newRating = (dx / totalWidth) * 5;
    newRating = (newRating * 2).ceil() / 2;
    newRating = newRating.clamp(0.5, 5.0);

    if (newRating != _rating) {
      setState(() => _rating = newRating);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? selected = await _picker.pickImage(source: source);
    if (selected != null) {
      setState(() => _image = selected);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF3EB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF462F4D)),
              title: const Text('Gallery', style: TextStyle(fontFamily: 'Satoshi')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF462F4D)),
              title: const Text('Camera', style: TextStyle(fontFamily: 'Satoshi')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFFF3EB);
    const textColor = Color(0xFF462F4D);
    const orange = Color(0xFFEF8A54);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: Container(
        color: bgColor,
        child: Stack(
          children: [
              const PatternBackground(),
              Positioned(
                left: 30,
                top: 51,
                child: BackButtonWidget(color: textColor),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      const SizedBox(height: 20),
                      if (!_checkedReviewed)
                        const Center(child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: CircularProgressIndicator(),
                        )),
                      if (_checkedReviewed && _hasReviewed)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFE2D2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "You have already reviewed this recipe.",
                              style: TextStyle(color: textColor, fontFamily: "Satoshi"),
                            ),
                          ),
                        ),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                        builder: (context, snapshot) {
                          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                          final userName = userData['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? "User";
                          final userImageUrl = userData['photoUrl'] ?? FirebaseAuth.instance.currentUser?.photoURL ?? "";

                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: orange.withValues(alpha:0.1),
                                backgroundImage: (userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? NetworkImage(userImageUrl) : null,
                                child: (userImageUrl.trim().isEmpty || !userImageUrl.startsWith("http")) ? const Icon(Icons.person, color: orange) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontFamily: "Satoshi"),
                                    ),
                                    const Text(
                                      "Is posting a review",
                                      style: TextStyle(fontSize: 12, color: Colors.black38, fontFamily: "Satoshi"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Rate ${widget.recipe.name}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (_, constraints) {
                          return GestureDetector(
                            onTapDown: _isSubmitting || _hasReviewed ? null : (d) => _updateRating(d.localPosition.dx, constraints.maxWidth),
                            onPanUpdate: _isSubmitting || _hasReviewed ? null : (d) => _updateRating(d.localPosition.dx, constraints.maxWidth),
                            child: Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < _rating.floor()
                                      ? Icons.star
                                      : (i < _rating ? Icons.star_half : Icons.star_border),
                                  color: orange,
                                  size: 32,
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text("Your Review",
                          style: TextStyle(fontFamily: "Satoshi", fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        enabled: !_isSubmitting && !_hasReviewed,
                        decoration: InputDecoration(
                          hintText: _hasReviewed ? "You already reviewed this recipe" : "Share your experience...",
                          filled: true,
                          fillColor: const Color(0xFFF9E3D5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _isSubmitting || _hasReviewed ? null : _showImageSourceDialog,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9E3D5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: _image != null
                              ? Image.file(File(_image!.path), fit: BoxFit.cover)
                              : const Center(child: Icon(Icons.add_a_photo_outlined)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _isSubmitting || _hasReviewed ? () {} : _submitReview,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: _hasReviewed ? Colors.grey : orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: _isSubmitting
                                ? CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Submit Review",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSubmitting)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: orange),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_hasReviewed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already reviewed this recipe')),
        );
      }
      return;
    }

    final comment = _controller.text.trim();
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // Fetch user details from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['fullName'] ?? user.displayName ?? "User";
      final userImageUrl = userData['photoUrl'] ?? user.photoURL ?? "";

      String? imageUrl;

      if (_image != null) {
        final ref = FirebaseStorage.instance
            .ref('review_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(_image!.path));
        imageUrl = await ref.getDownloadURL();
      }

      await _recipeService.addReview({
        'recipeId': widget.recipe.id,
        'userId': user.uid,
        'userName': userName,
        'userImageUrl': userImageUrl,
        'comment': comment,
        'rating': _rating,
        'imageUrl': imageUrl,
      }, 
      initialAvg: widget.recipe.avgRating,
      initialCount: widget.recipe.reviewCount
      );

      if (mounted) {
        _hasReviewed = true;
        Toaster.show(context, 'Review posted successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("[PostReview] Error submitting review: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
