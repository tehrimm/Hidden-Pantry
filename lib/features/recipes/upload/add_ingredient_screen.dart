import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';


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
    'tsp', 'teaspoon', 'teaspoons', 'tbsp', 'tablespoon', 'tablespoons', 'cup', 'cups', 
    'ml', 'l', 'g', 'kg', 'pinch', 'dash', 'slice', 'piece', 'clove', 'stalk', 'sprig', 
    'oz', 'lb', 'pint', 'quart', 'gallon', 'large', 'medium', 'small', 'stick', 'head', 'bunch','as needed','to taste'
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
    } else if (_unit != null) {
      combined = _unit!;
    }

    Navigator.pop(context, {
      'name': name,
      'quantity': combined,
    });

  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30.sw),
        ),
        child: Stack(
          children: [
            PatternBackground(),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 92.sh + safeBottom),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.width >= 600 ? 24.sh : 35.sh),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.sw),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 50.sw,
                              height: 50.sw,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9E3D5),
                                borderRadius: BorderRadius.circular(25.sw),
                              ),
                              child: Icon(Icons.arrow_back_ios_new, size: 18.sw, color: const Color(0xFF462F4D)),
                            ),
                          ),
                          SizedBox(width: 40.sw),
                          Text(
                            'Add Ingredients',
                            style: TextStyle(
                              color: const Color(0xFF462F4D),
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24.sh),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Center(
                          child: SizedBox(
                            width: (350.sw) * value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            height: math.max(60.0, 70.sh),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E3D5),
                              borderRadius: BorderRadius.circular(20.sw),
                              boxShadow: [
                                BoxShadow(
                                  color: purple.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 20.sw),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              textAlign: TextAlign.left,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: purple, fontSize: 16.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Search Ingredient',
                                hintStyle: TextStyle(
                                  color: purple.withValues(alpha: 0.5),
                                  fontSize: 16.sp,
                                  fontFamily: 'Satoshi',
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                suffixIcon: Icon(Icons.search, color: purple, size: 22.sw),
                              ),
                            ),
                          ),
                          
                          if (_suggestions.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 4.sh),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9E3D5),
                                borderRadius: BorderRadius.circular(15.sw),
                              ),
                              child: Column(
                                children: _suggestions.map((s) => ListTile(
                                  title: Text(s, style: TextStyle(color: purple, fontSize: 14.sp, fontFamily: 'Satoshi')),
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
                    
                    SizedBox(height: 16.sh),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Center(
                          child: SizedBox(
                            width: (350.sw) * value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        height: math.max(60.0, 70.sh),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9E3D5),
                          borderRadius: BorderRadius.circular(20.sw),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20.sw),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: TextInputType.text,
                                textAlign: TextAlign.left,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(color: purple, fontSize: 16.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Quantity',
                                  hintStyle: TextStyle(
                                    color: purple.withValues(alpha: 0.5),
                                    fontSize: 16.sp,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.sw),
                              child: Container(
                                width: 1.sw,
                                height: 36.sh,
                                color: purple.withValues(alpha: 0.15),
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _unit,
                                  hint: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Unit',
                                      style: TextStyle(
                                        color: purple.withValues(alpha: 0.5),
                                        fontSize: 16.sp,
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(Icons.keyboard_arrow_down, color: purple),
                                  items: _units.map((u) {
                                    return DropdownMenuItem<String>(
                                      value: u,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          u,
                                          style: TextStyle(color: purple, fontSize: 16.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (context) {
                                    return _units.map((u) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          u,
                                          style: TextStyle(color: purple, fontSize: 16.sp, fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
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
              left: 20.sw,
              right: 20.sw,
              bottom: 16.sh + safeBottom,
              child: SizedBox(
                height: 62.sh,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Save",
                    style: TextStyle(
                      color: const Color(0xFFFFF2EA),
                      fontSize: 15.sp,
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
