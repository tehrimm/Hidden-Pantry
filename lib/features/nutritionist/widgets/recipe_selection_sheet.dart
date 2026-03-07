import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeSelectionSheet extends StatelessWidget {
  final Function(Map<String, dynamic>) onRecipeSelected;

  const RecipeSelectionSheet({super.key, required this.onRecipeSelected});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color purple = const Color(0xFF462F4D);
    final Color orange = const Color(0xFFEF8A54);

    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "Select a Recipe to Share",
              style: TextStyle(
                color: purple,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: "Satoshi",
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("recipes")
                    .where("author_id", isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No recipes found. Upload some first!",
                        style: TextStyle(color: purple.withValues(alpha: 0.5)),
                      ),
                    );
                  }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final recipe = docs[index].data() as Map<String, dynamic>;
                    recipe['id'] = docs[index].id;
                    final title = recipe["name"] ?? recipe["title"] ?? "Untitled";
                    final imageUrl = recipe["recipeImageUrl"] ?? recipe["imageUrl"] ?? recipe["image_url"] ?? recipe["image"] ?? recipe["photoUrl"];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: orange.withValues(alpha: 0.1)),
                      ),
                      child: ListTile(
                        onTap: () => onRecipeSelected(recipe),
                        contentPadding: const EdgeInsets.all(8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _placeholder(orange),
                                )
                              : _placeholder(orange),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: purple,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Satoshi",
                          ),
                        ),
                        subtitle: Text(
                          "${recipe['minutes'] ?? 0} mins • ${recipe['difficulty'] ?? 'Easy'}",
                          style: TextStyle(
                            color: purple.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: purple.withValues(alpha: 0.3)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color orange) {
    return Container(
      width: 60,
      height: 60,
      color: orange.withValues(alpha: 0.1),
      child: Icon(Icons.restaurant_menu_rounded, color: orange),
    );
  }
}
