import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../../recipes/widgets/recipe_rating_widget.dart';
import '../../../core/widgets/skeletons.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onShareTap;
  final VoidCallback? onVisibilityTap;
  final bool? isPublic;
  final double? width;
  final double aspectRatio;
  final bool isNutritionist;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.onShareTap,
    this.onVisibilityTap,
    this.isPublic,
    this.width,
    this.aspectRatio = 161 / 231,
    this.isNutritionist = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color purple = Color(0xFF462F4D);
    const Color orange = Color(0xFFEF8A54);
    final imageUrl = recipe.imageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final bool showManagement = onShareTap != null || onVisibilityTap != null;

    // Unified Stack-based design for both nutritionist and default
    Widget content = Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            bottom: showManagement ? 70 : 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: const Color(0xFFF9E3D5),
                child: hasImage && imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const SkeletonBox(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: BorderRadius.all(Radius.circular(20)),
                              ),
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/Logos/recipe_placeholder.jpg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/Logos/recipe_placeholder.jpg',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          
          // Visibility Indicator (Top Right)
          if (onVisibilityTap != null && isPublic != null)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onVisibilityTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublic! ? Colors.green.withValues(alpha: 0.8) : Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPublic! ? "Public" : "Private",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // Recipe Name
          Positioned(
            left: 12,
            bottom: 28,
            right: 12,
            child: Text(
              recipe.name.isEmpty ? "Recipe" : recipe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: purple,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          
          // Time and Rating row
          Positioned(
            left: 11,
            bottom: 8,
            right: 12,
            child: Row(
              children: [
                Text(
                  "${recipe.minutes} min • ",
                  style: const TextStyle(
                    color: purple,
                    fontSize: 11,
                    fontFamily: 'Satoshi',
                  ),
                ),
                Expanded(
                  child: RecipeRatingWidget(
                    recipeId: recipe.id,
                    initialRating: recipe.avgRating,
                    style: const TextStyle(
                      color: purple,
                      fontSize: 11,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Share Button (Bottom Right)
          if (onShareTap != null)
            Positioned(
              bottom: 5,
              right: 5,
              child: IconButton(
                icon: const Icon(Icons.share_rounded, color: orange, size: 18),
                onPressed: onShareTap,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}
