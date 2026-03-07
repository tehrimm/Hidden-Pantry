import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../../recipes/widgets/recipe_rating_widget.dart';
import '../../../core/widgets/skeletons.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final double? width;
  final double aspectRatio;
  final bool isNutritionist;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.width,
    this.aspectRatio = 161 / 231,
    this.isNutritionist = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color purple = Color(0xFF462F4D);
    final imageUrl = recipe.imageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

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
            bottom: 50,
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
                fontSize: 15, // Standardized font size
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
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
