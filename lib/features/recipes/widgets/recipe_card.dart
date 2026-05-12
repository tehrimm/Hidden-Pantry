import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../../recipes/widgets/recipe_rating_widget.dart';
import '../../../core/widgets/skeletons.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
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
    this.onEdit,
    this.onDelete,
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
    final imageUrl = recipe.imageUrl ?? "";
    final hasImage = imageUrl.trim().isNotEmpty;
    final bool showManagement = onShareTap != null || onVisibilityTap != null;

    Widget content = Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Positioned.fill(
              bottom: showManagement ? 70 : 66,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: const Color(0xFFF9E3D5),
                    child: hasImage
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : const SkeletonBox(
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                  ),
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/logos/recipe_placeholder.jpg',
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/logos/recipe_placeholder.jpg',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ),

            // Glassy Bottom Section
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: showManagement ? 70 : 66,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB).withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Options Menu (Top Right)
            if (onEdit != null || onDelete != null)
              Positioned(
                top: 5,
                right: 5,
                child: PopupMenuButton<String>(
                  color: const Color(0xFFFFF3EB),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, color: purple, size: 24),
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) onEdit!();
                    if (value == 'delete' && onDelete != null) onDelete!();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: purple),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: purple, fontFamily: 'Satoshi')),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'Satoshi')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Visibility Indicator (if menu not shown)
            if ((onEdit == null && onDelete == null) && onVisibilityTap != null && isPublic != null)
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
              bottom: 22,
              right: 12,
              height: 36,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  recipe.name.trim().isEmpty ? "Recipe" : recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: purple,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                    height: 1.1,
                  ),
                ),
              ),
            ),
            
            // Time and Rating row
            Positioned(
              left: 11,
              bottom: 6,
              right: 12,
              child: Row(
                children: [
                  if (recipe.minutes > 0)
                    Text(
                      "${recipe.minutes} min • ",
                      style: const TextStyle(
                        color: purple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
                        fontWeight: FontWeight.bold,
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
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

class RecipeCardSkeleton extends StatelessWidget {
  final double? width;
  final double aspectRatio;

  const RecipeCardSkeleton({
    super.key,
    this.width,
    this.aspectRatio = 161 / 231,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              bottom: 66,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(16),
                  glassy: true,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 66,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB).withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 100, height: 14, glassy: true),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            SkeletonBox(width: 40, height: 10, glassy: true),
                            SizedBox(width: 10),
                            SkeletonBox(width: 40, height: 10, glassy: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}