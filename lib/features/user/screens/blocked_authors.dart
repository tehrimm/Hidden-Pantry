import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class BlockedAuthorsScreen extends StatefulWidget {
  const BlockedAuthorsScreen({super.key});

  @override
  State<BlockedAuthorsScreen> createState() => _BlockedAuthorsScreenState();
}

class _BlockedAuthorsScreenState extends State<BlockedAuthorsScreen> {
  static const Color bg = Color(0xFFFFF3EB);
  static const Color orange = Color(0xFFF2894F);
  static const Color text = Color(0xFF462F4D);

  bool _loading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _loading = true);
    
    try {
      final blockedIds = await ModerationService().getBlockedUsers();
      final cachedProfiles = await ModerationService().getBlockedUserProfiles();
      if (blockedIds.isEmpty) {
        if (mounted) setState(() { _blockedUsers = []; _loading = false; });
        return;
      }

      // Fetch user details for each blocked ID
      List<Map<String, dynamic>> users = [];
      for (String id in blockedIds) {
        // First check our new cached profiles (especially for backend/scraped authors)
        if (cachedProfiles.containsKey(id)) {
          users.add({
            'id': id,
            'name': cachedProfiles[id]['name'] ?? 'Unknown Author',
            'photoUrl': cachedProfiles[id]['photoUrl'],
          });
          continue;
        }

        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
          if (doc.exists) {
            users.add({
              'id': id,
              'name': doc.data()?['fullName'] ?? 'Unknown User',
              'photoUrl': doc.data()?['photoUrl'],
            });
          } else {
             // Check nutritionists collection just in case
             final nDoc = await FirebaseFirestore.instance.collection('nutritionists').doc(id).get();
             if (nDoc.exists) {
               users.add({
                'id': id,
                'name': nDoc.data()?['fullName'] ?? 'Unknown User',
                'photoUrl': nDoc.data()?['photoUrl'],
              });
             } else {
               // If completely not found in DB, try finding a recipe by them to extract name/photo
               final recipeDoc = await FirebaseFirestore.instance
                  .collection('recipes')
                  .where('author_id', isEqualTo: id)
                  .limit(1)
                  .get();

               if (recipeDoc.docs.isNotEmpty) {
                 final rData = recipeDoc.docs.first.data();
                 users.add({
                  'id': id,
                  'name': rData['author_name'] ?? rData['authorName'] ?? rData['sourceName'] ?? id,
                  'photoUrl': rData['author_profile_image_url'] ?? rData['authorProfileImageUrl'] ?? rData['author_profile'],
                 });
               } else {
                 users.add({
                  'id': id,
                  'name': id, // Show their ID/Username as a last resort
                  'photoUrl': null,
                 });
               }
             }
          }
        } catch (_) {}
      }
      
      if (mounted) setState(() { _blockedUsers = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    try {
      await ModerationService().unblockUser(userId);
      setState(() {
        _blockedUsers.removeWhere((u) => u['id'] == userId);
      });
      if (mounted) Toaster.show(context, "$userName unblocked.");
    } catch (e) {
      if (mounted) Toaster.show(context, "Error unblocking user.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const PatternBackground(),

          // Decorative corner shapes
          Positioned(
            top: -30.sh, right: -30.sw,
            child: Container(width: 120.sw, height: 120.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.06))),
          ),
          Positioned(
            bottom: -40.sh, left: -40.sw,
            child: Container(width: 160.sw, height: 160.sw,
              decoration: BoxDecoration(shape: BoxShape.circle, color: text.withValues(alpha: 0.04))),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.width >= 600 ? 24.sh : 35.sh),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.sw),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BackButtonWidget(
                          onPressed: () => Navigator.pop(context),
                          color: text,
                        ),
                      ),
                      Text(
                        'Blocked Authors',
                        style: TextStyle(
                          color: text,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25.sh),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: orange))
                      : _blockedUsers.isEmpty
                          ? _buildEmptyState()
                          : _buildBlockedList(),
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
              color: Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_alt_outlined, size: 64.sp, color: text.withValues(alpha: 0.3)),
          ),
          SizedBox(height: 24.sh),
          Text(
            "No blocked authors",
            style: TextStyle(
              color: text,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 8.sh),
          Text(
            "You haven't blocked anyone yet.",
            style: TextStyle(
              color: text.withValues(alpha: 0.5),
              fontSize: 14.sp,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(30.sw, 20.sh, 30.sw, 40.sh),
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return Container(
          margin: EdgeInsets.only(bottom: 16.sh),
          padding: EdgeInsets.all(16.sw),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20.sw),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24.sw,
                backgroundColor: text.withValues(alpha: 0.1),
                backgroundImage: user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty
                    ? NetworkImage(user['photoUrl'])
                    : null,
                onBackgroundImageError: user['photoUrl'] != null ? (_, __) {} : null,
                child: user['photoUrl'] == null || user['photoUrl'].toString().isEmpty
                    ? Icon(Icons.person, color: text.withValues(alpha: 0.4))
                    : null,
              ),
              SizedBox(width: 16.sw),
              
              // Name
              Expanded(
                child: Text(
                  user['name'],
                  style: TextStyle(
                    color: text,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              
              // Unblock Button
              GestureDetector(
                onTap: () => _unblockUser(user['id'], user['name']),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 8.sh),
                  decoration: BoxDecoration(
                    color: text.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.sw),
                  ),
                  child: Text(
                    "Unblock",
                    style: TextStyle(
                      color: text.withValues(alpha: 0.7),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
