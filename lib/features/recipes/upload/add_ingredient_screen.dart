import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddIngredientScreen extends StatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  
  List<String> _allItems = [];
  List<String> _suggestions = [];

  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFF2894F);
  final Color cardBg = const Color(0xFFF9E3D5);

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    try {
      final raw = await rootBundle.loadString('assets/data/ingredients_categorized.csv');
      final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      
      final items = <String>{};
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.isNotEmpty) {
          final ing = parts[0].trim();
          if (ing.isNotEmpty) items.add(ing);
        }
      }
      
      setState(() {
        _allItems = items.toList()..sort();
      });
    } catch (e) {
      setState(() {});
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    setState(() {
      _suggestions = _allItems
          .where((item) => item.toLowerCase().contains(lowerQuery))
          .take(5)
          .toList();
    });
  }

  void _save() {
    final name = _searchController.text.trim();
    final quantity = _quantityController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ingredient name')),
      );
      return;
    }
    
    Navigator.pop(context, {
      'name': name,
      'quantity': quantity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const _BackgroundPatterns(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                const SizedBox(height: 12),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF462F4D)),
                        ),
                      ),
                      const SizedBox(width: 40),
                      const Text(
                        'Add Ingredients',
                        style: TextStyle(
                          color: Color(0xFF462F4D),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _save,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: purple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100),

                // Search Ingredient
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 31),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(color: purple, fontSize: 15, fontFamily: 'Satoshi'),
                          decoration: InputDecoration(
                            hintText: 'Search Ingredient',
                            hintStyle: TextStyle(
                              color: purple.withValues(alpha: 0.5),
                              fontSize: 15,
                              fontFamily: 'Satoshi',
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      
                      // Suggestions list
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: _suggestions.map((s) => ListTile(
                              title: Text(s, style: TextStyle(color: purple, fontSize: 14, fontFamily: 'Satoshi')),
                              onTap: () {
                                setState(() {
                                  _searchController.text = s;
                                  _suggestions = [];
                                });
                              },
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // Quantity Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 31),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.text,
                      textAlign: TextAlign.left,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(color: purple, fontSize: 15, fontFamily: 'Satoshi'),
                      decoration: InputDecoration(
                        hintText: 'Enter Quantity',
                        hintStyle: TextStyle(
                          color: purple.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontFamily: 'Satoshi',
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _BackgroundPatterns extends StatelessWidget {
  const _BackgroundPatterns();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -154,
            top: -14,
            child: Transform.rotate(
              angle: 21 * math.pi / 180,
              child: Container(
                width: 271,
                height: 159,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: const BorderRadius.all(Radius.elliptical(136, 80)),
                ),
              ),
            ),
          ),
          Positioned(
            left: -149,
            top: -100,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: Container(
                width: 303,
                height: 329,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF5DDCE)),
                  borderRadius: const BorderRadius.all(Radius.elliptical(152, 165)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



