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
import 'dart:async';

class ChatInterface extends StatefulWidget {
  final String nutritionistId;
  final Map<String, dynamic> nutritionistData;
  final String? chatIdOverride;
  final String? otherUserName;
  final String? otherUserPhoto; // NEW
  final String? clientId; // NEW: The user UID when a nutritionist is chatting

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
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _canShareMealPlans = false;
  bool _canShareSupplements = false;


  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
    _clearRelatedNotifications();
    _msgCtrl.addListener(_onTextChanged);
    if (_isNutritionist) {
      _checkClientBenefits();
    } else {
    }
  }

  Future<void> _checkClientBenefits() async {
    if (!_isNutritionist || widget.clientId == null) {
      return;
    }

    try {
      final subsSnap = await FirebaseFirestore.instance
          .collection("subscriptions")
          .where("userId", isEqualTo: widget.clientId)
          .where("nutritionistId", isEqualTo: widget.nutritionistId)
          .where("status", whereIn: ["active", "trialing"])
          .get();

      if (subsSnap.docs.isNotEmpty) {
        final subData = subsSnap.docs.first.data();
        final planId = subData["planId"];
        
        if (planId != null) {
          final planDoc = await FirebaseFirestore.instance
              .collection("nutritionists")
              .doc(widget.nutritionistId)
              .collection("subscription_plans")
              .doc(planId)
              .get();

          if (planDoc.exists) {
            final List? benefits = planDoc.data()?["benefits"];
            if (benefits != null) {
              for (var b in benefits) {
                final String title = (b is Map ? (b["title"] ?? b["text"] ?? "") : b).toString().toLowerCase();
                if (title.contains("inchat meal plans")) _canShareMealPlans = true;
                if (title.contains("supplement guide")) _canShareSupplements = true;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking client benefits: $e");
    } finally {
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
      if (_isNutritionist) {
        await chatRef.update({"nutritionistUnread": 0});
      } else {
        await chatRef.update({"userUnread": 0});
      }
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
    showDialog(
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
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha:0.6), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Clear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine title & photo
    final String title = widget.otherUserName ?? widget.nutritionistData["fullName"] ?? "Chat";
    final String? photoUrl = widget.otherUserPhoto ?? widget.nutritionistData["imageUrl"];
    

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3EB),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
             margin: const EdgeInsets.all(8),
             alignment: Alignment.center,
             child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF462F4D), size: 24),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: purple.withValues(alpha:0.1),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person, color: purple, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: purple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
                overflow: TextOverflow.ellipsis,
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
                    Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text("Clear Chat History", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: PatternBackground()),
          Column(
            children: [
              SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
              // Encryption notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black.withValues(alpha:0.02),
                child: Text(
                  "Messages are end-to-end encrypted",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 10),
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
                            style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          final isMe = data["senderId"] == FirebaseAuth.instance.currentUser?.uid;

                          return _buildMessageItem(data, isMe, docId);
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
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4)],
                          ),
                          child: Row(
                            children: [
                              Text(
                                "typing",
                                style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB).withValues(alpha:0.9),
                    boxShadow: [BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, -4))],
                  ),
                  child: Row(
                    children: [
                      if (_isNutritionist) ...[
                        GestureDetector(
                          onTap: () => _showActionSheet(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E3D5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_rounded, color: const Color(0xFF74503C), size: 22),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: const TextStyle(color: Color(0xFFBFA89A)),
                            filled: true,
                            fillColor: const Color(0xFFFDECE4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE48E5B),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
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
    const Color purple = Color(0xFF462F4D);
    const Color actionOrange = Color(0xFFE48E5B);
    const Color subTextColor = Color(0xFFBFA89A);

    final actions = [
      if (_canShareMealPlans) ...[
        {"icon": Icons.restaurant_menu_rounded, "title": "Create New Meal Plan", "subtitle": "Design a custom plan for your client"},
        {"icon": Icons.bookmark_rounded, "title": "Share Saved Meal Plans", "subtitle": "Send from your existing plans library"},
      ],
      if (_canShareSupplements)
        {"icon": Icons.medical_services_rounded, "title": "Share Supplement Guide", "subtitle": "Send personalized recommendations"},
      {"icon": Icons.calendar_month_rounded, "title": "Schedule Meeting", "subtitle": "Set up a consultation session"},
      {"icon": Icons.attach_file_rounded, "title": "Attach File", "subtitle": "Send documents, images, or reports"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9E3D5), // Sheet becomes darker beige
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 50, height: 5,
              decoration: BoxDecoration(color: actionOrange, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 20),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    "Quick Actions",
                    style: TextStyle(color: purple, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24), // Added spacing
            // Action items — individual cards
            ...List.generate(actions.length, (i) {
              final action = actions[i];
              return Container(
                margin: EdgeInsets.only(left: 16, right: 16, bottom: i < actions.length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EA), // Cards become lighter
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: purple.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: purple.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: purple.withValues(alpha:0.06)),
                            ),
                            child: Icon(action["icon"] as IconData, color: actionOrange, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action["title"] as String,
                                  style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: "Satoshi"),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  action["subtitle"] as String,
                                  style: TextStyle(color: subTextColor, fontSize: 12, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E3D5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF74503C)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
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
    if (_isNutritionist) {
       updateData["userUnread"] = FieldValue.increment(1);
       updateData["nutritionistUnread"] = 0;
    } else {
       updateData["nutritionistUnread"] = FieldValue.increment(1);
       updateData["userUnread"] = 0;
       // Also ensure participants are set if creating for the first time by user
       updateData["participants"] = FieldValue.arrayUnion([user.uid, widget.nutritionistId]); 
    }

    await chatRef.set(updateData, SetOptions(merge: true));

    await chatRef.collection("messages").add({
      "text": text,
      "senderId": user.uid,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Trigger Notification
    final recipientId = _isNutritionist ? widget.clientId : widget.nutritionistId;
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
        body: text,
        type: NotificationType.chat_message,
        targetId: _chatId,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFF9E3D5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50, height: 5,
              decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 24),
            Text(
              "Delete Message",
              style: TextStyle(color: purple, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
            ),
            const SizedBox(height: 24),
            _deleteOptionButton("Delete for me", Icons.delete_outline_rounded, () {
              Navigator.pop(context);
              _deleteMessageForMe(docId);
            }),
            if (isMe) ...[
              const SizedBox(height: 12),
              _deleteOptionButton("Delete for everyone", Icons.delete_forever_rounded, () {
                Navigator.pop(context);
                _deleteMessageForEveryone(docId);
              }, isRed: true),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text("Cancel", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _deleteOptionButton(String label, IconData icon, VoidCallback onTap, {bool isRed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.withValues(alpha:0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isRed ? Colors.red : purple, size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: isRed ? Colors.red : purple, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
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
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFEF8A54) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Text(
            data["text"] ?? "",
            style: TextStyle(color: isMe ? Colors.white : purple, fontSize: 15),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        _showDeleteOptions(docId, isMe);
      },
      child: child,
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
        width: 260,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFFE48E5B), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text("Consultation Scheduled", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
            Divider(height: 20, color: purple.withValues(alpha:0.1)),
            Text(dateStr, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            if (time != null) Text(time, style: TextStyle(color: subheadColor, fontSize: 14)),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: btnBgColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 14, color: btnBgColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notes, style: TextStyle(color: subheadColor, fontSize: 13, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
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
                  backgroundColor: btnBgColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, color: btnTextColor, size: 16),
                    const SizedBox(width: 6),
                    Text("Add to Calendar", style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Notes (Optional)", style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: notesCtrl,
          decoration: InputDecoration(
            hintText: "Meeting topic...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3EB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      final cals = data["targetCalories"] ?? 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close sheet
                          _sendMealPlanMessage({...data, "planId": id});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                                    Text("$days Days • ~ $cals kcal", style: TextStyle(color: purple.withValues(alpha:0.6), fontSize: 13)),
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
        width: 260,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: const Color(0xFFE48E5B), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text("Meal Plan Shared", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
            Divider(height: 20, color: purple.withValues(alpha:0.1)),
            if (coverImage != null && coverImage.isNotEmpty)
              Container(
                width: double.infinity,
                height: 120,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(coverImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("$days Days • Target $cals kcal", style: TextStyle(color: subheadColor, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MealPlanViewScreen(
                        planData: plan,
                        // hide save logic for nutritionist view
                        isViewingSavedPlan: _isNutritionist, 
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBgColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(buttonText, style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
