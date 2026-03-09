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
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


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
    ResponsiveUtils.init(context);
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
                left: 30.sw,
                top: 51.sh,
                child: BackButtonWidget(color: textColor),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 12.sh),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 60.sh),
                      SizedBox(height: 20.sh),
                      if (!_checkedReviewed)
                        Center(child: Padding(
                          padding: EdgeInsets.only(top: 40.sh),
                          child: const CircularProgressIndicator(),
                        )),
                      if (_checkedReviewed && _hasReviewed)
                        Padding(
                          padding: EdgeInsets.only(top: 20.sh, bottom: 12.sh),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.sw),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE2D2),
                              borderRadius: BorderRadius.circular(12.sw),
                            ),
                            child: Text(
                              "You have already reviewed this recipe.",
                              style: TextStyle(color: textColor, fontFamily: "Satoshi", fontSize: 14.sp),
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
                                radius: 20.sw,
                                backgroundColor: orange.withValues(alpha:0.1),
                                backgroundImage: (userImageUrl.trim().isNotEmpty && userImageUrl.startsWith("http")) ? NetworkImage(userImageUrl) : null,
                                child: (userImageUrl.trim().isEmpty || !userImageUrl.startsWith("http")) ? Icon(Icons.person, color: orange, size: 24.sp) : null,
                              ),
                              SizedBox(width: 12.sw),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontFamily: "Satoshi", fontSize: 14.sp),
                                    ),
                                    Text(
                                      "Is posting a review",
                                      style: TextStyle(fontSize: 12.sp, color: Colors.black38, fontFamily: "Satoshi"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 30.sh),
                      Text(
                        "Rate ${widget.recipe.name}",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 12.sh),
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
                                  size: 32.sp,
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24.sh),
                      Text("Your Review",
                          style: TextStyle(fontFamily: "Satoshi", fontWeight: FontWeight.bold, fontSize: 16.sp)),
                      SizedBox(height: 12.sh),
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        enabled: !_isSubmitting && !_hasReviewed,
                        style: TextStyle(fontSize: 14.sp),
                        decoration: InputDecoration(
                          hintText: _hasReviewed ? "You already reviewed this recipe" : "Share your experience...",
                          hintStyle: TextStyle(fontSize: 14.sp),
                          filled: true,
                          fillColor: const Color(0xFFF9E3D5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.sw),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.sh),
                      GestureDetector(
                        onTap: _isSubmitting || _hasReviewed ? null : _showImageSourceDialog,
                        child: Container(
                          height: 180.sh,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9E3D5),
                            borderRadius: BorderRadius.circular(15.sw),
                          ),
                          child: _image != null
                              ? Image.file(File(_image!.path), fit: BoxFit.cover)
                              : Center(child: Icon(Icons.add_a_photo_outlined, size: 30.sp)),
                        ),
                      ),
                      SizedBox(height: 32.sh),
                      GestureDetector(
                        onTap: _isSubmitting || _hasReviewed ? () {} : _submitReview,
                        child: Container(
                          height: 60.sh,
                          decoration: BoxDecoration(
                            color: _hasReviewed ? Colors.grey : orange,
                            borderRadius: BorderRadius.circular(20.sw),
                          ),
                          child: Center(
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    "Submit Review",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.sp,
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
