import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';

import 'dart:ui'; // For ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/features/user/screens/tier_comparison_screen.dart'; // NEW
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:flutter/services.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'chat_interface_part.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class NutritionistDetailsScreen extends StatefulWidget {
  final String nutritionistId;
  final Map<String, dynamic> nutritionistData;

  const NutritionistDetailsScreen({
    super.key,
    required this.nutritionistId,
    required this.nutritionistData,
  });

  @override
  State<NutritionistDetailsScreen> createState() => _NutritionistDetailsScreenState();
}

class _NutritionistDetailsScreenState extends State<NutritionistDetailsScreen> with SingleTickerProviderStateMixin {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color cardBg = const Color(0xFFF9E3D5);
  final Color cardInner = const Color(0xFFFFF2EA);

  bool _isSubscribed = false;
  int _currentTier = 0; // 0: Free, 1: Silver, 2: Gold
  String? _subscriptionDocId;
  DateTime? _expiryDate;
  bool _isLoadingSubscription = true; // Prevents UI flicker
  bool _isMeNutritionist = false;
  bool _hasInitialCheck = false;
  bool _hasPrioritySupport = false; 
  
  int _subscriberCount = 0;
  int _postCount = 0;
  
  StreamSubscription<QuerySnapshot>? _subListener;
  late TabController _tabController;

  late Future<Map<String, int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkSubscription();
    _checkUserRole();
    _countsFuture = _fetchCountsDetailed(); // Initialize once
  }

  Future<void> _checkUserRole() async {
    final isNutr = await ViewModeService().isNutritionist();
    if (mounted) setState(() => _isMeNutritionist = isNutr);
  }
  
  @override
  void dispose() {
    _subListener?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkSubscription() async {
    _subListener?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
          if (!_hasInitialCheck) {
            _hasInitialCheck = true;
            _tabController.animateTo(2); // Go to Plans for guests
          }
        });
      }
      return;
    }

    _subListener = FirebaseFirestore.instance
        .collection("subscriptions")
        .where("userId", isEqualTo: user.uid)
        .where("nutritionistId", isEqualTo: widget.nutritionistId)
        .snapshots()
        .listen((query) async {
      if (query.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isSubscribed = false;
            _currentTier = 0;
            _isLoadingSubscription = false;
            if (!_hasInitialCheck) {
              _hasInitialCheck = true;
              if (!_isMeNutritionist) _tabController.animateTo(2); // Go to Plans for non-subscribers
            }
          });
        }
        return;
      }

      final now = DateTime.now();
      int highestTier = 0;
      QueryDocumentSnapshot? bestDoc;
      DateTime? bestExpiry;
      bool prioritySupportFound = false;

      for (var doc in query.docs) {
        final data = doc.data();
        final status = data["status"] as String?;
        final expiry = (data["expiryDate"] as Timestamp?)?.toDate();
        

        // FIX: Tighten active check (status must be active/trialing AND not expired)
        bool isActive = ((status == "active") || (status == "trialing")) && (expiry == null || expiry.isAfter(now));

          if (isActive) {
            int currentDocTier = 0;
            dynamic rawTier = data["tierLevel"];
            if (rawTier is num) {
              currentDocTier = rawTier.toInt();
            } else if (rawTier is String) {
              currentDocTier = int.tryParse(rawTier) ?? 0;
            }

            // Fetch plan details to check for Priority Support benefit
            if (data["planId"] != null) {
              try {
                var planDoc = await FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(widget.nutritionistId)
                    .collection("subscription_plans")
                    .doc(data["planId"])
                    .get();
                    
                // Fallback for older subscriptions that saved the title instead of the ID
                if (!planDoc.exists) {
                  final querySnap = await FirebaseFirestore.instance
                      .collection("nutritionists")
                      .doc(widget.nutritionistId)
                      .collection("subscription_plans")
                      .where("title", isEqualTo: data["planId"])
                      .limit(1)
                      .get();
                  if (querySnap.docs.isNotEmpty) {
                    // Force cast to DocumentSnapshot (QueryDocumentSnapshot implements it)
                    planDoc = querySnap.docs.first;
                  }
                }

                if (planDoc.exists) {
                  final pData = planDoc.data();
                  if (pData != null) {
                    // Check for Priority Support in benefits
                    final List? benefits = pData["benefits"];
                    if (benefits != null) {
                      final hasChat = benefits.any((b) {
                        final String title = (b is Map ? (b["title"] ?? b["text"] ?? "") : b).toString().toLowerCase();
                        return title.contains("priority support") || title.contains("chat access") || title.contains("direct chat");
                      });
                      if (hasChat) prioritySupportFound = true;
                    }

                    dynamic pTier = pData["tierLevel"];
                    if (pTier is num) {
                      currentDocTier = pTier.toInt();
                    } else if (pTier == null) {
                      final title = (pData["title"] ?? "").toString().toLowerCase();
                      if (title.contains("platinum")) {
                        currentDocTier = 3;
                      } else if (title.contains("gold")) {
                        currentDocTier = 2;
                      } else {
                        currentDocTier = 1;
                      }
                    }
                  }
                }
              } catch (_) {}
            }

            if (currentDocTier == 0) currentDocTier = 1;

            if (currentDocTier > highestTier) {
              highestTier = currentDocTier;
              bestDoc = doc;
              bestExpiry = expiry;
            }
          }
      }

      if (mounted) {
        bool wasInitialCheck = !_hasInitialCheck;

        if (bestDoc != null) {
          setState(() {
            _isSubscribed = true;
            _currentTier = highestTier;
            _subscriptionDocId = bestDoc!.id;
            _expiryDate = bestExpiry;
            _hasPrioritySupport = prioritySupportFound;
            _isLoadingSubscription = false;
            _hasInitialCheck = true;
          });
        } else {
          setState(() {
            _isSubscribed = false;
            _currentTier = 0;
            _hasPrioritySupport = false;
            _isLoadingSubscription = false;
            _hasInitialCheck = true;
          });
        }
        
        if (wasInitialCheck && !_isSubscribed && !_isMeNutritionist) {
           _tabController.animateTo(2); // Go to Plans for non-subscribers
        }
        
        // Refresh counts specifically if subscription state changes
        setState(() {
          _countsFuture = _fetchCountsDetailed();
        });
      }
    });
  }

  Future<Map<String, int>> _fetchCountsDetailed() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getNutritionistStats');
      final result = await callable.call<Map<dynamic, dynamic>>({'nutritionistId': widget.nutritionistId});
      
      final data = Map<String, dynamic>.from(result.data);
      final int totalPosts = data['posts'] as int? ?? 0;
      final int totalSubs = data['subs'] as int? ?? 0;

      if (mounted) {
         setState(() {
           _postCount = totalPosts;
           _subscriberCount = totalSubs;
         });
      }

      return {
        "posts": totalPosts,
        "subs": totalSubs,
      };
    } catch (e) {
      print("Error calling getNutritionistStats: $e");
      return {"posts": 0, "subs": 0}; // Fallback
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("nutritionists").doc(widget.nutritionistId).snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic> nutritionistData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.nutritionistData;

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              const PatternBackground(),
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 50),
                          _customAppBar(nutritionistData["fullName"] ?? "Expert Profile"),
                          _profileHeader(nutritionistData),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                            child: Text(
                              nutritionistData["bio"] ?? "Dedicated health professional.",
                              style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14, height: 1.5),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: orange,
                          unselectedLabelColor: purple.withValues(alpha:0.4),
                          indicatorColor: orange,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: "Satoshi"),
                          tabs: const [
                            Tab(text: "Feed"),
                            Tab(text: "Reviews"),
                            Tab(text: "Recipes"),
                            Tab(text: "Plans"),
                          ],
                        ),
                        backgroundColor: bg,
                      ),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _feedTab(),
                    _reviewsTab(),
                    _placeholderTab("Recipes coming soon!", icon: Icons.restaurant_menu_rounded),
                    _plansTab(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: (!_isLoadingSubscription && _isSubscribed && _hasPrioritySupport)
              ? FloatingActionButton(
                  onPressed: _openChat,
                  backgroundColor: orange,
                  elevation: 4,
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
                )
              : null,
        );
      },
    );
  }

  Widget _customAppBar(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BackButtonWidget(color: const Color(0xFF433020)),
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF462F4D),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: "Satoshi",
              ),
            ),
          ),
          if (_isSubscribed)
            IconButton(
              onPressed: _showRatingDialog,
              icon: const Icon(Icons.star_rounded, color: Color(0xFFDAA520)),
              tooltip: 'Rate Nutritionist',
            )
          else
            const SizedBox(width: 40), // Balance back button
        ],
      ),
    );
  }
  Widget _feedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(widget.nutritionistId)
          .collection("tips")
          .orderBy("timestamp", descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _placeholderTab("No updates yet.");

        return ListView.builder(
          padding: const EdgeInsets.all(22),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data["id"] = doc.id; // Correctly pass document ID
            return _tipCard(data);
          },
        );
      },
    );
  }

  Widget _reviewsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: NutritionistService().getReviews(widget.nutritionistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _placeholderTab("No reviews yet. Be the first!", icon: Icons.rate_review_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final double rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
            final String name = d['userName'] ?? 'User';
            final String text = d['reviewText'] ?? '';
            final Timestamp? ts = d['timestamp'] as Timestamp?;
            final String time = ts != null ? _timeAgo(ts.toDate()) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: cardInner, child: Icon(Icons.person, size: 16, color: orange)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      // Stars
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFDAA520),
                          size: 14,
                        )),
                      ),
                    ],
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(text, style: TextStyle(color: purple.withValues(alpha: 0.75), fontSize: 13, height: 1.5)),
                  ],
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(time, style: TextStyle(color: purple.withValues(alpha: 0.35), fontSize: 11)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _tipCard(Map<String, dynamic> data) {

    // 0=Free, 1=Silver, 2=Gold
    final int minTier = data["minTier"] ?? 0;
    final String type = data["type"] ?? "tip";
    
    if (_isLoadingSubscription) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 150,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: SizedBox(
            width: 24, height: 24, 
            child: CircularProgressIndicator(strokeWidth: 2, color: purple.withValues(alpha:0.2))
          ),
        ),
      );
    }

    final bool isLocked = _currentTier < minTier;
    final String content = data["content"] ?? "";
    final Timestamp? ts = data["timestamp"];
    final String tipId = data["id"] ?? "";
    final List<String> likedBy = List<String>.from(data["likedBy"] ?? []);
    final int likesCount = (data["likes"] ?? 0) as int;
    final int comments = (data["commentCount"] ?? 0) as int;
    final String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool hasLiked = likedBy.contains(currentUserUid);
    
    // Formatting timestamp
    String timeAgo = ts != null ? _timeAgo(ts.toDate()) : "Just now";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                     radius: 18, 
                     backgroundColor: cardInner,
                     backgroundImage: widget.nutritionistData["photoUrl"] != null && widget.nutritionistData["photoUrl"].toString().startsWith("http")
                        ? NetworkImage(widget.nutritionistData["photoUrl"]) 
                        : null,
                     child: (widget.nutritionistData["photoUrl"] == null) ? Icon(Icons.person, color: orange, size: 18) : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nutritionistData["fullName"] ?? "Nutritionist",
                      style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: "Satoshi"),
                    ),
                    Text(
                      timeAgo, 
                      style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                if (_isSubscribed && _expiryDate != null && minTier > 0 && !isLocked)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 10, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          "Active until ${_expiryDate!.day}/${_expiryDate!.month}",
                          style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (minTier > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLocked 
                          ? Colors.grey[200] 
                          : (minTier == 3 
                              ? const Color(0xFF4B0082) 
                              : minTier == 2 
                                ? const Color(0xFFDAA520) 
                                : const Color(0xFF708090)).withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.lock_rounded : (minTier == 3 ? Icons.diamond_rounded : (minTier == 2 ? Icons.star_rounded : Icons.star_half_rounded)), 
                          size: 12, 
                          color: isLocked ? Colors.grey : (minTier == 3 ? const Color(0xFF4B0082) : (minTier == 2 ? const Color(0xFFDAA520) : const Color(0xFF708090)))
                        ),
                        const SizedBox(width: 4),
                        Text(
                          minTier == 3 ? "PLATINUM" : minTier == 2 ? "GOLD" : "SILVER",
                          style: TextStyle(
                            color: isLocked ? Colors.grey : (minTier == 3 ? const Color(0xFF4B0082) : (minTier == 2 ? const Color(0xFFDAA520) : const Color(0xFF708090))),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 14),

          // ── Content ──
          if (isLocked)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Blurred Content
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data["imageUrl"] != null) ...[
                            Container(height: 150, decoration: BoxDecoration(color: purple.withValues(alpha:0.1), borderRadius: BorderRadius.circular(16))),
                            const SizedBox(height: 12),
                          ],
                          if (type == "meal_plan" || data["mealPlanId"] != null) ...[
                             _mealPlanPlaceholder(),
                             const SizedBox(height: 12),
                          ],
                          if (data["docUrl"] != null) ...[
                             Container(height: 50, decoration: BoxDecoration(color: purple.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12))),
                             const SizedBox(height: 12),
                          ],
                          Text(
                            content.isNotEmpty ? content : "This content is exclusive to ${minTier == 3 ? 'Platinum' : minTier == 2 ? 'Gold' : 'Silver'} subscribers. Upgrade your plan to unlock.",
                            style: TextStyle(color: const Color(0xFF433020).withValues(alpha:0.35), fontSize: 15, height: 1.6, fontFamily: "Satoshi"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Subtle Overlay & Lock
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          purple.withValues(alpha:0.05),
                          purple.withValues(alpha:0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: purple.withValues(alpha:0.1), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(Icons.lock_rounded, color: purple, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Exclusive ${minTier == 3 ? 'PLATINUM' : minTier == 2 ? 'GOLD' : 'SILVER'} ${type == 'meal_plan' || data['mealPlanId'] != null ? 'Meal Plan' : (data['recipeId'] != null) ? 'Recipe' : 'Update'}",
                          style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: "Satoshi")
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _navigateToTiers(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: orange.withValues(alpha:0.4),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Unlock Now", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        content,
                        style: TextStyle(color: purple.withValues(alpha:0.85), fontSize: 15, height: 1.6),
                      ),
                    ),
                  
                  // New Image Attachment
                  if (data["imageUrl"] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          data["imageUrl"],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(height: 200, color: purple.withValues(alpha:0.05), child: const Center(child: CircularProgressIndicator())),
                        ),
                      ),
                    ),

                  // Meal Plan
                  if (type == "meal_plan" || data["mealPlanId"] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _mealPlanInteractionCard(data["mealPlanId"], content),
                    ),

                  // Shared Recipe
                  if (data["recipeId"] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _recipeInteractionCard(data["recipeId"], data["recipeName"], data["recipeImageUrl"] ?? data["imageUrl"]),
                    ),

                  // Document Attachment
                  if (data["docUrl"] != null)
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse(data["docUrl"]);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha:0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: purple.withValues(alpha:0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file_rounded, color: orange, size: 24),
                            const SizedBox(width: 12),
                            Expanded(child: Text("Attached Document", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13))),
                            Icon(Icons.open_in_new_rounded, color: purple.withValues(alpha:0.4), size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Divider
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: purple.withValues(alpha:0.06)),

            // Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _actionButton(
                    icon: hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: likesCount > 0 ? "$likesCount" : "Like",
                    color: hasLiked ? Colors.red : purple.withValues(alpha:0.5),
                    onTap: () async {
                      if (tipId.isEmpty || widget.nutritionistId.isEmpty || _isMeNutritionist) return;
                      
                      final tipRef = FirebaseFirestore.instance
                          .collection("nutritionists")
                          .doc(widget.nutritionistId)
                          .collection("tips")
                          .doc(tipId);

                      try {
                        if (hasLiked) {
                          await tipRef.update({
                            "likedBy": FieldValue.arrayRemove([currentUserUid]),
                            "likes": FieldValue.increment(-1),
                          });
                        } else {
                          await tipRef.update({
                            "likedBy": FieldValue.arrayUnion([currentUserUid]),
                            "likes": FieldValue.increment(1),
                          });
                          
                          // Send Notification to nutritionist
                          if (widget.nutritionistId != currentUserUid) {
                            NotificationService().sendNotification(
                              recipientId: widget.nutritionistId,
                              recipientRole: 'nutritionist',
                              title: "New Like",
                              body: "${FirebaseAuth.instance.currentUser?.displayName ?? 'Someone'} liked your post.",
                              type: NotificationType.like,
                              targetId: tipId,
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Toaster.show(context, "Action failed: $e", isError: true);
                        }
                      }
                    },
                  ),
                  _actionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: comments > 0 ? "$comments" : "Comment",
                    color: purple.withValues(alpha:0.5),
                    onTap: () {
                      if (tipId.isNotEmpty) {
                        _showComments(tipId);
                      }
                    },
                  ),
                  _actionButton(
                    icon: Icons.share_outlined,
                    label: "Share",
                    color: purple.withValues(alpha:0.5),
                    onTap: () {
                       final String shareText = type == "meal_plan" || data["mealPlanId"] != null
                        ? "Check out this Meal Plan from ${widget.nutritionistData['fullName']}: $content"
                        : data["recipeId"] != null
                            ? "Check out this Recipe from ${widget.nutritionistData['fullName']}: ${data['recipeName'] ?? 'Shared Recipe'}\n\n$content"
                            : "💡 Health Tip from ${widget.nutritionistData['fullName']}:\n\n$content\n\n— Hidden Pantry";
                       Clipboard.setData(ClipboardData(text: shareText));
                       Toaster.show(context, "Copied to clipboard!");
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

 

   Future<void> _navigateToRecipe(String recipeId) async {
     try {
       final recipe = await RecipeService().getRecipeById(recipeId);
       if (recipe != null && mounted) {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (_) => RecipeDetailsScreen(recipe: recipe),
           ),
         );
       } else if (mounted) {
         Toaster.show(context, "Could not load recipe details", isError: true);
       }
     } catch (e) {
       if (mounted) {
         Toaster.show(context, "Error: $e", isError: true);
       }
     }
   }

  Widget _mealPlanPlaceholder() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: purple.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: Icon(Icons.restaurant_menu_rounded, color: purple.withValues(alpha:0.1), size: 32)),
    );
  }

  Widget _mealPlanInteractionCard(String? planId, String fallbackTitle) {
     if (planId == null) return Container();
     
     return StreamBuilder<DocumentSnapshot>(
       stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(widget.nutritionistId)
          .collection("meal_plans")
          .doc(planId)
          .snapshots(),
       builder: (context, snap) {
         if (!snap.hasData || !snap.data!.exists) {
           return Text(fallbackTitle, style: TextStyle(color: purple, fontWeight: FontWeight.bold));
         }
         final plan = snap.data!.data() as Map<String, dynamic>;
         final title = plan["title"] ?? "Expert Meal Plan";
         final days = plan["duration"] ?? 0;
         final cals = plan["targetCalories"] ?? 0;

         return Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: cardInner,
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: orange.withValues(alpha:0.1)),
           ),
           child: Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(color: orange.withValues(alpha:0.1), shape: BoxShape.circle),
                 child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 4),
                     Text("$days Days • $cals kcal", style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 13)),
                   ],
                 ),
               ),
               ElevatedButton(
                 onPressed: () {
                    final Map<String, dynamic> fullPlan = Map<String, dynamic>.from(plan);
                    fullPlan["planId"] = planId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MealPlanViewScreen(planData: fullPlan)),
                    );
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: orange,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   minimumSize: Size.zero,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   elevation: 0,
                 ),
                 child: const Text("View & Save", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
               ),
             ],
           ),
         );
       },
     );
  }

  Widget _recipeInteractionCard(String recipeId, String? recipeName, String? imageUrl) {
    if (recipeId.isEmpty) return Container();
    final title = (recipeName == null || recipeName.isEmpty) ? "Shared Recipe" : recipeName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: orange.withValues(alpha:0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: orange.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: (imageUrl != null && imageUrl.startsWith("http"))
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : _recipeCardIconPlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _navigateToRecipe(recipeId),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _recipeCardIconPlaceholder() {
    return Container(
      decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24),
    );
  }

  Widget _placeholderTab(String message, {IconData icon = Icons.construction_rounded}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: purple.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: purple.withValues(alpha:0.5))),
        ],
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatInterface(
          nutritionistId: widget.nutritionistId,
          nutritionistData: widget.nutritionistData,
        ),
      ),
    );
  }

  void _navigateToTiers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TierComparisonScreen(
          nutritionistId: widget.nutritionistId,
          nutritionistData: widget.nutritionistData,
          currentTier: _currentTier,
        ),
      ),
    );

    if (result == "refresh") {
       _checkSubscription();
    } else if (result != null && result is Map<String, dynamic>) {
       // Proceed to payment with selected plan
       _checkPaymentMethodsAndSubscribe(result);
    }
  }

  Widget _profileHeader(Map<String, dynamic> data) {
    final String name = data["fullName"] ?? "Nutritionist";
    final String? photo = data["photoUrl"];
    final String? org = data["organizationName"];
    
    // Initial data fallback to prevent showing 0 during loading
    final int displaySubs = _subscriberCount > 0 ? _subscriberCount : (data['subscriberCount'] ?? 0);
    final int displayPosts = _postCount > 0 ? _postCount : (data['recipeCount'] ?? 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            backgroundImage: photo != null && photo.startsWith("http")
                ? NetworkImage(photo)
                : const AssetImage("assets/Logos/mainLogo.png") as ImageProvider,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: purple,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                  ),
                ),
                if (org != null && org.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14, color: purple.withValues(alpha:0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          org,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: purple.withValues(alpha:0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                FutureBuilder<Map<String, int>>(
                  future: _countsFuture,
                  builder: (context, snapshot) {
                    int finalSubs = displaySubs > 0 ? displaySubs : (data['subscriberCount'] ?? 0);
                    int finalPosts = displayPosts > 0 ? displayPosts : (data['recipeCount'] ?? 0);
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      final dataMap = snapshot.data!;
                      if (dataMap["subs"]! >= 0) finalSubs = dataMap["subs"]!;
                      if (dataMap["posts"]! > 0) finalPosts = dataMap["posts"]!;
                    }

                    // Compute avg rating live from StreamBuilder data
                    final int reviewCount = (data['total_review_count'] as num?)?.toInt() ?? 0;
                    final double ratingSum = (data['total_rating_sum'] as num?)?.toDouble() ?? 0.0;
                    final double avgRating = reviewCount > 0 ? ratingSum / reviewCount : 0.0;

                    return Row(
                      children: [
                        _inlineStat(Icons.people_alt_rounded, "$finalSubs", "Sub"),
                        const SizedBox(width: 12),
                        _inlineStat(Icons.article_rounded, "$finalPosts", "Posts"),
                        if (avgRating > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.star_rounded, color: const Color(0xFFDAA520), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(color: purple, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "($reviewCount)",
                            style: TextStyle(color: purple.withValues(alpha: 0.45), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: orange, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: purple,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFamily: "Satoshi",
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: purple.withValues(alpha:0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _plansTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(widget.nutritionistId)
          .collection("subscription_plans")
          .where("isActive", isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final plans = snapshot.data?.docs ?? [];
        if (plans.isEmpty) {
          return _placeholderTab("No active plans.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(22),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final data = plans[index].data() as Map<String, dynamic>;
            // Ensure ID is passed for payment
            data['id'] = plans[index].id;
            return _planCard(data);
          },
        );
      },
    );
  }

  // Reuse _planCard but ensure it handles button text correctly
  Widget _planCard(Map<String, dynamic> data) {
    final List benefits = data["benefits"] ?? [];
    // ... (rest of logic)
    // Check if this plan is the current one
    final int tier = data["tierLevel"] ?? 1;
    final bool isCurrent = _isSubscribed && _currentTier == tier;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text(data["title"] ?? "Tier", style: TextStyle(color: purple, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
               Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (tier == 3 
                    ? const Color(0xFF4B0082) 
                    : tier == 2 
                      ? const Color(0xFFDAA520) 
                      : const Color(0xFF708090)).withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tier == 3 ? Icons.diamond_rounded : (tier == 2 ? Icons.star_rounded : Icons.star_half_rounded), 
                      size: 12, 
                      color: tier == 3 ? const Color(0xFF4B0082) : (tier == 2 ? const Color(0xFFDAA520) : const Color(0xFF708090))
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tier == 3 ? "PLATINUM" : tier == 2 ? "GOLD" : "SILVER",
                      style: TextStyle(
                        color: tier == 3 ? const Color(0xFF4B0082) : (tier == 2 ? const Color(0xFFDAA520) : const Color(0xFF708090)),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Rs. ${data["price"]}", style: TextStyle(color: orange, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: "Satoshi")),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text("/ ${data["interval"]}", style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: orange, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(b["title"] ?? "", style: TextStyle(color: purple, fontSize: 14))),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          
          if (isCurrent)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                   side: BorderSide(color: orange),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: Text("Current Plan", style: TextStyle(color: orange, fontWeight: FontWeight.bold)),
              ),
            )
          else 
            ElevatedButton(
              onPressed: () => _checkPaymentMethodsAndSubscribe(data),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _isSubscribed ? "Switch to this Plan" : "Subscribe Now", 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            )
        ],
      ),
    );
  }

  // Removed _nutritionistContent, _tipsList, _plansList as they are replaced by Tabs


  Future<void> _checkPaymentMethodsAndSubscribe(Map<String, dynamic> plan) async {
    final bool isStripeLinked = widget.nutritionistData['stripeId'] != null || 
                               widget.nutritionistData['stripeAccountId'] != null;
    
    if (!isStripeLinked) {
      Toaster.show(context, "This nutritionist is not yet set up to receive payments.", isError: true);
      return;
    }
    _startStripeCheckout(plan);
  }

  void _showRatingDialog() async {
    // Pre-fetch the user's existing review (if any)
    final existingReview = await NutritionistService().getMyReview(widget.nutritionistId);
    final existingData = existingReview?.data() as Map<String, dynamic>?;
    final isUpdate = existingData != null;

    double currentRating = (existingData?['rating'] as num?)?.toDouble() ?? 0.0;
    final commentCtrl = TextEditingController(text: existingData?['reviewText'] ?? '');
    bool isSubmitting = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isUpdate ? "Update Your Review" : "Rate Nutritionist",
              style: const TextStyle(color: Color(0xFF462F4D), fontWeight: FontWeight.w900, fontFamily: "Satoshi", fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUpdate ? "You already reviewed this nutritionist. Update below." : "How was your experience?",
                  style: const TextStyle(color: Color(0xFF462F4D)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setDialogState(() => currentRating = index + 1.0),
                      icon: Icon(
                        index < currentRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFDAA520),
                        size: 32,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: commentCtrl,
                  decoration: InputDecoration(
                    hintText: "Write a review (optional)",
                    hintStyle: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.5))),
              ),
              ElevatedButton(
                onPressed: (currentRating == 0.0 || isSubmitting)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await NutritionistService().submitRating(
                            nutritionistId: widget.nutritionistId,
                            rating: currentRating,
                            reviewText: commentCtrl.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            Toaster.show(context, isUpdate ? "Review updated!" : "Thank you for your review!");
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) Toaster.show(context, "Error: $e", isError: true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF8A54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isUpdate ? "Update" : "Submit", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startStripeCheckout(Map<String, dynamic> plan) async {
     setState(() => _isLoadingSubscription = true);
     try {
       final rawPrice = plan['price'];
       double price = 0.0;
       
       if (rawPrice is num) {
         price = rawPrice.toDouble();
       } else if (rawPrice is String) {
         price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
       }

       if (price <= 0) {
         throw Exception("Invalid plan price: $rawPrice");
       }

       final rawTier = plan['tierLevel'];
       int tierLevel = 1;
       if (rawTier is num) {
         tierLevel = rawTier.toInt();
       } else if (rawTier is String) {
         tierLevel = int.tryParse(rawTier) ?? 1;
       }

       final stripe = StripeService();
       final url = await stripe.createNutritionistCheckout(
         planId: plan['id'] ?? '',
         planTitle: plan['title'] ?? 'Plan',
         price: price,
         interval: plan['interval'] ?? 'month',
         nutritionistId: widget.nutritionistId,
         nutritionistName: widget.nutritionistData['fullName'] ?? 'Nutritionist',
         existingSubscriptionId: _subscriptionDocId,
         tierLevel: tierLevel,
       );

       if (mounted) {
         setState(() => _isLoadingSubscription = false);
         await stripe.launchStripeUrl(url);
         _checkSubscription();
       }
     } catch (e) {
       if (mounted) {
         setState(() => _isLoadingSubscription = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Checkout error: $e")),
         );
       }
     }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showComments(String tipId) {
    if (tipId.isEmpty || widget.nutritionistId.isEmpty) return;
    final commentCtrl = TextEditingController();
    final nutritionistId = widget.nutritionistId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Comments", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: "Satoshi")),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(nutritionistId)
                    .collection("tips")
                    .doc(tipId)
                    .collection("comments")
                    .orderBy("timestamp", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text("No comments yet", style: TextStyle(color: purple.withValues(alpha:0.4))),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final c = docs[index].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: cardBg,
                              child: Icon(Icons.person, size: 14, color: orange),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c["userName"] ?? "User", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(c["text"] ?? "", style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(color: purple.withValues(alpha:0.4)),
                        filled: true,
                        fillColor: cardInner,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: orange,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      onPressed: () async {
                        final text = commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        commentCtrl.clear();
                        final user = FirebaseAuth.instance.currentUser;
                        final tipRef = FirebaseFirestore.instance
                            .collection("nutritionists").doc(nutritionistId)
                            .collection("tips").doc(tipId);
                        
                        await tipRef.collection("comments").add({
                          "text": text,
                          "userId": user?.uid,
                          "userName": user?.displayName ?? "User",
                          "timestamp": FieldValue.serverTimestamp(),
                        });
                        await tipRef.update({"commentCount": FieldValue.increment(1)});
                        
                        // Send Notification to nutritionist
                        if (nutritionistId != user?.uid) {
                          NotificationService().sendNotification(
                            recipientId: nutritionistId,
                            recipientRole: 'nutritionist',
                            title: "New Comment",
                            body: "${user?.displayName ?? 'Someone'} commented on your post: $text",
                            type: NotificationType.comment,
                            targetId: tipId,
                          );
                        }
                      },
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

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.day}/${date.month}/${date.year}";
  }

  // ... (keep _BackgroundPattern) ...
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this._tabBar, {this.backgroundColor = Colors.white});

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for border

  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          _tabBar,
          Container(height: 1, color: const Color(0xFF462F4D).withValues(alpha:0.1)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

