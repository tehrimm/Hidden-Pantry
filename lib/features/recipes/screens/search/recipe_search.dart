import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/features/recipes/widgets/recipe_card.dart';

class RecipeSearchScreen extends StatefulWidget {
  final String query;
  final List<String> ingredients;

  const RecipeSearchScreen({
    super.key,
    required this.query,
    this.ingredients = const [],
  });

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final RecipeApiService _api = const RecipeApiService(baseUrl: ApiConstants.baseUrl);
  
  List<Recipe> _results = [];
  bool _loading = true;
  String? _error;

  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _saveSearch(widget.query);
      final res = await _api.recommend(
        query: widget.query,
        ingredients: widget.ingredients,
        topK: 50, // Limit to 50 as requested
      );
      
      if (mounted) {
        // Apply sorting based on relevance, but don't filter out results if they don't match exactly.
        // This ensures backend results (semantic search) are preserved.
        final q = widget.query.toLowerCase().trim();
        final scored = <MapEntry<Recipe, double>>[];
        
        for (final r in res) {
          double score = 1.0; // Base score for being returned by backend
          
          if (q.isNotEmpty && q != "ingredient search") {
            if (r.name.toLowerCase().contains(q)) {
              score += 100;
              if (r.name.toLowerCase().startsWith(q)) score += 50;
            }
            if (r.ingredients.any((i) => i.name.toLowerCase().contains(q))) score += 40;
            if (r.tags.any((t) => t.toLowerCase().contains(q))) score += 20;
          }
          
          scored.add(MapEntry(r, score));
        }
        
        scored.sort((a, b) => b.value.compareTo(a.value));
        
        setState(() {
          // Filter: If it's a keyword search and score is 1.0, it means no keyword match was found.
          // The recommendation engine might return semantically related but "wrong" results for the user's intent.
          if (q.isNotEmpty && q != "ingredient search") {
            _results = scored.where((e) => e.value > 1.0).map((e) => e.key).toList();
          } else {
            _results = scored.map((e) => e.key).toList();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty || q == "ingredient search") return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('recent_searches') ?? [];
    
    history.remove(q);
    history.insert(0, q);
    
    if (history.length > 10) history = history.sublist(0, 10);
    
    await prefs.setStringList('recent_searches', history);
  }

  void _openRecipe(Recipe r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => MainNavigationShell()),
                  (route) => false,
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: purple),
            ),
          ),
        ),
        title: Text(
          widget.query == "ingredient search" ? "Search Results" : widget.query,
          style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
        ),
      ),
      body: _loading
          ? _buildProgress()
          : _error != null
              ? _buildError()
              : _buildGrid(),
    );
  }

  Widget _buildProgress() {
    return GridView.builder(
      padding: const EdgeInsets.all(22),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 22,
        childAspectRatio: 160 / 240,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _RecipeCardSkeleton(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Error: $_error", textAlign: TextAlign.center, style: TextStyle(color: purple)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchResults, child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          "No recipes found.\nTry removing some filters.",
          textAlign: TextAlign.center,
          style: TextStyle(color: purple, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(22),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 22,
        childAspectRatio: 157 / 231,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final r = _results[i];
        return RecipeCard(
          recipe: r,
          onTap: () => _openRecipe(r),
        );
      },
    );
  }
}

class _RecipeCardSkeleton extends StatelessWidget {
  const _RecipeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          child: SkeletonBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        SizedBox(height: 10),
        SkeletonBox(width: 120, height: 14, borderRadius: BorderRadius.all(Radius.circular(7))),
        SizedBox(height: 8),
        SkeletonBox(width: 80, height: 11, borderRadius: BorderRadius.all(Radius.circular(5))),
      ],
    );
  }
}
