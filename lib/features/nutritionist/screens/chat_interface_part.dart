import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/meal_plan_creator.dart';
import 'package:hidden_pantry_app/features/user/screens/meal_plan_view.dart';
import 'package:intl/intl.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:hidden_pantry_app/core/services/chat_encryption_service.dart';
import 'package:hidden_pantry_app/core/services/user_status_service.dart';

class ChatInterface extends StatefulWidget {
  final String nutritionistId;
  final Map<String, dynamic> nutritionistData;
  final String? chatIdOverride;
  final String? otherUserName;
  final String? otherUserPhoto; 
  final String? clientId; 

  static const String defaultProfileUrl = "https://ui-avatars.com/api/?name=User&background=random&color=fff";

  const ChatInterface({
    super.key,
    required this.nutritionistId, 
    required this.nutritionistData,
    this.chatIdOverride,
    this.otherUserName,
    this.otherUserPhoto,
    this.clientId,
  });

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Color purple = const Color(0xFF321B3A);
  final Color orange = const Color(0xFFFF8C5A);

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _canShareMealPlans = false;
  bool _canShareSupplements = false;
  String? _myPhotoUrl;


  @override
  void initState() {
    super.initState();
    ChatEncryptionService().initializeKeys(); // Initialize E2EE
    _resetUnreadCount();
    _clearRelatedNotifications();
    _msgCtrl.addListener(_onTextChanged);
    _fetchMyProfile();
    if (_isNutritionist) {
      _checkClientBenefits();
    } else {
    }
  }

  Future<void> _checkClientBenefits() async {
    if (!_isNutritionist || widget.clientId == null) return;

    try {
      final subsSnap = await FirebaseFirestore.instance
          .collection("subscriptions")
          .where("userId", isEqualTo: widget.clientId)
          .where("nutritionistId", isEqualTo: widget.nutritionistId)
          .where("status", whereIn: ["active", "trialing"])
          .get();

      if (subsSnap.docs.isEmpty) return;

      bool mealPlans = false;
      bool supplements = false;

      for (final subDoc in subsSnap.docs) {
        final subData = subDoc.data();
        var planId = subData["planId"];

        if (planId == null) continue;

        // Try by doc ID first, then by title (planId may be stored as title)
        var planDoc = await FirebaseFirestore.instance
            .collection("nutritionists")
            .doc(widget.nutritionistId)
            .collection("subscription_plans")
            .doc(planId.toString())
            .get();

        if (!planDoc.exists) {
          final q = await FirebaseFirestore.instance
              .collection("nutritionists")
              .doc(widget.nutritionistId)
              .collection("subscription_plans")
              .where("title", isEqualTo: planId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) planDoc = q.docs.first;
        }

        if (!planDoc.exists) continue;

        final List? benefits = planDoc.data()?["benefits"];
        if (benefits == null) continue;

        for (var b in benefits) {
          final String t = (b is Map
                  ? (b["title"] ?? b["text"] ?? "")
                  : b)
              .toString()
              .toLowerCase();

          // Broad matching — covers "In-Chat Meal Plans", "inchat meal plan", "meal plan sharing" etc.
          if (t.contains("meal plan") || t.contains("inchat") || t.contains("in-chat")) {
            mealPlans = true;
          }
          if (t.contains("supplement")) {
            supplements = true;
          }
        }
      }

      // setState is required so the UI rebuilds and the + options appear
      if (mounted) {
        setState(() {
          _canShareMealPlans = mealPlans;
          _canShareSupplements = supplements;
        });
      }
    } catch (e) {
      debugPrint("Error checking client benefits: $e");
    }
  }


  void _clearRelatedNotifications() {
    NotificationService().markNotificationsForTargetAsRead(_chatId);
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _msgCtrl.text.trim();
    if (text.isNotEmpty && !_isTyping) {
      _setTypingStatus(true);
    } else if (text.isEmpty && _isTyping) {
      _setTypingStatus(false);
    }

    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isTyping) _setTypingStatus(false);
      });
    }
  }

  Future<void> _setTypingStatus(bool typing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isTyping = typing);
    
    try {
      final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);
      await chatRef.set({
        "typingStatus": {
          user.uid: typing,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating typing status: $e");
    }
  }

  Future<void> _fetchMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Nutritionists are in 'nutritionists' collection, users are in 'users' collection
      // First try to detect which one the current user is
      final nutDoc = await FirebaseFirestore.instance.collection("nutritionists").doc(user.uid).get();
      if (nutDoc.exists && mounted) {
        setState(() {
          _myPhotoUrl = nutDoc.data()?["photoUrl"] ?? nutDoc.data()?["imageUrl"];
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _myPhotoUrl = userDoc.data()?["photoUrl"] ?? userDoc.data()?["imageUrl"];
        });
      }
    } catch (e) {
      debugPrint("Error fetching my profile: $e");
    }
  }

  String get _chatId {
    if (widget.chatIdOverride != null) return widget.chatIdOverride!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return "chat_${uid}_${widget.nutritionistId}";
  }

  bool get _isNutritionist => FirebaseAuth.instance.currentUser?.uid == widget.nutritionistId;

  Future<void> _resetUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);
      final uid = user.uid;
      
      // We must ensure participants are set so security rules allow reading messages
      // participants should include both the user and the nutritionist
      final List<String> participants = [uid];
      if (_isNutritionist) {
        if (widget.clientId != null) participants.add(widget.clientId!);
      } else {
        participants.add(widget.nutritionistId);
      }

      final Map<String, dynamic> initialData = {
        "participants": FieldValue.arrayUnion(participants),
      };

      if (_isNutritionist) {
        initialData["nutritionistUnread"] = 0;
      } else {
        initialData["userUnread"] = 0;
      }

      await chatRef.set(initialData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error resetting unread count: $e");
    }
  }


  Future<void> _clearChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messagesRef = FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages");
          
      final snapshots = await messagesRef.get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();

      if (mounted) {
        Toaster.show(context, "Chat history cleared.");
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error clearing chat: $e", isError: true);
      }
    }
  }

  void _confirmClearChat() {
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF3EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear Chat", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Text(
          "Are you sure you want to delete all messages in this conversation? This action cannot be undone.",
          style: TextStyle(color: purple.withValues(alpha:0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6), fontWeight: FontWeight.w600, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sw)),
            ),
            child: Text("Clear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    // 1. Determine title & photo
    final String title = widget.otherUserName ?? widget.nutritionistData["fullName"] ?? "Chat";
    String photoUrl = widget.otherUserPhoto ?? widget.nutritionistData["photoUrl"] ?? widget.nutritionistData["imageUrl"] ?? "";
    if (photoUrl.isEmpty) photoUrl = ChatInterface.defaultProfileUrl;
    

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
             margin: EdgeInsets.all(8.sw),
             alignment: Alignment.center,
             child: Icon(Icons.arrow_back_rounded, color: const Color(0xFF462F4D), size: 24.sw),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.sw),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: orange.withValues(alpha:0.3), width: 1.5.sw),
              ),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 18.sw,
                    backgroundColor: purple.withValues(alpha:0.1),
                    child: ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 36.sw,
                        height: 36.sw,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.network(
                          "${ChatInterface.defaultProfileUrl}&name=${Uri.encodeComponent(title)}",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: UserStatusService().getStatusStream(
                      _isNutritionist ? (widget.clientId ?? "") : widget.nutritionistId,
                      !_isNutritionist,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final bool isOnline = data['isOnline'] ?? false;
                      if (!isOnline) return const SizedBox.shrink();

                      return Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10.sw,
                          height: 10.sw,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.sw),
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
                    title,
                    style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: UserStatusService().getStatusStream(
                      _isNutritionist ? (widget.clientId ?? "") : widget.nutritionistId,
                      !_isNutritionist, // If I'm NOT a nutritionist, I'm looking for a nutritionist's status
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final bool isOnline = data['isOnline'] ?? false;
                      final Timestamp? lastSeen = data['lastSeen'] as Timestamp?;

                      if (isOnline) {
                        return Text(
                          "Online",
                          style: TextStyle(color: Colors.green, fontSize: 10.sp, fontWeight: FontWeight.bold),
                        );
                      } else {
                        String lastSeenText = "Offline";
                        if (lastSeen != null) {
                          final DateTime lastSeenDate = lastSeen.toDate();
                          final now = DateTime.now();
                          final diff = now.difference(lastSeenDate);

                          if (diff.inMinutes < 1) {
                            lastSeenText = "Last seen just now";
                          } else if (diff.inMinutes < 60) {
                            lastSeenText = "Last seen ${diff.inMinutes}m ago";
                          } else if (diff.inHours < 24) {
                            lastSeenText = "Last seen ${diff.inHours}h ago";
                          } else {
                            lastSeenText = "Last seen ${DateFormat('MMM d, HH:mm').format(lastSeenDate)}";
                          }
                        }
                        return Text(
                          lastSeenText,
                          style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.bold),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: purple),
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearChat();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20.sw),
                    SizedBox(width: 8.sw),
                    Text("Clear Chat", style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFF7F2),
      body: Stack(
        children: [
          const PatternBackground(opacity: 0.5),
          Column(
            children: [
              SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
              // Encryption notice
              Container(
                margin: EdgeInsets.symmetric(vertical: 8.sh),
                padding: EdgeInsets.symmetric(vertical: 6.sh, horizontal: 16.sw),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(20.sw),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: purple.withValues(alpha:0.4), size: 10.sp),
                    SizedBox(width: 6.sw),
                    Text(
                      "Messages are end-to-end encrypted",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 9.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("chats")
                        .doc(_chatId)
                        .collection("messages")
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Error loading chats"));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final allDocs = snapshot.data!.docs;
                      // Filter docs: exclude if deletedBy contains me
                      final meId = FirebaseAuth.instance.currentUser?.uid;
                      final docs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedBy = List<String>.from(data["deletedBy"] ?? []);
                        return !deletedBy.contains(meId);
                      }).toList();

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            "Start the conversation!",
                            style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 16.sp),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 20.sh),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          final isMe = data["senderId"] == FirebaseAuth.instance.currentUser?.uid;

                          return _FadeSlideEntry(
                            delayMs: index * 50, // Slight stagger
                            child: _buildMessageItem(data, isMe, docId),
                          );
                        },
                      );
                    },
                  ),
              ),
              // Typing Indicator
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("chats").doc(_chatId).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
                  final data = snap.data!.data() as Map<String, dynamic>;
                  final typingMap = data["typingStatus"] as Map<String, dynamic>?;
                  if (typingMap == null) return const SizedBox.shrink();

                  // Find other participant's typing status
                  bool isOtherTyping = false;
                  typingMap.forEach((uid, isT) {
                    if (uid != FirebaseAuth.instance.currentUser?.uid && isT == true) {
                      isOtherTyping = true;
                    }
                  });

                  if (!isOtherTyping) return const SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.only(left: 16.sw, bottom: 8.sh),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.sw),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4.sw)],
                          ),
                          child: Row(
                            children: [
                              Text(
                                "typing",
                                style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 11.sp, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4.sw),
                              _dotAnimation(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
              // Input bar
                Container(
                  padding: EdgeInsets.fromLTRB(16.sw, 12.sh, 16.sw, MediaQuery.of(context).padding.bottom + 12.sh),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24.sw)),
                    boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 15.sw, offset: Offset(0, -5.sh))],
                  ),
                  child: Row(
                    children: [
                      if (_isNutritionist) ...[
                        GestureDetector(
                          onTap: () => _showActionSheet(),
                          child: Container(
                            width: 44.sw,
                            height: 44.sw,
                            decoration: BoxDecoration(
                              color: orange.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(14.sw),
                            ),
                            child: Icon(Icons.add_rounded, color: orange, size: 24.sw),
                          ),
                        ),
                        SizedBox(width: 12.sw),
                      ],
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9E3D5).withValues(alpha:0.4),
                            borderRadius: BorderRadius.circular(18.sw),
                          ),
                          child: TextField(
                            controller: _msgCtrl,
                            style: TextStyle(fontSize: 14.sp, color: purple, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: TextStyle(color: purple.withValues(alpha:0.3), fontSize: 14.sp),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.sw, vertical: 12.sh),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.sw),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 44.sw,
                          height: 44.sw,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [orange, const Color(0xFFE48E5B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14.sw),
                            boxShadow: [
                              BoxShadow(
                                color: orange.withValues(alpha:0.3),
                                blurRadius: 8.sw,
                                offset: Offset(0, 3.sh),
                              ),
                            ],
                          ),
                          child: Icon(Icons.send_rounded, color: Colors.white, size: 18.sw),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  void _showActionSheet() {
    final actions = [
      if (_canShareMealPlans) ...[
        {"icon": Icons.restaurant_menu_rounded, "title": "Create New Meal Plan", "subtitle": "Design a custom plan for your client", "color": const Color(0xFFFF8C5A)},
        {"icon": Icons.bookmark_rounded, "title": "Share Saved Meal Plans", "subtitle": "Send from your existing plans library", "color": const Color(0xFF7B61FF)},
      ],
      if (_canShareSupplements)
        {"icon": Icons.medical_services_rounded, "title": "Share Supplement Guide", "subtitle": "Send personalized recommendations", "color": const Color(0xFF00C853)},
      {"icon": Icons.calendar_month_rounded, "title": "Schedule Meeting", "subtitle": "Set up a consultation session", "color": const Color(0xFF2979FF)},
      {"icon": Icons.attach_file_rounded, "title": "Attach File", "subtitle": "Send documents, images, or reports", "color": const Color(0xFF795548)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 20.sw),
        decoration: BoxDecoration(
          color: const Color(0xFF321B3A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.sw)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.sh),
            Container(
              width: 50.sw,
              height: 4.sh,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.sw),
              ),
            ),
            SizedBox(height: 32.sh),
            Row(
              children: [
                Text(
                  "Quick Actions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Satoshi",
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.sh),
            ...List.generate(actions.length, (i) {
              final action = actions[i];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (i * 100)),
                curve: Curves.easeOutQuint,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Container(
                  margin: EdgeInsets.only(bottom: 12.sh),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20.sw),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.sw),
                      onTap: () {
                        Navigator.pop(context);
                        if (action["title"] == "Create New Meal Plan") {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanCreatorScreen()));
                        } else if (action["title"] == "Schedule Meeting") {
                          _showScheduleMeetingDialog();
                        } else if (action["title"] == "Share Saved Meal Plans") {
                          _showSavedPlansSheet();
                        } else if (action["title"] == "Share Supplement Guide") {
                          _sendSupplementGuide();
                        } else {
                          Toaster.show(context, "${action["title"]} coming soon!");
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.all(16.sw),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.sw),
                              decoration: BoxDecoration(
                                color: (action["color"] as Color).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16.sw),
                              ),
                              child: Icon(action["icon"] as IconData, color: action["color"] as Color, size: 24.sw),
                            ),
                            SizedBox(width: 16.sw),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action["title"] as String,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                  SizedBox(height: 2.sh),
                                  Text(
                                    action["subtitle"] as String,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 12.sp,
                                      fontFamily: "Satoshi",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24.sh),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Reset typing status immediately
    _setTypingStatus(false);
    _typingTimer?.cancel();

    _msgCtrl.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);
    
    // Determine update logic based on who is sending
    final Map<String, dynamic> updateData = {
      "lastMessage": text,
      "lastMessageTime": FieldValue.serverTimestamp(),
    };
    
    // If we are nutritionist, we set userUnread + 1, and reset nutritionistUnread
    // If we are user, we set nutritionistUnread + 1, and reset userUnread
    // Always ensure participants are properly set/merged for both parties
    updateData["participants"] = FieldValue.arrayUnion([user.uid, widget.nutritionistId, widget.clientId ?? ""]);

    if (_isNutritionist) {
       updateData["userUnread"] = FieldValue.increment(1);
       updateData["nutritionistUnread"] = 0;
    } else {
       updateData["nutritionistUnread"] = FieldValue.increment(1);
       updateData["userUnread"] = 0;
    }

    await chatRef.set(updateData, SetOptions(merge: true));

    // Encryption Layer
    final recipientId = _isNutritionist ? widget.clientId : widget.nutritionistId;
    if (recipientId != null) {
      final encryptedData = await ChatEncryptionService().encryptMessage(text, recipientId);
      debugPrint("Encryption check: key matches ${encryptedData['serverKeyMatch']}");
      
      await chatRef.collection("messages").add({
        "text": encryptedData['isEncrypted'] == 'true' ? "[Encrypted]" : text, // Fallback for old apps
        "cipherText": encryptedData['cipherText'],
        "encryptedKey": encryptedData['encryptedKey'],
        "senderEncryptedKey": encryptedData['senderEncryptedKey'], // Added for self-decryption
        "isEncrypted": encryptedData['isEncrypted'],
        "senderId": user.uid,
        "timestamp": FieldValue.serverTimestamp(),
      });
    }

    // Trigger Notification
    if (recipientId != null && recipientId.isNotEmpty) {
      String senderName = user.displayName ?? "";
      
      // If display name is missing, fetch from Firestore
      if (senderName.isEmpty) {
        try {
          final collection = _isNutritionist ? 'nutritionists' : 'users';
          final doc = await FirebaseFirestore.instance.collection(collection).doc(user.uid).get();
          final data = doc.data();
          if (data != null) {
            senderName = data['fullName'] ?? data['name'] ?? data['userName'] ?? "";
          }
        } catch (_) {}
      }

      if (senderName.isEmpty) {
        senderName = _isNutritionist ? "Nutritionist" : "User";
      }

      NotificationService().sendNotification(
        recipientId: recipientId,
        title: "New Message from $senderName",
        body: "[Encrypted Message]", // Hide content for E2EE privacy
        type: NotificationType.chat_message,
        targetId: _chatId,
        recipientRole: _isNutritionist ? 'user' : 'nutritionist',
      );
    }
  }


  Widget _dotAnimation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => _SingleDot(delay: i * 200)),
    );
  }

  Future<void> _deleteMessageForMe(String docId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages")
          .doc(docId)
          .update({
        "deletedBy": FieldValue.arrayUnion([uid])
      });
      if (mounted) Toaster.show(context, "Message deleted for you");
    } catch (e) {
      if (mounted) Toaster.show(context, "Failed to delete message: $e", isError: true);
    }
  }

  Future<void> _deleteMessageForEveryone(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages")
          .doc(docId)
          .delete();
      if (mounted) Toaster.show(context, "Message deleted for everyone");
    } catch (e) {
      if (mounted) Toaster.show(context, "Failed to delete message: $e", isError: true);
    }
  }

  void _showDeleteOptions(String docId, bool isMe) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => _DeleteMessageDialog(
        isMe: isMe,
        onDeleteForMe: () => _deleteMessageForMe(docId),
        onDeleteForEveryone: () => _deleteMessageForEveryone(docId),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }


  Widget _buildMessageItem(Map<String, dynamic> data, bool isMe, String docId) {
    Widget child;
    if (data["type"] == "meeting") {
      child = _buildMeetingCard(data, isMe);
    } else if (data["type"] == "meal_plan") {
      child = _buildMealPlanCard(data, isMe);
    } else {
      // Default Text Message
      child = Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6.sh),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22.sw),
              topRight: Radius.circular(22.sw),
              bottomLeft: Radius.circular(isMe ? 22.sw : 4.sw),
              bottomRight: Radius.circular(isMe ? 4.sw : 22.sw),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe ? orange.withValues(alpha:0.15) : Colors.black.withValues(alpha:0.04),
                blurRadius: 10.sw,
                offset: Offset(0, 4.sh),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22.sw),
              topRight: Radius.circular(22.sw),
              bottomLeft: Radius.circular(isMe ? 22.sw : 4.sw),
              bottomRight: Radius.circular(isMe ? 4.sw : 22.sw),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.sw, vertical: 12.sh),
                decoration: BoxDecoration(
                  gradient: isMe 
                    ? LinearGradient(
                        colors: [orange, const Color(0xFFE48E5B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white.withValues(alpha:0.9), Colors.white.withValues(alpha:0.7)],
                      ),
                  border: Border.all(
                    color: isMe ? Colors.white.withValues(alpha:0.2) : Colors.white.withValues(alpha:0.8),
                    width: 1.sw,
                  ),
                ),
                child: _DecryptedMessage(
                  data: data,
                  style: TextStyle(
                    color: isMe ? Colors.white : purple,
                    fontSize: 14.5.sp,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        _showDeleteOptions(docId, isMe);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.sh),
        child: child,
      ),
    );
  }

  void _addToCalendar(DateTime date, String time, String notes) async {
    try {
      // Robustly parse the time string (e.g., "10:30 AM", "14:00")
      final regex = RegExp(r'(\d+):(\d+)\s*([a|p]m)?', caseSensitive: false);
      final match = regex.firstMatch(time);
      
      int hour = 10; // Defaults
      int minute = 0;
      
      if (match != null) {
         hour = int.tryParse(match.group(1) ?? "10") ?? 10;
         minute = int.tryParse(match.group(2) ?? "0") ?? 0;
         final period = match.group(3)?.toLowerCase();
         
         if (period == 'pm' && hour < 12) hour += 12;
         if (period == 'am' && hour == 12) hour = 0;
      }
      
      final startTime = DateTime(date.year, date.month, date.day, hour, minute);
      final endTime = startTime.add(const Duration(hours: 1)); // Default 1 hour meeting

      final Event event = Event(
        title: 'Nutritionist Consultation',
        description: notes,
        location: 'In-app Chat / Google Meet',
        startDate: startTime,
        endDate: endTime,
        iosParams: const IOSParams(
          reminder: Duration(minutes: 30),
          url: 'https://hiddenpantry.app',
        ),
        androidParams: const AndroidParams(
          emailInvites: [], // can add client email here if available
        ),
      );

      Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      if (mounted) Toaster.show(context, "Error opening calendar app: $e", isError: true);
    }
  }

  Widget _buildMeetingCard(Map<String, dynamic> data, bool isMe) {
    // Handling Timestamp or String
    DateTime? date;
    if (data["meetingDate"] is Timestamp) {
      date = (data["meetingDate"] as Timestamp).toDate();
    } else if (data["meetingDate"] is String) {
      // Fallback if stored as string
      try {
        date = DateTime.parse(data["meetingDate"]);
      } catch (_) {}
    }

    final time = data["meetingTime"] as String?;
    final notes = data["notes"] as String?;
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : "Unknown Date";
    
    // Bubble Colors styling based on sender (Matching Meal Plan Card)
    final bgColor = isMe ? const Color(0xFFE48E5B).withValues(alpha:0.15) : Colors.white;
    final textColor = purple;
    final subheadColor = purple.withValues(alpha:0.7);
    final borderColor = isMe ? const Color(0xFFE48E5B).withValues(alpha:0.5) : const Color(0xFFE48E5B).withValues(alpha:0.3);
    
    // Button styling
    final btnBgColor = const Color(0xFFE48E5B);
    final btnTextColor = Colors.white;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280.sw,
        margin: EdgeInsets.symmetric(vertical: 8.sh),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.sw),
            topRight: Radius.circular(24.sw),
            bottomLeft: Radius.circular(isMe ? 24.sw : 4.sw),
            bottomRight: Radius.circular(isMe ? 4.sw : 24.sw),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(18.sw),
              decoration: BoxDecoration(
                color: isMe 
                  ? orange.withValues(alpha: 0.12) 
                  : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.sw),
                  topRight: Radius.circular(24.sw),
                  bottomLeft: Radius.circular(isMe ? 24.sw : 4.sw),
                  bottomRight: Radius.circular(isMe ? 4.sw : 24.sw),
                ),
                border: Border.all(
                  color: isMe 
                    ? orange.withValues(alpha: 0.3) 
                    : Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.sw),
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.videocam_rounded, color: orange, size: 18.sw),
                      ),
                      SizedBox(width: 12.sw),
                      Expanded(
                        child: Text(
                          "Consultation",
                          style: TextStyle(
                            color: purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.sh),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: purple,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4.sh),
                  Text(
                    time ?? "TBD",
                    style: TextStyle(
                      color: purple.withValues(alpha: 0.6),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    SizedBox(height: 12.sh),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 8.sh),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12.sw),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          color: purple.withValues(alpha: 0.7),
                          fontSize: 12.sp,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 20.sh),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (date != null && time != null) {
                          _addToCalendar(date, time, notes ?? "");
                        } else {
                          Toaster.show(context, "Missing valid date or time", isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.sh),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Add to Calendar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showScheduleMeetingDialog() async {
    final actionOrange = const Color(0xFFE48E5B);
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: actionOrange, onPrimary: Colors.white, onSurface: purple),
          ),
          child: child!,
        );
      },
    );
    if (selectedDate == null) return;

    if (!mounted) return;
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
       builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: actionOrange, onPrimary: Colors.white, onSurface: purple),
          ),
          child: child!,
        );
      },
    );
    if (selectedTime == null) return;

    final TextEditingController notesCtrl = TextEditingController();
    
    if (!mounted) return;
    await GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Notes (Optional)", style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: notesCtrl,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: "Meeting topic...",
            hintStyle: TextStyle(fontSize: 14.sp),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.sw)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Skip", style: TextStyle(color: purple.withValues(alpha:0.6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMeetingMessage(selectedDate, selectedTime, notesCtrl.text);
            },
            child: Text("Confirm", style: TextStyle(color: actionOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendMeetingMessage(DateTime date, TimeOfDay time, String notes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);
    final timeStr = time.format(context);

    // Determine update logic based on who is sending
    final Map<String, dynamic> updateData = {
      "lastMessage": "📅 Meeting Scheduled",
      "lastMessageTime": FieldValue.serverTimestamp(),
    };
    
    if (_isNutritionist) {
       updateData["userUnread"] = FieldValue.increment(1);
       updateData["nutritionistUnread"] = 0;
    } else {
       updateData["nutritionistUnread"] = FieldValue.increment(1);
       updateData["userUnread"] = 0;
       updateData["participants"] = FieldValue.arrayUnion([user.uid, widget.nutritionistId]); 
    }

    await chatRef.set(updateData, SetOptions(merge: true));

    await chatRef.collection("messages").add({
      "type": "meeting",
      "senderId": user.uid,
      "text": "Scheduled a meeting",
      "meetingDate": Timestamp.fromDate(date),
      "meetingTime": timeStr,
      "notes": notes,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Trigger Notification for meeting
    final recipientId = _isNutritionist ? widget.clientId : widget.nutritionistId;
    if (recipientId != null && recipientId.isNotEmpty) {
      String senderName = user.displayName ?? "";
      if (senderName.isEmpty) senderName = _isNutritionist ? "Nutritionist" : "User";

      NotificationService().sendNotification(
        recipientId: recipientId,
        title: "Meeting Scheduled with $senderName",
        body: notes.isNotEmpty ? notes : "A new consultation was scheduled.",
        type: NotificationType.chat_message,
        targetId: _chatId,
        recipientRole: _isNutritionist ? 'user' : 'nutritionist',
      );
    }
  }


  void _showSavedPlansSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final actionOrange = const Color(0xFFE48E5B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3EB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.sw)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              width: 50, height: 5,
              decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3)),
            ),
            Text("Select Plan to Share", style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("nutritionists")
                    .doc(user.uid)
                    .collection("meal_plans")
                    .orderBy("updatedAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading plans"));
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: actionOrange));
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("No saved plans found"));

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;
                      final title = data["title"] ?? "Untitled Plan";
                      final days = data["duration"] ?? 0;

                      // Compute avg daily calories from actual days data
                      int avgCals = 0;
                      final List daysList = data["days"] is List ? data["days"] as List : [];
                      if (daysList.isNotEmpty) {
                        int totalCals = 0;
                        int dayCount = 0;
                        for (final day in daysList) {
                          if (day is Map) {
                            final List meals = day["meals"] is List ? day["meals"] as List : [];
                            int dayCals = 0;
                            for (final meal in meals) {
                              if (meal is Map) {
                                // Prefer nutrition['Calories'] string (per-serving, e.g. "250 kcal")
                                int mealCal = 0;
                                final nutrition = meal["nutrition"];
                                if (nutrition is Map) {
                                  final calStr = (nutrition["Calories"] ?? nutrition["calories"] ?? "").toString();
                                  final match = RegExp(r'(\d+\.?\d*)').firstMatch(calStr);
                                  if (match != null) mealCal = double.tryParse(match.group(1)!)?.round() ?? 0;
                                }
                                // Fallback: raw calories field ÷ servings
                                if (mealCal == 0) {
                                  final rawCal = ((meal["calories"] as num?) ?? 0).toDouble();
                                  final servings = ((meal["base_servings"] ?? meal["baseServings"] ?? meal["servings"] ?? 1) as num).toInt().clamp(1, 100);
                                  mealCal = (rawCal / servings).round();
                                }
                                dayCals += mealCal;
                              }
                            }
                            if (dayCals > 0) {
                              totalCals += dayCals;
                              dayCount++;
                            }
                          }
                        }
                        if (dayCount > 0) avgCals = (totalCals / dayCount).round();
                      }
                      // Fallback to targetCalories if no per-meal cal data
                      if (avgCals == 0) avgCals = (data["targetCalories"] as num?)?.toInt() ?? 0;
                      final String calLabel = avgCals > 0 ? "~ $avgCals kcal/day avg" : "Calories not set";


                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close sheet
                          _sendMealPlanMessage({...data, "planId": id});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9E3D5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 4, offset:const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: actionOrange.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),

                                child: Icon(Icons.restaurant_menu_rounded, color: actionOrange),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("$days Days • $calLabel", style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: actionOrange, size: 20),
                                    onPressed: () {
                                      Navigator.pop(context); // Close sheet
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MealPlanCreatorScreen(
                                            existingPlanId: id,
                                            initialData: data,
                                          ),
                                        ),
                                      );
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.send_rounded, color: actionOrange, size: 20),
                                    onPressed: () {
                                      Navigator.pop(context); // Close sheet
                                      _sendMealPlanMessage({...data, "planId": id});
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMealPlanMessage(Map<String, dynamic> planData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);

    final Map<String, dynamic> updateData = {
      "lastMessage": "🍽️ Shared a Meal Plan",
      "lastMessageTime": FieldValue.serverTimestamp(),
    };

    if (_isNutritionist) {
       updateData["userUnread"] = FieldValue.increment(1);
       updateData["nutritionistUnread"] = 0;
    } else {
       updateData["nutritionistUnread"] = FieldValue.increment(1);
       updateData["userUnread"] = 0;
    }

    await chatRef.set(updateData, SetOptions(merge: true));

    // Add message
    await chatRef.collection("messages").add({
      "type": "meal_plan",
      "senderId": user.uid,
      "text": "Shared a meal plan: ${planData["title"]}",
      "mealPlanData": planData,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Trigger Notification for meal plan
    final recipientId = _isNutritionist ? widget.clientId : widget.nutritionistId;
    if (recipientId != null && recipientId.isNotEmpty) {
      String senderName = user.displayName ?? "";
      if (senderName.isEmpty) senderName = _isNutritionist ? "Nutritionist" : "User";

      NotificationService().sendNotification(
        recipientId: recipientId,
        title: "New Meal Plan from $senderName",
        body: planData["title"] ?? "Meal Plan",
        type: NotificationType.chat_message,
        targetId: _chatId,
        recipientRole: _isNutritionist ? 'user' : 'nutritionist',
      );
    }
  }

  void _sendSupplementGuide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final chatRef = FirebaseFirestore.instance.collection("chats").doc(_chatId);

    final Map<String, dynamic> updateData = {
      "lastMessage": "💊 Shared Supplement Guide",
      "lastMessageTime": FieldValue.serverTimestamp(),
      "userUnread": FieldValue.increment(1),
      "nutritionistUnread": 0,
    };

    await chatRef.set(updateData, SetOptions(merge: true));

    await chatRef.collection("messages").add({
      "type": "supplement_guide",
      "senderId": user.uid,
      "text": "Sent a supplement guide request",
      "timestamp": FieldValue.serverTimestamp(),
    });

    if (mounted) Toaster.show(context, "Supplement guide request sent");
  }

  Widget _buildMealPlanCard(Map<String, dynamic> data, bool isMe) {
    // Handling different payload formats
    final plan = data["planData"] as Map<String, dynamic>? ?? 
                 data["mealPlanData"] as Map<String, dynamic>? ?? {};
                 
    final title = plan["title"] ?? "Meal Plan";
    final days = plan["duration"] ?? "?";
    final cals = plan["targetCalories"] ?? "?";
    
    // Extract cover image from the first meal if available
    String? coverImage;
    final planDays = plan["days"] as List<dynamic>? ?? [];
    if (planDays.isNotEmpty) {
      final firstDayMeals = planDays.first["meals"] as List<dynamic>? ?? [];
      if (firstDayMeals.isNotEmpty) {
         coverImage = firstDayMeals.first["imageUrl"];
      }
    }

    // Bubble Colors styling based on sender
    final bgColor = isMe ? const Color(0xFFE48E5B).withValues(alpha:0.15) : Colors.white;
    final textColor = purple;
    final subheadColor = purple.withValues(alpha:0.7);
    final borderColor = isMe ? const Color(0xFFE48E5B).withValues(alpha:0.5) : const Color(0xFFE48E5B).withValues(alpha:0.3);
    
    // Button styling
    final btnBgColor = isMe ? const Color(0xFFE48E5B) : const Color(0xFFE48E5B);
    final btnTextColor = Colors.white;
    
    final buttonText = _isNutritionist ? "Tap to View" : "Tap to View & Save";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280.sw,
        margin: EdgeInsets.symmetric(vertical: 8.sh),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.sw),
            topRight: Radius.circular(24.sw),
            bottomLeft: Radius.circular(isMe ? 24.sw : 4.sw),
            bottomRight: Radius.circular(isMe ? 4.sw : 24.sw),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isMe 
                  ? orange.withValues(alpha: 0.1) 
                  : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.sw),
                  topRight: Radius.circular(24.sw),
                  bottomLeft: Radius.circular(isMe ? 24.sw : 4.sw),
                  bottomRight: Radius.circular(isMe ? 4.sw : 24.sw),
                ),
                border: Border.all(
                  color: isMe 
                    ? orange.withValues(alpha: 0.2) 
                    : Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Image / Title Section
                  if (coverImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24.sw),
                            topRight: Radius.circular(24.sw),
                          ),
                          child: Image.network(
                            coverImage,
                            height: 120.sh,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 120.sh,
                              color: orange.withValues(alpha: 0.1),
                              child: Icon(Icons.restaurant_menu_rounded, color: orange, size: 40.sw),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10.sh,
                          right: 10.sw,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20.sw),
                            ),
                            child: Text(
                              "Meal Plan",
                              style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  Padding(
                    padding: EdgeInsets.all(16.sw),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: purple,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 12.sh),
                        Row(
                          children: [
                            _statChip(Icons.calendar_today_rounded, "$days Days"),
                            SizedBox(width: 8.sw),
                            _statChip(Icons.local_fire_department_rounded, "$cals kcal"),
                          ],
                        ),
                        SizedBox(height: 20.sh),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final pId = plan["planId"] ?? plan["id"];
                              if (pId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MealPlanViewScreen(
                                      planData: plan,
                                      isViewingSavedPlan: true,
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.sh),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.sw)),
                              elevation: 0,
                            ),
                            child: Text(
                              buttonText,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.sw, vertical: 4.sh),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.sw),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sw, color: purple.withValues(alpha: 0.6)),
          SizedBox(width: 4.sw),
          Text(
            label,
            style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 11.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _DecryptedMessage extends StatelessWidget {
  final Map<String, dynamic> data;
  final TextStyle style;
  const _DecryptedMessage({required this.data, required this.style});

  @override
  Widget build(BuildContext context) {
    // If not encrypted, return plain text
    if (data['isEncrypted'] != 'true') {
      return Text(data['text'] ?? "", style: style);
    }

    return FutureBuilder<String>(
      future: ChatEncryptionService().decryptMessage(data),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 20.sw,
            height: 10.sh,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                style.color!.withValues(alpha:0.3),
              ),
            ),
          );
        }
        return Text(snapshot.data ?? "[Encrypted]", style: style);
      },
    );
  }
}

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, this.delayMs = 0});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _SingleDot extends StatefulWidget {
  final int delay;
  const _SingleDot({required this.delay});

  @override
  State<_SingleDot> createState() => _SingleDotState();
}

class _SingleDotState extends State<_SingleDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        width: 3, height: 3,
        decoration: BoxDecoration(
          color: const Color(0xFF462F4D).withValues(alpha:0.3 + (0.7 * _ctrl.value)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DeleteMessageDialog extends StatelessWidget {
  final bool isMe;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;

  const _DeleteMessageDialog({
    required this.isMe,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
  });

  @override
  Widget build(BuildContext context) {
    final Color purple = const Color(0xFF321B3A);
    final Color orange = const Color(0xFFFF8C5A);

    return Center(
      child: Container(
        margin: EdgeInsets.all(32.sw),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32.sw),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(24.sw),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EB).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(32.sw),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48.sw,
                      height: 48.sw,
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_sweep_rounded, color: orange, size: 28.sw),
                    ),
                    SizedBox(height: 16.sh),
                    Text(
                      "Delete Message",
                      style: TextStyle(
                        color: purple,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    SizedBox(height: 8.sh),
                    Text(
                      "Are you sure you want to remove this message? This action cannot be undone.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: purple.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                        fontFamily: "Satoshi",
                      ),
                    ),
                    SizedBox(height: 24.sh),
                    _FadeSlideEntry(
                      delayMs: 100,
                      child: _dialogButton(
                        label: "Delete for me",
                        icon: Icons.person_outline_rounded,
                        color: purple,
                        onTap: () {
                          Navigator.pop(context);
                          onDeleteForMe();
                        },
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(height: 12.sh),
                      _FadeSlideEntry(
                        delayMs: 200,
                        child: _dialogButton(
                          label: "Delete for everyone",
                          icon: Icons.public_rounded,
                          color: const Color(0xFFFD3250),
                          onTap: () {
                            Navigator.pop(context);
                            onDeleteForEveryone();
                          },
                          isFilled: true,
                        ),
                      ),
                    ],
                    SizedBox(height: 12.sh),
                    _FadeSlideEntry(
                      delayMs: 300,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 16.sh),
                          alignment: Alignment.center,
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: purple.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                        ),
                      ),
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

  Widget _dialogButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFilled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.sh, horizontal: 20.sw),
        decoration: BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.sw),
          border: Border.all(color: color.withValues(alpha: isFilled ? 0 : 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isFilled ? Colors.white : color, size: 20.sw),
            SizedBox(width: 12.sw),
            Text(
              label,
              style: TextStyle(
                color: isFilled ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                fontFamily: "Satoshi",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
