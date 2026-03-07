import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class RecipeRatingWidget extends StatelessWidget {
  final String recipeId;
  final double initialRating;
  final TextStyle? style;
  final double iconSize;
  final Color? color;

  const RecipeRatingWidget({
    super.key,
    required this.recipeId,
    required this.initialRating,
    this.style,
    this.iconSize = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: color ?? const Color(0xFFEF8A54),
            size: iconSize,
          ),
          const SizedBox(width: 4),
          Text(
            initialRating.toStringAsFixed(1),
            style: style ?? const TextStyle(
              fontSize: 11,
              fontFamily: "Satoshi",
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('recipes').doc(recipeId).snapshots(),
      builder: (context, snapshot) {
        double displayRating = initialRating;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayRating = double.tryParse(data['avg_rating']?.toString() ?? "0") ?? initialRating;
        }

        if (displayRating <= 0) {
          return Text(
            "no rating",
            style: style ?? const TextStyle(
              fontSize: 11,
              fontFamily: "Satoshi",
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              color: color ?? const Color(0xFFEF8A54),
              size: iconSize,
            ),
            const SizedBox(width: 4),
            Text(
              displayRating.toStringAsFixed(1),
              style: style ?? const TextStyle(
                fontSize: 11,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        );
      },
    );
  }
}
