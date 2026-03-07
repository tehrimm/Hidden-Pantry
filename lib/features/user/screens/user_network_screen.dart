import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/author_profile.dart'; // Assuming this exists or similar
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

class UserNetworkScreen extends StatefulWidget {
  final int initialIndex;
  final bool isNutritionist;
  const UserNetworkScreen({super.key, this.initialIndex = 0, this.isNutritionist = false});

  @override
  State<UserNetworkScreen> createState() => _UserNetworkScreenState();
}

class _UserNetworkScreenState extends State<UserNetworkScreen> {
  final _followService = FollowService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF462F4D);
    const bg = Color(0xFFFFF3EB);
    const brown = Color(0xFF433020);
    const orange = Color(0xFFEF8A54);

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: widget.isNutritionist ? Colors.white : bg,
        body: ClipRRect(
          borderRadius: widget.isNutritionist ? BorderRadius.circular(30) : BorderRadius.zero,
          child: Container(
            color: bg,
            child: Stack(
          children: [
            const PatternBackground(),
            SafeArea(
              child: Column(
                children: [
                   const SizedBox(height: 80), // Space for header
                   
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 22),
                     child: TabBar(
                       indicatorColor: orange, // Changed to orange
                       indicatorWeight: 3,
                       indicatorSize: TabBarIndicatorSize.tab,
                       labelColor: orange, // Changed to orange
                       unselectedLabelColor: purple.withValues(alpha: 0.5),
                       labelStyle: const TextStyle(
                         fontWeight: FontWeight.w900,
                         fontFamily: 'Satoshi',
                         fontSize: 16,
                       ),
                       unselectedLabelStyle: const TextStyle(
                         fontWeight: FontWeight.w500,
                         fontFamily: 'Satoshi',
                         fontSize: 16,
                       ),
                       tabs: const [
                         Tab(text: "Following"),
                         Tab(text: "Followers"),
                       ],
                     ),
                   ),
                   const SizedBox(height: 20),

                   Expanded(
                     child: TabBarView(
                       children: [
                         _UserList(
                           fetchFuture: _followService.getFollowingProfiles(_uid),
                           emptyMessage: "You aren't following anyone yet.",
                         ),
                         _UserList(
                           fetchFuture: _followService.getFollowerProfiles(_uid),
                           emptyMessage: "You don't have any followers yet.",
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ),

            // Fixed Header
            Positioned(
              top: 51,
              left: 22,
              right: 22,
              child: Row(
                children: [
                  BackButtonWidget(
                    color: brown,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    "My Network",
                    style: TextStyle(
                      color: purple,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Satoshi",
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

class _UserList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> fetchFuture;
  final String emptyMessage;

  const _UserList({required this.fetchFuture, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF462F4D);
    const tileBg = Color(0xFFF9E3D5);
    const bg = Color(0xFFFFF3EB);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFEF8A54)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: TextStyle(color: purple.withValues(alpha:0.6), fontFamily: "Satoshi"),
            ),
          );
        }

        final users = snapshot.data!;
        
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = users[index];
            final String name = user['fullName'] ?? 
                                user['name'] ?? 
                                user['userName'] ?? 
                                (user['email'] != null ? (user['email'] as String).split('@').first : 'User');
            final photoUrl = user['photoUrl'];
            final uid = user['uid'];
            final isFollowingTab = emptyMessage.contains("following"); // Simple check to decide button type

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthorProfileScreen(
                      authorId: uid,
                      authorName: name,
                      profileImageUrl: photoUrl,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Licensed Avatar Styling
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 5, spreadRadius: 1),
                        ],
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                            ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Image.asset("assets/Logos/profile_placeholder.png", fit: BoxFit.cover))
                            : Image.asset("assets/Logos/profile_placeholder.png", fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: "Satoshi",
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Action Button
                    if (isFollowingTab)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Unfollow logic
                            await FollowService().toggleFollow(uid, shouldFollow: false);
                            // Force rebuild/refresh - in a real app might want to remove item from list locally
                            (context as Element).markNeedsBuild(); 
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bg, // Light background
                            foregroundColor: const Color(0xFFEF8A54), // Orange text
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFEF8A54)),
                            ),
                          ),
                          child: const Text(
                            "Unfollow",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: "Satoshi"),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
