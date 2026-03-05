import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  final List<String> _domains = ["All", "Weight Loss", "Clinical", "Sports", "Pediatric", "General", "Keto", "Vegan"];

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
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          (route) => false,
        );
    } else if (i == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    } else if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadRecipeStep1()),
      ).then((_) {
         if (mounted) setState(() => _bottomIndex = 4);
      });
    } else if (i == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
      );
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
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: widget.inShell 
          ? null 
          : HpBottomNav(
              currentIndex: _bottomIndex,
              onTap: _onBottomTap,
              orange: orange,
              isNutritionistInUserView: false, // In discovery, we are a user viewing experts
            ),
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            const PatternBackground(),
            
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 12),
                  _header(),
                  _searchBar(),
                  _domainFilters(),
                  Expanded(
                     child: _isLoadingSubs 
                         ? const Center(child: CircularProgressIndicator())
                         : _contentList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

        // 1. Split into Subscribed and Others
        final subscribedList = <DocumentSnapshot>[];
        final othersList = <DocumentSnapshot>[];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final saasStatus = data?["saasStatus"] ?? "unpaid";
          
          if (_subscribedIds.contains(doc.id)) {
            subscribedList.add(doc);
          } else if (saasStatus == "active") {
            othersList.add(doc);
          }
        }

        // 2. Apply Filters ONLY to "Others"
        final filteredOthers = othersList.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final name = (data?["fullName"] ?? "").toString().toLowerCase();
          final domain = (data?["domain"] ?? "All").toString();

          final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
          final matchesDomain = _selectedDomain == "All" || domain == _selectedDomain;

          return matchesSearch && matchesDomain;
        }).toList();

        return ListView(
          padding: const EdgeInsets.only(left: 22, right: 22, top: 10, bottom: 120),
          children: [
            // Section: Subscribed (Visible if any exist)
            if (subscribedList.isNotEmpty && _searchQuery.isEmpty && _selectedDomain == "All") ...[
              Text(
                "Your Nutritionists",
                style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
              const SizedBox(height: 12),
              ...subscribedList.map((doc) => _nutritionistCard(
                doc.id, 
                doc.data() as Map<String, dynamic>, 
                isSubscribed: true,
                isCancelled: _cancelledIds.contains(doc.id),
              )),
              const SizedBox(height: 24),
              Divider(color: purple.withValues(alpha: 0.1)),
              const SizedBox(height: 24),
            ],

            // Section: Others
            Text(
              "Available Nutritionists",
              style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
            ),
            const SizedBox(height: 12),
            
            if (filteredOthers.isEmpty)
              _emptyState("No results found for your search.")
            else
              ...filteredOthers.map((doc) => _nutritionistCard(
                doc.id, 
                doc.data() as Map<String, dynamic>, 
                isSubscribed: false,
                isCancelled: false,
              )),
          ],
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Explore Nutritionists",
            style: TextStyle(color: purple, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
          ),
          Text(
            "Get personalized guidance for your health",
            style: TextStyle(color: purple.withValues(alpha: 0.6), fontSize: 14, fontFamily: "Satoshi"),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: searchBarBg,
          borderRadius: BorderRadius.circular(27),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Image.asset("assets/icons/Search.png", width: 20, height: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                 style: TextStyle(color: purple, fontSize: 16, fontFamily: "Satoshi"),
                decoration: InputDecoration(
                  hintText: "Search nutritionist...",
                  hintStyle: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 16, fontFamily: "Satoshi"),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = "");
                },
                child: Icon(Icons.close, color: purple, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _domainFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 22, right: 22, bottom: 16, top: 16),
      child: Row(
        children: _domains.map((domain) {
          final isSelected = _selectedDomain == domain;
          return GestureDetector(
            onTap: () => setState(() => _selectedDomain = domain),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? orange : const Color(0xFFF9E3D5), // Match Search screen chip style
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                domain,
                style: TextStyle(
                  color: isSelected ? Colors.white : purple,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: "Satoshi",
                ),
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NutritionistDetailsScreen(nutritionistId: id, nutritionistData: data)),
      ).then((_) => _fetchSubscriptions()), // Refresh on return in case they subscribed
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
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF9E3D5), // Match Search placeholder bg
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: photo != null && photo.startsWith("http")
                    ? Image.network(photo, fit: BoxFit.cover)
                    : Image.asset("assets/Logos/mainLogo.png", fit: BoxFit.cover),
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
                          style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                        ),
                      ),
                       if (isSubscribed) 
                        Icon(
                          isCancelled ? Icons.timer_outlined : Icons.star_rounded, 
                          color: isCancelled ? Colors.red : orange, 
                          size: 18
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (domain != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(domain.toUpperCase(), style: TextStyle(color: orange, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 13, fontFamily: "Satoshi"),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber[700], size: 16),
                      const SizedBox(width: 4),
                      Text("4.9", style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Icon(Icons.verified_rounded, color: orange, size: 16),
                      const SizedBox(width: 4),
                      Text("Verified", style: TextStyle(color: orange, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
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
