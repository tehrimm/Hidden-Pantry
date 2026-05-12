import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/recipe_details.dart';
import 'package:hidden_pantry_app/features/recipes/screens/reviews/reviews.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/core/constants/api_constants.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'dart:ui' as ui;
import 'dart:async';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final ModerationService _moderationService = ModerationService();
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];
  StreamSubscription? _reportSub;
  final Map<String, Map<String, dynamic>> _enrichedCache = {};

  static const Color purple = Color(0xFF462F4D);
  static const Color orange = Color(0xFFF2894F);
  static const Color bg = Color(0xFFFFF3EB);

  @override
  void initState() {
    super.initState();
    _reportSub = _moderationService.getReportSummaryStream().listen((reports) {
      _handleNewReports(reports);
    });
  }

  @override
  void dispose() {
    _reportSub?.cancel();
    super.dispose();
  }

  void _handleNewReports(List<Map<String, dynamic>> rawReports) async {
    if (!mounted) return;

    // 1. Update UI immediately with what we have (preserving cache)
    setState(() {
      _reports = rawReports.map((r) {
        final id = r['contentId'] as String;
        if (_enrichedCache.containsKey(id)) {
          return {...r, ..._enrichedCache[id]!};
        }
        return r;
      }).toList();
      _loading = false;
    });

    // 2. Identify and enrich only missing ones
    final toEnrich = rawReports.where((r) => !_enrichedCache.containsKey(r['contentId'])).toList();
    if (toEnrich.isEmpty) return;

    // Enrich concurrently but update UI as each one finishes
    for (final report in toEnrich) {
      _enrichSingleReport(report, rawReports);
    }
  }

  Future<void> _enrichSingleReport(Map<String, dynamic> report, List<Map<String, dynamic>> rawReports) async {
    try {
      final contentType = report['contentType'] as String;
      final contentId = report['contentId'] as String;
      final Map<String, dynamic> enrichedData = {};

      if (contentType == 'recipe') {
        var doc = await FirebaseFirestore.instance.collection('recipes').doc(contentId).get();
        if (!doc.exists) {
          final query = await FirebaseFirestore.instance.collection('recipes').where('id', isEqualTo: contentId).limit(1).get();
          if (query.docs.isNotEmpty) doc = query.docs.first;
        }
        if (doc.exists) {
          final data = doc.data()!;
          enrichedData['contentTitle'] = data['name'] ?? data['title'] ?? data['recipe_name'] ?? data['recipeName'] ?? 'Untitled Recipe';
          enrichedData['contentPreview'] = data['description'] ?? '';
          enrichedData['contentImageUrl'] = data['image_url'] ?? data['imageUrl'];
          
          final authorName = data['author_name'] ?? data['authorName'] ?? data['sourceName'];
          if (authorName != null && authorName.toString().isNotEmpty) {
            enrichedData['authorName'] = authorName;
          } else {
            final authorId = report['authorId'] as String? ?? '';
            if (authorId.isNotEmpty) {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
              enrichedData['authorName'] = userDoc.data()?['fullName'] ?? 'Author #$authorId';
            }
          }
          enrichedData['_firestoreDocId'] = doc.id;
        } else {
          try {
            final apiService = const RecipeApiService(baseUrl: ApiConstants.baseUrl);
            final apiRecipe = await apiService.getRecipeById(contentId);
            enrichedData['contentTitle'] = apiRecipe.name;
            enrichedData['contentPreview'] = apiRecipe.description;
            enrichedData['contentImageUrl'] = apiRecipe.imageUrl;
            enrichedData['authorName'] = apiRecipe.authorName ?? 'API Author';
            enrichedData['isApiRecipe'] = true;
          } catch (_) {
            enrichedData['contentTitle'] = 'Content deleted';
          }
        }
      } else if (contentType == 'review') {
        final doc = await FirebaseFirestore.instance.collection('reviews').doc(contentId).get();
        if (doc.exists) {
          final data = doc.data()!;
          enrichedData['contentTitle'] = 'Review by ${data['userName'] ?? 'Unknown'}';
          enrichedData['contentPreview'] = data['comment'] ?? data['text'] ?? '';
          enrichedData['authorName'] = data['userName'] ?? 'Unknown';
        }
      } else if (contentType == 'reply') {
        final metadata = report['metadata'] as Map<String, dynamic>?;
        final reviewId = metadata?['parentReviewId'] as String?;
        if (reviewId != null) {
          final doc = await FirebaseFirestore.instance.collection('reviews').doc(reviewId).collection('replies').doc(contentId).get();
          if (doc.exists) {
            final data = doc.data()!;
            enrichedData['contentTitle'] = 'Reply by ${data['userName'] ?? 'Unknown'}';
            enrichedData['contentPreview'] = data['comment'] ?? '';
            enrichedData['authorName'] = data['userName'] ?? 'Unknown';
          }
        }
      }

      if (!mounted) return;
      if (enrichedData.isNotEmpty) {
        _enrichedCache[contentId] = enrichedData;
        setState(() {
          _reports = rawReports.map((r) {
            final id = r['contentId'] as String;
            return {...r, ...(_enrichedCache[id] ?? {})};
          }).toList();
        });
      }
    } catch (e) {
      print("Enrichment failed for ${report['contentId']}: $e");
    }
  }
  }

  Future<void> _fetchReports() async {
    // Legacy method - the stream listener now handles this automatically.
    // We can keep it as an alias for manual refresh if needed.
  }

  Future<void> _suspendUser(String userId, int days) async {
    try {
      await _moderationService.suspendUser(userId, days);
      if (mounted) {
        Toaster.show(context, 'User suspended for $days days');
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, 'Error suspending user: $e', isError: true);
      }
    }
  }

  Future<void> _takeAction(String contentType, String contentId, String action, String authorId) async {
    try {
      await _moderationService.takeAction(contentType, contentId, action, authorId);
      _fetchReports(); // Refresh
      if (mounted) {
        Toaster.show(context, 'Content deleted & author warned.');
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, 'Error taking action: $e', isError: true);
      }
    }
  }

  void _showContentPreview(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.sw)),
        child: Padding(
          padding: EdgeInsets.all(24.sw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.sw),
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      report['contentType'] == 'recipe'
                          ? Icons.restaurant_menu_rounded
                          : (report['contentType'] == 'reply' ? Icons.reply_rounded : Icons.rate_review_rounded),
                      color: orange,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.sw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reported ${report['contentType']?.toString().toUpperCase() ?? 'CONTENT'}',
                          style: TextStyle(
                            color: purple,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        Text(
                          '${report['reportCount']} report(s)',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.sh),

              // Content image (for recipes)
              if (report['contentImageUrl'] != null &&
                  report['contentImageUrl'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.sw),
                  child: Image.network(
                    report['contentImageUrl'],
                    height: 150.sh,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox.shrink(),
                  ),
                ),
              if (report['contentImageUrl'] != null &&
                  report['contentImageUrl'].toString().isNotEmpty)
                SizedBox(height: 16.sh),

              // Title
              Text(
                report['contentTitle'] ?? report['contentId'] ?? 'Unknown',
                style: TextStyle(
                  color: purple,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 8.sh),

              // Author
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14.sp, color: purple.withValues(alpha: 0.5)),
                  SizedBox(width: 4.sw),
                  Text(
                    'By ${report['authorName'] ?? report['authorId'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.5),
                      fontSize: 12.sp,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.sh),

              // Content Preview
              if (report['contentPreview'] != null &&
                  report['contentPreview'].toString().isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12.sw),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12.sw),
                    border: Border.all(color: purple.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    report['contentPreview'],
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.7),
                      fontSize: 13.sp,
                      fontFamily: 'Satoshi',
                      height: 1.5,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              SizedBox(height: 16.sh),

              // Reason
              Container(
                padding: EdgeInsets.all(12.sw),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.sw),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 16.sp, color: Colors.redAccent),
                    SizedBox(width: 8.sw),
                    Expanded(
                      child: Text(
                        'Reason: ${report['reason'] ?? 'Not specified'}',
                        style: TextStyle(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.sh),

              // View Content Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToContent(report);
                  },
                  icon: Icon(Icons.open_in_new_rounded, size: 18.sp),
                  label: Text("View Full Content", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                    padding: EdgeInsets.symmetric(vertical: 14.sh),
                    elevation: 0,
                  ),
                ),
              ),

              SizedBox(height: 10.sh),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: purple.withValues(alpha: 0.2), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                        padding: EdgeInsets.symmetric(vertical: 14.sh),
                      ),
                      child: Text("Close", style: TextStyle(color: purple.withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                    ),
                  ),
                  SizedBox(width: 12.sw),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showActionDialog(report);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                        padding: EdgeInsets.symmetric(vertical: 14.sh),
                        elevation: 0,
                      ),
                      child: Text("Take Action", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToContent(Map<String, dynamic> report) async {
    final contentType = report['contentType'] as String;
    final contentId = report['contentId'] as String;

    try {
      if (contentType == 'recipe') {
        if (report['isApiRecipe'] == true) {
          // --- BUG FIX: Navigate to API recipe details ---
          final placeholder = Recipe(
            id: contentId,
            name: report['contentTitle'] ?? 'Loading...',
            minutes: 0,
            avgRating: 0.0,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: placeholder)),
          );
          return;
        }

        // Try document ID first, then query by internal 'id' field
        var doc = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(report['_firestoreDocId'] ?? contentId)
            .get();
        if (!doc.exists) {
          final query = await FirebaseFirestore.instance
              .collection('recipes')
              .where('id', isEqualTo: contentId)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) doc = query.docs.first;
        }
        if (doc.exists && mounted) {
          final data = doc.data()!;
          data['id'] = doc.id; // Ensure the Firestore doc ID is used
          final recipe = Recipe.fromJson(data);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailsScreen(recipe: recipe)),
          );
        } else if (mounted) {
          Toaster.show(context, 'Recipe no longer exists.', isError: true);
        }
      } else if (contentType == 'review') {
        // A review ID is usually "userId_recipeId"
        final parts = contentId.split('_');
        if (parts.length >= 2) {
          final recipeId = parts.sublist(1).join('_');
          // Try document ID first, then query by field
          var recipeDoc = await FirebaseFirestore.instance
              .collection('recipes')
              .doc(recipeId)
              .get();
          if (!recipeDoc.exists) {
            final query = await FirebaseFirestore.instance
                .collection('recipes')
                .where('id', isEqualTo: recipeId)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) recipeDoc = query.docs.first;
          }
          if (recipeDoc.exists && mounted) {
            final data = recipeDoc.data()!;
            data['id'] = recipeDoc.id;
            final recipe = Recipe.fromJson(data);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReviewsScreen(recipe: recipe)),
            );
          } else if (mounted) {
            Toaster.show(context, 'Associated recipe no longer exists.', isError: true);
          }
        } else if (mounted) {
          Toaster.show(context, 'Could not resolve review location.', isError: true);
        }
      } else if (contentType == 'reply') {
        final metadata = report['metadata'] as Map<String, dynamic>?;
        final reviewId = metadata?['parentReviewId'] as String?;
        if (reviewId != null) {
          final parts = reviewId.split('_');
          if (parts.length >= 2) {
            final recipeId = parts.sublist(1).join('_');
            final recipeDoc = await FirebaseFirestore.instance.collection('recipes').doc(recipeId).get();
            if (recipeDoc.exists && mounted) {
              final recipe = Recipe.fromJson({...recipeDoc.data()!, 'id': recipeDoc.id});
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen(recipe: recipe)));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, 'Error navigating to content: $e', isError: true);
      }
    }
  }

  void _showActionDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.sw)),
        child: Padding(
          padding: EdgeInsets.all(24.sw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.sw,
                height: 50.sw,
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 26.sp),
              ),
              SizedBox(height: 16.sh),
              Text(
                'Take Action',
                style: TextStyle(
                  color: purple,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 8.sh),
              Text(
                'Managing ${report['contentType']} reported ${report['reportCount']} time(s)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: purple.withValues(alpha: 0.6),
                  fontSize: 13.sp,
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 24.sh),

              // Delete Content & Warn
              _actionTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete & Warn Author',
                subtitle: 'Remove content & send official warning',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(report);
                },
              ),
              SizedBox(height: 8.sh),

              // Suspend Author
              _actionTile(
                icon: Icons.timer_outlined,
                title: 'Suspend Author (7 days)',
                subtitle: 'Restrict access for 7 days',
                color: orange,
                onTap: () {
                  Navigator.pop(context);
                  _suspendUser(report['authorId'], 7);
                },
              ),
              SizedBox(height: 8.sh),

              // Dismiss Reports
              _actionTile(
                icon: Icons.done_all_rounded,
                title: 'Dismiss Reports',
                subtitle: 'Mark as reviewed and keep content',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _moderationService.dismissReports(report['contentId']).then((_) => _fetchReports());
                  Toaster.show(context, 'Reports dismissed.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.sw)),
        child: Padding(
          padding: EdgeInsets.all(24.sw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.sw,
                height: 50.sw,
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28.sp),
              ),
              SizedBox(height: 16.sh),
              Text(
                'Confirm Deletion',
                style: TextStyle(color: purple, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: 'Satoshi'),
              ),
              SizedBox(height: 12.sh),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: purple.withValues(alpha: 0.6), fontSize: 14.sp, fontFamily: 'Satoshi', height: 1.4),
                  children: [
                    const TextSpan(text: 'This will '),
                    TextSpan(text: 'permanently delete ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    TextSpan(text: '"${report['contentTitle'] ?? report['contentId']}"'),
                    const TextSpan(text: ' and send an '),
                    TextSpan(text: 'official warning ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const TextSpan(text: 'to the author.'),
                  ],
                ),
              ),
              SizedBox(height: 28.sh),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: purple.withValues(alpha: 0.2), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                        padding: EdgeInsets.symmetric(vertical: 14.sh),
                      ),
                      child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                    ),
                  ),
                  SizedBox(width: 12.sw),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _takeAction(
                          report['contentType'],
                          report['contentId'],
                          'delete',
                          report['authorId'],
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sw)),
                        padding: EdgeInsets.symmetric(vertical: 14.sh),
                        elevation: 0,
                      ),
                      child: const Text("Delete & Warn", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.sw),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 14.sh),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.sw),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.sw),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 14.sw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: purple,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  SizedBox(height: 2.sh),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.5),
                      fontSize: 11.sp,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: purple.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.sw, vertical: 15.sh),
                  child: Row(
                    children: [
                      const BackButtonWidget(),
                      SizedBox(width: 20.sw),
                      Expanded(
                        child: Text(
                          'Moderation Dashboard',
                          style: TextStyle(
                            color: purple,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                      // Report count badge
                      if (!_loading && _reports.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.sw),
                          ),
                          child: Text(
                            '${_reports.length}',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: orange))
                      : _reports.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: orange,
                              onRefresh: _fetchReports,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: EdgeInsets.symmetric(horizontal: 25.sw),
                                itemCount: _reports.length,
                                itemBuilder: (context, index) {
                                  final report = _reports[index];
                                  return _ReportCard(
                                    report: report,
                                    onTap: () => _showContentPreview(report),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.sw),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, size: 56.sp, color: Colors.green.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 24.sh),
          Text(
            'All clear!',
            style: TextStyle(
              color: purple,
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 8.sh),
          Text(
            'No pending reports to review.',
            style: TextStyle(
              color: purple.withValues(alpha: 0.5),
              fontSize: 14.sp,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF462F4D);
    const orange = Color(0xFFF2894F);

    return Container(
      margin: EdgeInsets.only(bottom: 16.sh),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20.sw),
              child: Container(
                padding: EdgeInsets.all(16.sw),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20.sw),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                          decoration: BoxDecoration(
                            color: orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.sw),
                          ),
                          child: Text(
                            report['contentType'].toString().toUpperCase(),
                            style: TextStyle(
                              color: orange,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 16.sw),
                            SizedBox(width: 4.sw),
                            Text(
                              'Reported ${report['reportCount']} times',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.sh),
                    Text(
                      report['contentTitle'] ?? report['contentId'] ?? 'Unknown',
                      style: TextStyle(
                        color: purple,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Satoshi',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.sh),
                    if (report['contentPreview'] != null && report['contentPreview'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.sh),
                        child: Text(
                          report['contentPreview'],
                          style: TextStyle(
                            color: purple.withValues(alpha: 0.5),
                            fontSize: 12.sp,
                            fontFamily: 'Satoshi',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14.sp, color: purple.withValues(alpha: 0.4)),
                        SizedBox(width: 4.sw),
                        Text(
                          report['authorName'] ?? report['authorId'] ?? 'Unknown',
                          style: TextStyle(
                            color: purple.withValues(alpha: 0.4),
                            fontSize: 11.sp,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tap to review →',
                          style: TextStyle(
                            color: orange.withValues(alpha: 0.7),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
