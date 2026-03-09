import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/user/services/follow_service.dart';
import 'package:hidden_pantry_app/features/recipes/screens/author_profile.dart'; // Assuming this exists or similar
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

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
    ResponsiveUtils.init(context);
    final topPad = MediaQuery.of(context).padding.top;
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
          borderRadius: widget.isNutritionist ? BorderRadius.circular(30.sw) : BorderRadius.zero,
          child: Container(
            color: bg,
            child: Stack(
          children: [
            const PatternBackground(),
            SafeArea(
              child: Column(
                children: [
                   SizedBox(height: 96.sh), // Standardized gap for fixed header
                   
                   Padding(
                     padding: EdgeInsets.symmetric(horizontal: 22.sw),
                     child: TabBar(
                       indicatorColor: orange, // Changed to orange
                       indicatorWeight: 3.sw,
                       indicatorSize: TabBarIndicatorSize.tab,
                       labelColor: orange, // Changed to orange
                       unselectedLabelColor: purple.withValues(alpha: 0.5),
                       labelStyle: TextStyle(
                         fontWeight: FontWeight.w900,
                         fontFamily: 'Satoshi',
                         fontSize: 16.sp,
                       ),
                       unselectedLabelStyle: TextStyle(
                         fontWeight: FontWeight.w500,
                         fontFamily: 'Satoshi',
                         fontSize: 16.sp,
                       ),
                       tabs: const [
                         Tab(text: "Following"),
                         Tab(text: "Followers"),
                       ],
                     ),
                   ),
                   SizedBox(height: 20.sh),

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
              top: topPad + 36.sh,
              left: 22.sw,
              right: 22.sw,
              child: Row(
                children: [
                  BackButtonWidget(
                    color: brown,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    "My Network",
                    style: TextStyle(
                      color: purple,
                      fontSize: 24.sp,
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

class _UserList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> fetchFuture;
  final String emptyMessage;

  const _UserList({required this.fetchFuture, required this.emptyMessage});

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> {
  List<Map<String, dynamic>>? _users;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await widget.fetchFuture;
      if (mounted) setState(() { _users = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _users = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF462F4D);
    const tileBg = Color(0xFFF9E3D5);
    const bg = Color(0xFFFFF3EB);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFEF8A54)));
    }
    if (_users == null || _users!.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: TextStyle(color: purple.withValues(alpha: 0.6), fontFamily: "Satoshi", fontSize: 14.sp),
        ),
      );
    }

    final users = _users!;

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 22.sw),
      itemCount: users.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.sh),
      itemBuilder: (context, index) {
        final user = users[index];
        final String name = user['fullName'] ??
            user['name'] ??
            user['userName'] ??
            (user['email'] != null ? (user['email'] as String).split('@').first : 'User');
        final photoUrl = user['photoUrl'];
        final uid = user['uid'];
        final isFollowingTab = widget.emptyMessage.contains("following");

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
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(20.sw),
            ),
            child: Row(
              children: [
                Container(
                  width: 50.sw,
                  height: 50.sw,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.sw),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5.sw, spreadRadius: 1.sw),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset("assets/logos/profile_placeholder.png", fit: BoxFit.cover))
                        : Image.asset("assets/logos/profile_placeholder.png", fit: BoxFit.cover),
                  ),
                ),
                SizedBox(width: 16.sw),

                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      fontFamily: "Satoshi",
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isFollowingTab)
                  SizedBox(
                    height: 36.sh,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FollowService().toggleFollow(uid, shouldFollow: false);
                        // Remove user from local list immediately
                        if (mounted) {
                          setState(() {
                            _users!.removeAt(index);
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: const Color(0xFFEF8A54),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16.sw),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.sw),
                          side: BorderSide(color: const Color(0xFFEF8A54), width: 1.sw),
                        ),
                      ),
                      child: Text(
                        "Unfollow",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, fontFamily: "Satoshi"),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

