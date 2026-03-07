import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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
  final Color bg = const Color(0xFFFFF3EB);
  final List<String> _units = [
    'tsp','tbsp','cup','ml','l','g','kg','pinch','dash','slice','piece'
  ];
  String? _unit;

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
    List<String> ranked = List<String>.from(_allItems);
    ranked.sort((a, b) {
      final la = a.toLowerCase();
      final lb = b.toLowerCase();
      
      final aExact = la == lowerQuery;
      final bExact = lb == lowerQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      final aStarts = la.startsWith(lowerQuery);
      final bStarts = lb.startsWith(lowerQuery);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      
      final aDist = _levenshtein(la, lowerQuery);
      final bDist = _levenshtein(lb, lowerQuery);
      if (aDist != bDist) return aDist.compareTo(bDist);
      
      final aContains = la.contains(lowerQuery);
      final bContains = lb.contains(lowerQuery);
      if (aContains && !bContains) return -1;
      if (!aContains && bContains) return 1;
      
      return la.compareTo(lb);
    });
    
    setState(() {
      _suggestions = ranked.take(10).toList();
    });
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) m[i][0] = i;
    for (var j = 0; j <= b.length; j++) m[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final del = m[i - 1][j] + 1;
        final ins = m[i][j - 1] + 1;
        final sub = m[i - 1][j - 1] + cost;
        m[i][j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
    }
    return m[a.length][b.length];
  }
  void _save() {
    final name = _searchController.text.trim();
    final quantity = _quantityController.text.trim();
    
    if (name.isEmpty) {
      Toaster.show(context, 'Please enter an ingredient name', isError: true);
      return;
    }
    
    String combined = '';
    if (quantity.isNotEmpty && _unit != null) {
      combined = '$quantity $_unit';
    } else if (quantity.isNotEmpty) {
      combined = quantity;
    }
    Navigator.pop(context, {
      'name': name,
      'quantity': combined,
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            const _BackgroundPatterns(),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 92 + safeBottom),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
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
                                color: const Color(0xFFF9E3D5),
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
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E3D5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 31),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              textAlign: TextAlign.center,
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
                          
                          if (_suggestions.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9E3D5),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9E3D5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: TextInputType.text,
                                textAlign: TextAlign.center,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(
                                width: 1,
                                height: 36,
                                color: purple.withValues(alpha: 0.15),
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _unit,
                                  hint: Center(
                                    child: Text(
                                      'Unit',
                                      style: TextStyle(
                                        color: purple.withValues(alpha: 0.5),
                                        fontSize: 15,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  ),
                                  icon: Icon(Icons.keyboard_arrow_down, color: purple),
                                  items: _units.map((u) {
                                    return DropdownMenuItem<String>(
                                      value: u,
                                      child: Center(
                                        child: Text(
                                          u,
                                          style: TextStyle(color: purple, fontSize: 15, fontFamily: 'Satoshi'),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (context) {
                                    return _units.map((u) {
                                      return Center(
                                        child: Text(
                                          u,
                                          style: TextStyle(color: purple, fontSize: 15, fontFamily: 'Satoshi'),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _unit = val);
                                    }
                                  },
                                  dropdownColor: const Color(0xFFF9E3D5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16 + safeBottom,
              child: SizedBox(
                height: 62,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: Color(0xFFFFF2EA),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Satoshi',
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



