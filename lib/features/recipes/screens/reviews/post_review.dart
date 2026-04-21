import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';

class PostReviewScreen extends StatefulWidget {
  final Recipe recipe;

  const PostReviewScreen({super.key, required this.recipe});

  @override
  State<PostReviewScreen> createState() => _PostReviewScreenState();
}

class _PostReviewScreenState extends State<PostReviewScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final RecipeService _recipeService = RecipeService();

  double _rating = 5.0;
  XFile? _image;
  bool _isSubmitting = false;
  bool _hasReviewed = false;
  bool _checkedReviewed = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _precheck();
  }

  Future<void> _precheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checkedReviewed = true);
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
      if (mounted) setState(() => _checkedReviewed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onRatingUpdate(double newRating) {
    if (_isSubmitting || _hasReviewed) return;
    setState(() => _rating = newRating);
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
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(24.sw),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EB).withValues(alpha: 0.8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40.sw, height: 4.sh, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 24.sh),
              _sourceTile(Icons.photo_library_rounded, "Gallery", () => _pickImage(ImageSource.gallery)),
              SizedBox(height: 12.sh),
              _sourceTile(Icons.camera_alt_rounded, "Camera", () => _pickImage(ImageSource.camera)),
              SizedBox(height: 24.sh),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16.sw),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15.sw),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF462F4D)),
            SizedBox(width: 16.sw),
            Text(label, style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    const textColor = Color(0xFF462F4D);
    const orange = Color(0xFFEF8A54);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const PatternBackground(),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vh = constraints.maxHeight;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: vh),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 12.sh),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 110.sh), 

                          if (!_checkedReviewed)
                            SizedBox(
                              height: vh * 0.7,
                              child: const Center(child: CircularProgressIndicator(color: orange)),
                            )
                          else ...[
                            // Header Section
                            _StaggeredSection(
                              delay: 100,
                              child: _buildHeader(textColor),
                            ),
                            
                            SizedBox(height: 40.sh), 

                            // Rating Section
                            _StaggeredSection(
                              delay: 200,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Rate ${widget.recipe.name}", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: textColor, fontFamily: "Satoshi")),
                                  SizedBox(height: 10.sh),
                                  _AnimatedRatingStars(
                                    rating: _rating,
                                    onRatingUpdate: _onRatingUpdate,
                                    enabled: !_isSubmitting && !_hasReviewed,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 30.sh),

                            // Review Text Section
                            _StaggeredSection(
                              delay: 300,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Your Review", style: TextStyle(fontFamily: "Satoshi", fontWeight: FontWeight.w900, fontSize: 15.sp, color: textColor)),
                                  SizedBox(height: 10.sh),
                                  _GlassyTextField(
                                    controller: _controller,
                                    enabled: !_isSubmitting && !_hasReviewed,
                                    hint: _hasReviewed ? "Already reviewed!" : "Tell us about your experience...",
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 30.sh),

                            // Photo Section
                            _StaggeredSection(
                              delay: 400,
                              child: _PolaroidPicker(
                                image: _image,
                                onTap: _isSubmitting || _hasReviewed ? null : _showImageSourceDialog,
                              ),
                            ),

                            SizedBox(height: 40.sh),

                            // Submit Button
                            _StaggeredSection(
                              delay: 500,
                              child: _AnimatedSubmitButton(
                                isSubmitting: _isSubmitting,
                                isSuccess: _showSuccess,
                                enabled: !_hasReviewed,
                                width: constraints.maxWidth - 44.sw,
                                onTap: _submitReview,
                              ),
                            ),
                            
                            SizedBox(height: 20.sh),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Standard Back Button on top
          Positioned(
            left: 30.sw,
            top: 51.sh,
            child: const BackButtonWidget(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final userName = userData['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? "User";
        final userImageUrl = userData['photoUrl'] ?? FirebaseAuth.instance.currentUser?.photoURL ?? "";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                children: [
                  Container(
                    width: 48.sw,
                    height: 48.sw,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)],
                    ),
                    child: ClipOval(
                      child: (userImageUrl.startsWith("http")) 
                        ? Image.network(userImageUrl, fit: BoxFit.cover) 
                        : Icon(Icons.person, color: const Color(0xFFEF8A54)),
                    ),
                  ),
                  SizedBox(width: 16.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontFamily: "Satoshi", fontSize: 18.sp)),
                        Text("Cooking Master", style: TextStyle(fontSize: 12.sp, color: Colors.black45, fontFamily: "Satoshi", letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasReviewed)
                Container(
                  margin: EdgeInsets.only(top: 20.sh),
                  padding: EdgeInsets.all(12.sw),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      SizedBox(width: 8.sw),
                      Text("You've shared your thoughts on this!", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hasReviewed) return;

    final comment = _controller.text.trim();
    setState(() => _isSubmitting = true);

    try {
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
        setState(() {
          _isSubmitting = false;
          _showSuccess = true;
          _hasReviewed = true;
        });
        Toaster.show(context, 'Review posted! Enjoy the meal!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Toaster.show(context, 'Oops! Something went wrong.', isError: true);
      }
    }
  }
}

class _AnimatedRatingStars extends StatelessWidget {
  final double rating;
  final Function(double) onRatingUpdate;
  final bool enabled;

  const _AnimatedRatingStars({required this.rating, required this.onRatingUpdate, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onTapDown: !enabled ? null : (d) => _calcRating(d.localPosition.dx, constraints.maxWidth),
        onPanUpdate: !enabled ? null : (d) => _calcRating(d.localPosition.dx, constraints.maxWidth),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final active = i < rating.floor();
            final half = i < rating && i >= rating.floor();
            
            return _StarItem(
              isActive: active,
              isHalf: half,
              index: i,
            );
          }),
        ),
      );
    });
  }

  void _calcRating(double dx, double max) {
    double r = (dx / max) * 5;
    r = (r * 2).ceil() / 2;
    onRatingUpdate(r.clamp(0.5, 5.0));
  }
}

class _StarItem extends StatefulWidget {
  final bool isActive;
  final bool isHalf;
  final int index;

  const _StarItem({required this.isActive, required this.isHalf, required this.index});

  @override
  State<_StarItem> createState() => _StarItemState();
}

class _StarItemState extends State<_StarItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_StarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isActive && !oldWidget.isActive) || (widget.isHalf && !oldWidget.isHalf)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        widget.isActive ? Icons.star_rounded : (widget.isHalf ? Icons.star_half_rounded : Icons.star_outline_rounded),
        color: const Color(0xFFEF8A54),
        size: 42.sw,
      ),
    );
  }
}

class _GlassyTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hint;

  const _GlassyTextField({required this.controller, required this.enabled, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        enabled: enabled,
        style: TextStyle(fontSize: 15.sp, color: const Color(0xFF462F4D), fontWeight: FontWeight.w600, fontFamily: "Satoshi"),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14.sp, color: Colors.blueGrey.withValues(alpha: 0.4)),
          contentPadding: EdgeInsets.all(20.sw),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _PolaroidPicker extends StatelessWidget {
  final XFile? image;
  final VoidCallback? onTap;

  const _PolaroidPicker({required this.image, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 500),
          turns: image != null ? -0.01 : 0.0,
          child: Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.sw),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 200.sw,
                  height: 130.sh,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB),
                    borderRadius: BorderRadius.circular(4.sw),
                  ),
                  child: image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4.sw),
                          child: Image.file(File(image!.path), fit: BoxFit.cover),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40.sw, color: const Color(0xFFEF8A54).withValues(alpha: 0.5)),
                              SizedBox(height: 8.sh),
                              Text("Add a photo", style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                ),
                SizedBox(height: 12.sh),
                Container(width: 60.sw, height: 4.sh, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool isSuccess;
  final bool enabled;
  final double width;
  final VoidCallback onTap;

  const _AnimatedSubmitButton({required this.isSubmitting, required this.isSuccess, required this.enabled, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: !enabled || isSubmitting || isSuccess ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutBack,
        width: isSubmitting || isSuccess ? 60.sw : width,
        height: 60.sh,
        decoration: BoxDecoration(
          color: isSuccess ? Colors.green : (enabled ? const Color(0xFFEF8A54) : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(isSubmitting || isSuccess ? 30.sw : 20.sw),
          boxShadow: [
            BoxShadow(
              color: isSubmitting || isSuccess ? Colors.transparent : const Color(0xFFEF8A54).withValues(alpha: 0.3),
              blurRadius: 20, 
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: isSubmitting
              ? SizedBox(width: 24.sw, height: 24.sw, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : (isSuccess
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                  : Text(
                      enabled ? "Share Review" : "Review Locked",
                      style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                    )),
        ),
      ),
    );
  }
}

class _StaggeredSection extends StatefulWidget {
  final Widget child;
  final int delay;

  const _StaggeredSection({required this.child, required this.delay});

  @override
  State<_StaggeredSection> createState() => _StaggeredSectionState();
}

class _StaggeredSectionState extends State<_StaggeredSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        transform: Matrix4.translationValues(0, _visible ? 0 : 20.sh, 0),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
