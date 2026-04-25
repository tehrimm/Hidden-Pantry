import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/home_bottom_nav.dart';
import 'package:hidden_pantry_app/core/widgets/main_navigation_shell.dart';
import 'package:hidden_pantry_app/features/recipes/screens/search/search.dart';
import 'package:hidden_pantry_app/features/recipes/upload/upload_recipe_step1.dart';
import 'package:hidden_pantry_app/features/recipes/screens/saved_recipes.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_details.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';

class NutritionistDiscoveryScreen extends StatefulWidget {
  final bool inShell;
  const NutritionistDiscoveryScreen({super.key, this.inShell = false});

  @override
  State<NutritionistDiscoveryScreen> createState() => _NutritionistDiscoveryScreenState();
}

class _NutritionistDiscoveryScreenState extends State<NutritionistDiscoveryScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color searchBarBg = const Color(0xFFFDECE4);

  final TextEditingController _searchCtrl = TextEditingController();
  
  String _searchQuery = "";
  String _selectedDomain = "All";
  int _bottomIndex = 4; // Expert tab
  
  final List<String> _domains = [
    "⭐ Top Rated",
    "All",
    "Clinical Nutrition",
    "Sports Nutrition",
    "Pediatric Nutrition",
    "Weight Management",
    "Plant-Based",
    "Holistic",
    "Diabetes Educator",
    "General Wellness",
    "Keto",
  ];

  // Cache subscriptions
  Set<String> _subscribedIds = {};
  Set<String> _cancelledIds = {};
  bool _isLoadingSubs = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingSubs = false);
      return;
    }

    try {
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance
          .collection("subscriptions")
          .where("userId", isEqualTo: user.uid)
          .get();

      final Set<String> ids = {};
      final Set<String> cancelledIds = {};
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final status = data?["status"] as String?;
        final expiry = (data?["expiryDate"] as Timestamp?)?.toDate();
        final isCancelled = data?["isCancelled"] as bool? ?? false;

        if (expiry != null && expiry.isAfter(now)) {
          final nId = data?["nutritionistId"] as String?;
          if (nId != null) {
            ids.add(nId);
            if (isCancelled) cancelledIds.add(nId);
          }
        } else if (status == "active" && expiry == null) {
          final nId = data?["nutritionistId"] as String?;
          if (nId != null) {
            ids.add(nId);
            if (isCancelled) cancelledIds.add(nId);
          }
        }
      }
      if (mounted) {
        setState(() {
          _subscribedIds = ids;
          _cancelledIds = cancelledIds;
          _isLoadingSubs = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching subs: $e");
      if (mounted) setState(() => _isLoadingSubs = false);
    }
  }

  void _onBottomTap(int i) {
    if (i == _bottomIndex) return;

    setState(() => _bottomIndex = i);

    if (i == 0) {
       Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainNavigationShell()),
          (route) => false,
        );
    } else if (i == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ).then((_) {
        if (mounted) setState(() => _bottomIndex = 4);
      });
    } else if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      ).then((_) {
         if (mounted) setState(() => _bottomIndex = 4);
      });
    } else if (i == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
      ).then((_) {
        if (mounted) setState(() => _bottomIndex = 4);
      });
    } else if (i == 4) {
       // Check if user is trying to switch to "User Profile" view of dashboard, 
       // but here we are in Discovery mode.
       // The HomeScreen handles switching back to Nutritionist Dashboard if mode is nutritionist.
       // Here we just stay.
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    Widget content = Container(
      color: widget.inShell ? Colors.transparent : bg,
      child: Stack(
        children: [
          if (!widget.inShell) const PatternBackground(),
        
        // Force the Stack to be at least screen-sized to prevent RenderFlex overflow
        const SizedBox.expand(),
        
        // Salad Illustration (Bleeding from top of screen)
        _headerIllustration(),

        Positioned.fill(
          child: SafeArea(
            bottom: !widget.inShell, // Only pad bottom if NOT in shell (shell has its own nav)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _header(),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -28.sh,
                      child: _searchBar(),
                    ),
                  ],
                ),
                SizedBox(height: 38.sh),
                _domainFilters(),
                Expanded(
                  child: _isLoadingSubs 
                      ? const Center(child: CircularProgressIndicator())
                      : _contentList(),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

    if (widget.inShell) return content;

    return Scaffold(
      backgroundColor: widget.inShell ? Colors.transparent : bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: HpBottomNav(
        currentIndex: _bottomIndex,
        onTap: _onBottomTap,
        orange: orange,
        isNutritionistInUserView: false,
      ),
      body: content,
    );
  }

  Widget _contentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("nutritionists").snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState("No nutritionists found.");

        final bool isTopRated = _selectedDomain == "⭐ Top Rated";

        // Compute avgRating for every doc and inject it into the data map
        List<Map<String, dynamic>> enriched = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['_id'] = doc.id;
          final int count = (data['total_review_count'] as num?)?.toInt() ?? 0;
          final double sum = (data['total_rating_sum'] as num?)?.toDouble() ?? 0.0;
          data['avgRating'] = count > 0 ? sum / count : 0.0;
          data['_reviewCount'] = count;
          return data;
        }).toList();

        // Split subscribed vs others
        final subscribedList = <Map<String, dynamic>>[];
        final othersList = <Map<String, dynamic>>[];

        for (final data in enriched) {
          final id = data['_id'] as String;
          final saasStatus = data['saasStatus'] ?? 'unpaid';
          if (_subscribedIds.contains(id)) {
            subscribedList.add(data);
          } else if (saasStatus == 'active') {
            othersList.add(data);
          }
        }

        // Helper for matching
        bool matchesFilter(Map<String, dynamic> data) {
          final name = (data['fullName'] ?? '').toString().toLowerCase();
          final domain = (data['domain'] ?? '').toString().toLowerCase();
          final selected = _selectedDomain.toLowerCase();
          
          final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
          
          bool matchesDomain = false;
          if (_selectedDomain == 'All' || isTopRated) {
            matchesDomain = true;
          } else {
            // Flexible matching: "Sports" matches "Sports Nutrition"
            matchesDomain = domain.contains(selected) || selected.contains(domain);
          }
          
          return matchesSearch && matchesDomain;
        }

        // Apply filters to both lists
        var filteredSubscribed = subscribedList.where(matchesFilter).toList();
        var filteredOthers = othersList.where(matchesFilter).toList();

        // Sort by avgRating descending when Top Rated is selected
        if (isTopRated) {
          filteredOthers.sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));
          filteredSubscribed.sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));
        }

        return ListView(
          padding: const EdgeInsets.only(left: 22, right: 22, top: 10, bottom: 120),
          children: [
            if (filteredSubscribed.isNotEmpty) ...[
              Text(
                (_searchQuery.isEmpty && _selectedDomain == 'All') ? "Your Nutritionists" : "Followed Matches",
                style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
              const SizedBox(height: 12),
              ...filteredSubscribed.map((data) => _nutritionistCard(
                    data['_id'] as String,
                    data,
                    isSubscribed: true,
                    isCancelled: _cancelledIds.contains(data['_id']),
                  )),
              const SizedBox(height: 24),
              Divider(color: purple.withValues(alpha: 0.1)),
              const SizedBox(height: 24),
            ],

            if (filteredOthers.isNotEmpty) ...[
              Text(
                isTopRated ? "Top Rated Nutritionists" : "Available Nutritionists",
                style: TextStyle(color: purple, fontSize: 18.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
              const SizedBox(height: 12),
              ...filteredOthers.map((data) => _nutritionistCard(
                    data['_id'] as String,
                    data,
                    isSubscribed: false,
                    isCancelled: false,
                  )),
            ],

            if (filteredSubscribed.isEmpty && filteredOthers.isEmpty)
              _emptyState(_searchQuery.isEmpty ? "No experts found in this category." : "No results found for your search."),
          ],
        );
      },
    );
  }

  Widget _headerIllustration() {
    return Positioned(
      top: -45.sh,
      right: -35.sw,
      child: Opacity(
        opacity: 1.0,
        child: Container(
          width: 210.sw,
          height: 210.sw,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 25.clamp(0.0, 100.0).toDouble(),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(105.sw),
            child: Image.asset(
              'assets/illustration/salad.png',
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(
                color: Colors.white,
                child: Icon(Icons.restaurant_menu, color: orange.withValues(alpha:0.2), size: 60.sp),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      height: 220.sh,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40.sw),
          bottomRight: Radius.circular(40.sw),
        ),
      ),
      child: Stack(
        children: [
          // Decorative Blobs
          Positioned(
            top: -40.sh,
            right: -20.sw,
            child: Container(
              width: 180.sw,
              height: 180.sw,
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 60.sh,
            right: 40.sw,
            child: Container(
              width: 60.sw,
              height: 60.sw,
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Text Content
          Padding(
            padding: EdgeInsets.fromLTRB(25.sw, 40.sh, 140.sw, 20.sh),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.sw),
                  ),
                  child: Text(
                    "PREMIUM GUIDANCE",
                    style: TextStyle(
                      color: orange,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ),
                SizedBox(height: 12.sh),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: purple,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Satoshi",
                      height: 1.1,
                    ),
                    children: [
                      const TextSpan(text: "Explore\n"),
                      TextSpan(
                        text: "Nutritionists",
                        style: TextStyle(color: orange),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.sh),
                Text(
                  "Get personalized guidance for your health",
                  style: TextStyle(
                    color: purple.withValues(alpha: 0.6),
                    fontSize: 13.sp,
                    fontFamily: "Satoshi",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Container(
            height: 56.sh,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28.sw),
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: 0.08),
                  blurRadius: (15 * value).clamp(0.0, 100.0).toDouble(),
                  offset: Offset(0, 8 * value),
                ),
              ],
              border: Border.all(
                color: orange.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.sw),
            child: child,
          );
        },
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: orange, size: 24.sw),
            SizedBox(width: 12.sw),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  color: purple,
                  fontSize: 15.sp,
                  fontFamily: "Satoshi",
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Search your expert...",
                  hintStyle: TextStyle(
                    color: purple.withValues(alpha: 0.4),
                    fontSize: 15.sp,
                    fontFamily: "Satoshi",
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _searchCtrl.clear();
                  setState(() => _searchQuery = "");
                },
                child: CircleAvatar(
                  radius: 12.sw,
                  backgroundColor: orange.withValues(alpha: 0.1),
                  child: Icon(Icons.close, color: orange, size: 16.sw),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _domainFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(left: 22.sw, right: 22.sw, bottom: 24.sh, top: 12.sh),
      child: Row(
        children: _domains.map((domain) {
          final isSelected = _selectedDomain == domain;
          
          IconData icon;
          if (domain.contains("⭐")) {
            icon = Icons.auto_awesome_rounded;
          } else if (domain == "All") {
            icon = Icons.grid_view_rounded;
          } else if (domain.contains("Clinical")) {
            icon = Icons.health_and_safety_rounded;
          } else if (domain.contains("Sports")) {
            icon = Icons.fitness_center_rounded;
          } else if (domain.contains("Pediatric")) {
            icon = Icons.child_care_rounded;
          } else if (domain.contains("Weight")) {
            icon = Icons.monitor_weight_rounded;
          } else {
            icon = Icons.spa_rounded;
          }

          final cleanDomain = domain.replaceAll("⭐ ", "");

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDomain = domain);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(right: 12.sw),
              padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 10.sh),
              decoration: BoxDecoration(
                color: isSelected ? orange : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20.sw),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: orange.withValues(alpha: 0.3),
                    blurRadius: 10.0.clamp(0.0, 100.0).toDouble(),
                    offset: const Offset(0, 4),
                  )
                ] : [],
                border: Border.all(
                  color: isSelected ? Colors.transparent : orange.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon, 
                    color: isSelected ? Colors.white : orange, 
                    size: 16.sw,
                  ),
                  SizedBox(width: 8.sw),
                  Text(
                    cleanDomain,
                    style: TextStyle(
                      color: isSelected ? Colors.white : purple,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13.sp,
                      fontFamily: "Satoshi",
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nutritionistCard(String id, Map<String, dynamic> data, {required bool isSubscribed, required bool isCancelled}) {
    final String name = data["fullName"] ?? "Anonymous Nutritionist";
    final String? photo = data["photoUrl"];
    final String bio = data["bio"] ?? "Experienced nutritionist ready to help you reach your goals.";
    final String? domain = data["domain"];
    final double avgRating = (data['avgRating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (data['_reviewCount'] as int?) ?? 0;
    final bool isTop = avgRating >= 4.5 && reviewCount >= 3;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NutritionistDetailsScreen(nutritionistId: id, nutritionistData: data)),
      ).then((_) => _fetchSubscriptions()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSubscribed ? Border.all(color: isCancelled ? Colors.red : orange, width: 1.5) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70.sw,
              height: 70.sw,
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5),
                borderRadius: BorderRadius.circular(20.sw),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.sw),
                child: photo != null && photo.startsWith("http")
                    ? Image.network(photo, fit: BoxFit.cover)
                    : Image.asset("assets/logos/main_logo.png", fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                        ),
                      ),
                      if (isTop)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.star_rounded, color: Color(0xFFDAA520), size: 11),
                              SizedBox(width: 3),
                              Text("TOP", style: TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        )
                      else if (isSubscribed)
                        Icon(
                          isCancelled ? Icons.timer_outlined : Icons.star_rounded,
                          color: isCancelled ? Colors.red : orange,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (domain != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        domain.toUpperCase(),
                        style: TextStyle(color: orange, fontSize: 9, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                      ),
                    ),
                  Row(
                    children: [
                      if (avgRating > 0) ...[
                        Icon(Icons.star_rounded, color: Colors.amber[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "${avgRating.toStringAsFixed(1)} ($reviewCount)",
                          style: TextStyle(color: purple, fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (data["verificationStatus"] == "approved") ...[
                        Icon(Icons.verified_rounded, color: orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: TextStyle(color: orange, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.5),
                      fontSize: 13.sp,
                      fontFamily: "Satoshi",
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: purple.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 16, fontFamily: "Satoshi"),
            ),
          ],
        ),
      ),
    );
  }
}
