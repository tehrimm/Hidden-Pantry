import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/user/services/stripe_service.dart';
import 'package:hidden_pantry_app/features/user/screens/tier_comparison_screen.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'package:hidden_pantry_app/core/services/view_mode_service.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'chat_interface_part.dart';
import 'package:hidden_pantry_app/core/services/user_status_service.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
      }
    });
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
        ResponsiveUtils.init(context);
        final Map<String, dynamic> nutritionistData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.nutritionistData;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              const PatternBackground(),
              Column(
                children: [
                  SizedBox(height: 50.sh),
                  _customAppBar(nutritionistData["fullName"] ?? "Expert Profile"),
                  _profileHeader(nutritionistData),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 8.sh),
                    child: Text(
                      nutritionistData["bio"] ?? "Dedicated health professional.",
                      style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14.sp, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 24.sh),
                  TabBar(
                    controller: _tabController,
                    labelColor: orange,
                    unselectedLabelColor: purple.withValues(alpha:0.4),
                    indicatorColor: orange,
                    isScrollable: false,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: "Satoshi"),
                    tabs: const [
                      Tab(text: "Feed"),
                      Tab(text: "Reviews"),
                      Tab(text: "Plans"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _feedTab(),
                        _reviewsTab(),
                        _plansTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: (!_isLoadingSubscription && _isSubscribed && _hasPrioritySupport)
              ? FloatingActionButton(
                  onPressed: _openChat,
                  backgroundColor: orange,
                  elevation: 4.sw,
                  child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24.sw),
                )
              : null,
        ),
        );
      },
    );
  }

  Widget _customAppBar(String name) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 8.sh),
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
                fontSize: 18.sp,
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
          padding: EdgeInsets.all(22.sw),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data["id"] = doc.id; // Correctly pass document ID
            return _animatedItem(index, _tipCard(data));
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

        // Calculate Average
        double totalRating = 0;
        for (var d in docs) {
          totalRating += (d.data() as Map<String, dynamic>)['rating'] ?? 0.0;
        }
        double avg = docs.isEmpty ? 0 : totalRating / docs.length;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 22.sw, vertical: 16.sh),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Rating Overview Header
              return Container(
                margin: EdgeInsets.only(bottom: 24.sh),
                padding: EdgeInsets.all(20.sw),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24.sw),
                  border: Border.all(color: orange.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(color: purple, fontSize: 40.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                        ),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < avg.floor() ? Icons.star_rounded : (i < avg ? Icons.star_half_rounded : Icons.star_outline_rounded),
                            color: orange,
                            size: 16.sw,
                          )),
                        ),
                        SizedBox(height: 4.sh),
                        Text(
                          "Based on ${docs.length} reviews",
                          style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 11.sp),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 60.sw,
                      height: 60.sw,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: orange.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(Icons.star_rounded, color: orange, size: 32.sw),
                    ),
                  ],
                ),
              );
            }

            final d = docs[index - 1].data() as Map<String, dynamic>;
            final double rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
            final String name = d['userName'] ?? 'User';
            final String text = d['reviewText'] ?? '';
            final Timestamp? ts = d['timestamp'] as Timestamp?;
            final String time = ts != null ? _timeAgo(ts.toDate()) : '';

            return _animatedItem(index, Container(
              margin: EdgeInsets.only(bottom: 16.sh),
              padding: EdgeInsets.all(16.sw),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F5),
                borderRadius: BorderRadius.circular(22.sw),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.03),
                    blurRadius: 15.sw,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.sw),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: orange.withValues(alpha: 0.1)),
                        ),
                        child: CircleAvatar(
                          radius: 14.sw, 
                          backgroundColor: cardInner, 
                          child: Icon(Icons.person, size: 14.sw, color: orange)
                        ),
                      ),
                      SizedBox(width: 12.sw),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(color: purple, fontWeight: FontWeight.w900, fontSize: 13.sp, fontFamily: "Satoshi")),
                            if (time.isNotEmpty)
                              Text(time, style: TextStyle(color: purple.withValues(alpha: 0.3), fontSize: 10.sp)),
                          ],
                        ),
                      ),
                      // Stars
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: orange,
                          size: 14.sw,
                        )),
                      ),
                    ],
                  ),
                  if (text.isNotEmpty) ...[
                    SizedBox(height: 12.sh),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, color: orange.withValues(alpha: 0.2), size: 16.sw),
                        SizedBox(width: 8.sw),
                        Expanded(
                          child: Text(
                            text, 
                            style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 13.sp, height: 1.5, fontStyle: FontStyle.italic)
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ));
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
            width: 24.sw, height: 24.sw, 
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
      margin: EdgeInsets.only(bottom: 12.sh),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F5),
        borderRadius: BorderRadius.circular(22.sw),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.03),
            blurRadius: 15.sw,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.sw, 10.sh, 12.sw, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.sw),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: orange.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                           radius: 16.sw, 
                           backgroundColor: cardInner,
                           backgroundImage: widget.nutritionistData["photoUrl"] != null && widget.nutritionistData["photoUrl"].toString().startsWith("http")
                              ? NetworkImage(widget.nutritionistData["photoUrl"]) 
                              : null,
                           child: (widget.nutritionistData["photoUrl"] == null) ? Icon(Icons.person, color: orange, size: 16.sw) : null,
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: UserStatusService().getStatusStream(widget.nutritionistId, true),
                        builder: (context, statusSnap) {
                          if (!statusSnap.hasData || !statusSnap.data!.exists) return const SizedBox.shrink();
                          final statusData = statusSnap.data!.data() as Map<String, dynamic>;
                          final bool isOnline = statusData['isOnline'] ?? false;
                          if (!isOnline) return const SizedBox.shrink();

                          return Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 8.sw,
                              height: 8.sw,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.sw),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nutritionistData["fullName"] ?? "Nutritionist",
                        style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: "Satoshi"),
                      ),
                      Text(
                        timeAgo, 
                        style: TextStyle(color: purple.withValues(alpha:0.3), fontSize: 10.sp),
                      ),
                    ],
                  ),
                ),
                if (minTier > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                    decoration: BoxDecoration(
                      color: isLocked 
                          ? Colors.grey[100] 
                          : (minTier == 3 
                              ? const Color(0xFF6A4C93) // Platinum
                              : minTier == 2 
                                ? const Color(0xFFD4AF37) // Gold
                                : const Color(0xFF8A9EA7)).withValues(alpha:0.1), // Silver
                      borderRadius: BorderRadius.circular(10.sw),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.lock_rounded : (minTier == 3 ? Icons.diamond_rounded : (minTier == 2 ? Icons.star_rounded : Icons.star_half_rounded)), 
                          size: 10.sw, 
                          color: isLocked ? Colors.grey : (minTier == 3 ? const Color(0xFF6A4C93) : (minTier == 2 ? const Color(0xFFD4AF37) : const Color(0xFF8A9EA7)))
                        ),
                        SizedBox(width: 4.sw),
                        Text(
                          minTier == 3 ? "PLATINUM" : minTier == 2 ? "GOLD" : "SILVER",
                          style: TextStyle(
                            color: isLocked ? Colors.grey : (minTier == 3 ? const Color(0xFF6A4C93) : (minTier == 2 ? const Color(0xFFD4AF37) : const Color(0xFF8A9EA7))),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 10.sh),

          // ── Content ──
          if (isLocked)
            Container(
              width: double.infinity,
              height: 175.sh,
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.sw)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.sw),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative Background Circles
                    Positioned(
                      top: -20.sh,
                      right: -20.sw,
                      child: Container(
                        width: 140.sw,
                        height: 140.sw,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -40.sh,
                      left: -10.sw,
                      child: Container(
                        width: 120.sw,
                        height: 120.sw,
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40.sh,
                      left: 60.sw,
                      child: Container(
                        width: 40.sw,
                        height: 40.sw,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Centered Content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16.sw),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: orange.withValues(alpha: 0.2),
                                blurRadius: 20.sw,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(Icons.lock_rounded, color: orange, size: 24.sw),
                        ),
                        SizedBox(height: 12.sh),
                        Text(
                          "EXCLUSIVE ${minTier == 3 ? 'PLATINUM' : minTier == 2 ? 'GOLD' : 'SILVER'} CONTENT",
                          style: TextStyle(
                            color: purple,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.sp,
                            letterSpacing: 1.2,
                            fontFamily: "Satoshi",
                          ),
                        ),
                        SizedBox(height: 8.sh),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.sw),
                          child: Text(
                            "This ${type == 'meal_plan' || data['mealPlanId'] != null ? 'Meal Plan' : 'Update'} is locked.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp),
                          ),
                        ),
                        SizedBox(height: 12.sh),
                        ElevatedButton(
                          onPressed: () => _navigateToTiers(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 12.sh),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.sw)),
                          ),
                          child: Text("Unlock Plan", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.sw),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (content.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.sh),
                      child: Text(
                        content,
                        style: TextStyle(color: purple.withValues(alpha:0.75), fontSize: 13.sp, height: 1.4),
                      ),
                    ),
                  
                  // New Image Attachment
                  if (data["imageUrl"] != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.sh),
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(context, data["imageUrl"]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.sw),
                          child: Image.network(
                            data["imageUrl"],
                            width: double.infinity,
                            height: 180.sh,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(height: 180.sh, color: purple.withValues(alpha:0.05), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: orange))),
                          ),
                        ),
                      ),
                    ),

                  // Meal Plan
                  if (type == "meal_plan" || data["mealPlanId"] != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.sh),
                      child: _mealPlanInteractionCard(data["mealPlanId"], content),
                    ),

                  // Shared Recipe
                  if (data["recipeId"] != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.sh),
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
                        padding: EdgeInsets.all(12.sw),
                        margin: EdgeInsets.only(bottom: 12.sh),
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha:0.05),
                          borderRadius: BorderRadius.circular(12.sw),
                          border: Border.all(color: purple.withValues(alpha:0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file_rounded, color: orange, size: 24.sw),
                            SizedBox(width: 12.sw),
                            Expanded(child: Text("Attached Document", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13.sp))),
                            Icon(Icons.open_in_new_rounded, color: purple.withValues(alpha:0.4), size: 18.sw),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 12.sh),
            
            // Divider
            Container(height: 1, margin: EdgeInsets.symmetric(horizontal: 16.sw), color: purple.withValues(alpha:0.06)),

            // Action Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 6.sh),
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
      height: 80.sh,
      decoration: BoxDecoration(
        color: purple.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(16.sw),
      ),
      child: Center(child: Icon(Icons.restaurant_menu_rounded, color: purple.withValues(alpha:0.1), size: 32.sw)),
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
          padding: EdgeInsets.symmetric(horizontal: 14.sw, vertical: 12.sh),
          decoration: BoxDecoration(
            color: cardInner,
            borderRadius: BorderRadius.circular(16.sw),
            border: Border.all(color: orange.withValues(alpha:0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.sw),
                decoration: BoxDecoration(color: orange.withValues(alpha:0.1), shape: BoxShape.circle),
                child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 20.sw),
              ),
              SizedBox(width: 12.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    const SizedBox(height: 2),
                    Text("$days Days • $cals kcal", style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 11.sp)),
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
                  padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 6.sh),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.sw)),
                  elevation: 0,
                ),
                child: Text("View & Save", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
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
      padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 10.sh),
      decoration: BoxDecoration(
        color: cardInner,
        borderRadius: BorderRadius.circular(16.sw),
        border: Border.all(color: orange.withValues(alpha:0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.sw,
            height: 44.sw,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: orange.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(10.sw),
            ),
            child: (imageUrl != null && imageUrl.startsWith("http"))
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : _recipeCardIconPlaceholder(),
          ),
          SizedBox(width: 12.sw),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _navigateToRecipe(recipeId),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 8.sh),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.sw)),
              elevation: 0,
            ),
            child: Text("View", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _recipeCardIconPlaceholder() {
    return Container(
      decoration: BoxDecoration(color: orange.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 24.sw),
    );
  }

  Widget _placeholderTab(String message, {IconData icon = Icons.construction_rounded}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48.sw, color: purple.withValues(alpha:0.2)),
          SizedBox(height: 16.sh),
          Text(message, style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14.sp)),
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
    final int displaySubs = _subscriberCount;
    final int displayPosts = _postCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(22.sw, 16.sh, 22.sw, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           Stack(
            children: [
              CircleAvatar(
                radius: 40.sw,
                backgroundColor: Colors.white,
                backgroundImage: photo != null && photo.startsWith("http")
                    ? NetworkImage(photo)
                    : const AssetImage("assets/logos/main_logo.png") as ImageProvider,
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: UserStatusService().getStatusStream(widget.nutritionistId, true),
                builder: (context, statusSnap) {
                  if (!statusSnap.hasData || !statusSnap.data!.exists) return const SizedBox.shrink();
                  final statusData = statusSnap.data!.data() as Map<String, dynamic>;
                  final bool isOnline = statusData['isOnline'] ?? false;
                  if (!isOnline) return const SizedBox.shrink();

                  return Positioned(
                    right: 4.sw,
                    bottom: 4.sw,
                    child: Container(
                      width: 16.sw,
                      height: 16.sw,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.sw),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(width: 20.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: purple,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                  ),
                ),
                if (org != null && org.isNotEmpty) ...[
                  SizedBox(height: 4.sh),
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14.sw, color: purple.withValues(alpha:0.5)),
                      SizedBox(width: 4.sw),
                      Expanded(
                        child: Text(
                          org,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: purple.withValues(alpha:0.5),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8.sh),
                FutureBuilder<Map<String, int>>(
                  future: _countsFuture,
                  builder: (context, snapshot) {
                    int finalSubs = displaySubs;
                    int finalPosts = displayPosts;
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      final dataMap = snapshot.data!;
                      if (dataMap["subs"]! >= 0) finalSubs = dataMap["subs"]!;
                      if (dataMap["posts"]! >= 0) finalPosts = dataMap["posts"]!;
                    }

                    // Compute avg rating live from StreamBuilder data
                    final int reviewCount = (data['total_review_count'] as num?)?.toInt() ?? 0;
                    final double ratingSum = (data['total_rating_sum'] as num?)?.toDouble() ?? 0.0;
                    final double avgRating = reviewCount > 0 ? ratingSum / reviewCount : 0.0;

                    return Row(
                      children: [
                        _inlineStat(Icons.people_alt_rounded, "$finalSubs", "Sub"),
                        SizedBox(width: 12.sw),
                        _inlineStat(Icons.article_rounded, "$finalPosts", "Posts"),
                        if (avgRating > 0) ...[
                          SizedBox(width: 12.sw),
                          Icon(Icons.star_rounded, color: const Color(0xFFDAA520), size: 14.sw),
                          SizedBox(width: 4.sw),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(color: purple, fontSize: 14.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
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
        Icon(icon, color: orange, size: 14.sw),
        SizedBox(width: 4.sw),
        Text(
          value,
          style: TextStyle(
            color: purple,
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            fontFamily: "Satoshi",
          ),
        ),
        SizedBox(width: 4.sw),
        Text(
          label,
          style: TextStyle(
            color: purple.withValues(alpha:0.5),
            fontSize: 11.sp,
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
          padding: EdgeInsets.all(22.sw),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final data = plans[index].data() as Map<String, dynamic>;
            // Ensure ID is passed for payment
            data['id'] = plans[index].id;
            return _planCard(data, index);
          },
        );
      },
    );
  }

  Widget _planCard(Map<String, dynamic> data, int index) {
    final List benefits = data["benefits"] ?? [];
    final int tier = data["tierLevel"] ?? 1;
    final bool isCurrent = _isSubscribed && _currentTier == tier;
    
    // Tier-specific styling
    Color tierColor;
    Color accentColor;
    IconData tierIcon;
    String tierName;

    if (tier == 3) {
      tierColor = const Color(0xFF6A4C93); // Royal Purple for Platinum
      accentColor = tierColor.withValues(alpha: 0.1);
      tierIcon = Icons.diamond_rounded;
      tierName = "PLATINUM";
    } else if (tier == 2) {
      tierColor = const Color(0xFFD4AF37); // Gold
      accentColor = tierColor.withValues(alpha: 0.1);
      tierIcon = Icons.star_rounded;
      tierName = "GOLD";
    } else {
      tierColor = const Color(0xFF8A9EA7); // Cool Silver
      accentColor = tierColor.withValues(alpha: 0.1);
      tierIcon = Icons.star_half_rounded;
      tierName = "SILVER";
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: EdgeInsets.only(bottom: 16.sh),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F5),
                borderRadius: BorderRadius.circular(24.sw),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.03),
                    blurRadius: 15.sw,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30.sw),
                child: Stack(
                  children: [
                    // Top Accent Blob
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120.sw,
                        height: 120.sw,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: EdgeInsets.all(24.sw),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data["title"] ?? "Plan",
                                    style: TextStyle(
                                      color: purple,
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(8.sw),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(tierIcon, size: 12.sw, color: tierColor),
                                        SizedBox(width: 6.sw),
                                        Text(
                                          tierName,
                                          style: TextStyle(
                                            color: tierColor,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isCurrent)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                                  decoration: BoxDecoration(
                                    color: orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12.sw),
                                    border: Border.all(color: orange.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    "ACTIVE",
                                    style: TextStyle(color: orange, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 20.sh),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Rs. ${data["price"]}",
                                style: TextStyle(
                                  color: orange,
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: "Satoshi",
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: 6.sh, left: 6.sw),
                                child: Text(
                                  "/ ${data["interval"]}",
                                  style: TextStyle(
                                    color: purple.withValues(alpha: 0.4),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24.sh),
                          Divider(color: purple.withValues(alpha: 0.05)),
                          SizedBox(height: 20.sh),
                          ...benefits.map((b) => Padding(
                                padding: EdgeInsets.only(bottom: 12.sh),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4.sw),
                                      decoration: BoxDecoration(
                                        color: orange.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check, color: orange, size: 12.sw),
                                    ),
                                    SizedBox(width: 14.sw),
                                    Expanded(
                                      child: Text(
                                        b["title"] ?? "",
                                        style: TextStyle(
                                          color: purple.withValues(alpha: 0.8),
                                          fontSize: 14.sp,
                                          fontFamily: "Satoshi",
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          SizedBox(height: 28.sh),
                          
                          if (isCurrent)
                            SizedBox(
                              width: double.infinity,
                              height: 56.sh,
                              child: OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: purple),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.sw)),
                                ),
                                child: Text("Current Plan", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16.sp)),
                              ),
                            )
                          else 
                            ElevatedButton(
                              onPressed: () => _checkPaymentMethodsAndSubscribe(data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 56.sh),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.sw)),
                                elevation: 8.sh,
                                shadowColor: tierColor.withValues(alpha: 0.3),
                              ),
                              child: Text(
                                _isSubscribed ? "Switch Plan" : "Get Started Now", 
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi")
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

    GlassDialog.show(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sw)),
            title: Text(
              isUpdate ? "Update Your Review" : "Rate Nutritionist",
              style: TextStyle(color: const Color(0xFF462F4D), fontWeight: FontWeight.w900, fontFamily: "Satoshi", fontSize: 20.sp),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUpdate ? "You already reviewed this nutritionist. Update below." : "How was your experience?",
                  style: TextStyle(color: const Color(0xFF462F4D), fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.sh),
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
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: "Write a review (optional)",
                    hintStyle: TextStyle(color: const Color(0xFF462F4D).withValues(alpha: 0.5), fontSize: 14.sp),
                    filled: true,
                    fillColor: const Color(0xFFF6F6F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.sw), borderSide: BorderSide.none),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? SizedBox(width: 16.sw, height: 16.sw, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isUpdate ? "Update" : "Submit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
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
           SnackBar(content: Text(StripeService.friendlyError(e))),
         );
       }
     }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Image",
      barrierColor: Colors.black.withValues(alpha:0.9),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 40.sh,
                right: 20.sw,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8.sw),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 24.sw),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _animatedItem(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
    );
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
        borderRadius: BorderRadius.circular(12.sw),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 8.sh),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18.sw, color: color),
              if (label.isNotEmpty) ...[
                SizedBox(width: 5.sw),
                Text(label, style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w600)),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.sw)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.sh),
              width: 40.sw, height: 4.sh,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.sw)),
            ),
            Padding(
              padding: EdgeInsets.all(16.sw),
              child: Text("Comments", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp, fontFamily: "Satoshi")),
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
                      child: Text("No comments yet", style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 14.sp)),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.sw),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final c = docs[index].data() as Map<String, dynamic>;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.sh),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14.sw,
                              backgroundColor: cardBg,
                              child: Icon(Icons.person, size: 14.sw, color: orange),
                            ),
                            SizedBox(width: 10.sw),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c["userName"] ?? "User", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                  SizedBox(height: 2.sh),
                                  Text(c["text"] ?? "", style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 13.sp)),
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
              padding: EdgeInsets.fromLTRB(16.sw, 8.sh, 16.sw, MediaQuery.of(context).viewInsets.bottom + 16.sh),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10.sw, offset: Offset(0, -4.sh))],
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
                  SizedBox(width: 8.sw),
                  CircleAvatar(
                    radius: 20.sw,
                    backgroundColor: orange,
                    child: IconButton(
                      icon: Icon(Icons.send_rounded, color: Colors.white, size: 16.sw),
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

