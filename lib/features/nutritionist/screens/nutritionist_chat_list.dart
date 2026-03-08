import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/chat_interface_part.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

class NutritionistChatListScreen extends StatefulWidget {
  const NutritionistChatListScreen({super.key});

  @override
  State<NutritionistChatListScreen> createState() => _NutritionistChatListScreenState();
}

class _NutritionistChatListScreenState extends State<NutritionistChatListScreen> {
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);
  final Color bg = const Color(0xFFFFF3EB);

  bool _isSubsLoading = true;
  List<String> _activeSubscriberIds = [];
  final Map<String, bool> _prioritySupportMap = {};
  StreamSubscription? _subsSubscription;

  @override
  void initState() {
    super.initState();
    _loadActiveSubscribers();
  }

  void _loadActiveSubscribers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subsSubscription?.cancel();
    _subsSubscription = FirebaseFirestore.instance
        .collection("subscriptions")
        .where("nutritionistId", isEqualTo: user.uid)
        .snapshots()
        .listen((subsSnap) async {
      final Map<String, bool> accessMap = {};
      final DateTime now = DateTime.now();

      // Collect subscriptions to process
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs = [];
      for (var doc in subsSnap.docs) {
        final data = doc.data();
        final String status = data["status"]?.toString() ?? "";
        final Timestamp? expiryDate = data["expiryDate"] as Timestamp?;

        // Strict activity check: must have active/trialing status AND valid future expiry
        final bool isActive = (status == "active" || status == "trialing") &&
            (expiryDate != null && expiryDate.toDate().isAfter(now));

        if (isActive) {
          activeDocs.add(doc);
        }
      }

      // Process in parallel
      await Future.wait(activeDocs.map((doc) async {
        final data = doc.data();
        final userId = data["userId"] as String?;
        final planId = data["planId"] as String?;
        if (userId == null || userId == user.uid) return;

        // Default: Assume priority if tier >= 2
        int tierLevel = 0;
        final rawTier = data["tierLevel"];
        if (rawTier is num) tierLevel = rawTier.toInt();
        else if (rawTier is String) tierLevel = int.tryParse(rawTier) ?? 0;

        bool hasPriority = tierLevel >= 2;

        // Verify with plan benefits if planId exists
        if (planId != null && planId.isNotEmpty) {
          try {
            var planDoc = await FirebaseFirestore.instance
                .collection("nutritionists")
                .doc(user.uid)
                .collection("subscription_plans")
                .doc(planId)
                .get();

            if (!planDoc.exists) {
              final q = await FirebaseFirestore.instance
                  .collection("nutritionists")
                  .doc(user.uid)
                  .collection("subscription_plans")
                  .where("title", isEqualTo: planId)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) planDoc = q.docs.first;
            }

            if (planDoc.exists) {
              final List? benefits = planDoc.data()?["benefits"];
              if (benefits != null) {
                final bool hasChatBenefit = benefits.any((b) {
                  final String t = (b is Map ? (b["title"] ?? b["text"] ?? "") : b)
                      .toString()
                      .toLowerCase();
                  return t.contains("priority support") ||
                      t.contains("chat access") ||
                      t.contains("direct chat") ||
                      t.contains("message access") ||
                      t.contains("in-chat");
                });
                
                // If plan explicitly has chat, allow it even on tier 1
                if (hasChatBenefit) hasPriority = true;
              }
            }
          } catch (e) {
            debugPrint("Error checking plan $planId: $e");
          }
        }

        if (hasPriority) {
          accessMap[userId] = true;
        }
      }));

      if (mounted) {
        setState(() {
          _activeSubscriberIds = accessMap.keys.toList();
          _prioritySupportMap
            ..clear()
            ..addAll(accessMap);
          _isSubsLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint("Error loading subscribers: $e");
      if (mounted) setState(() => _isSubsLoading = false);
    });
  }


  Future<Map<String, dynamic>> _getUserDetails(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          "name": data["fullName"] ?? "User",
          "photoUrl": data["photoUrl"],
        };
      }
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
    return {"name": "User"};
  }

  void _confirmDeleteChat(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Conversation?", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Text(
          "Are you sure you want to delete the chat with ${client["name"]}? This will delete all messages and remove the chat from your list.",
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
              _deleteChat(client);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha:0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(Map<String, dynamic> client) async {
    final chatId = client["chatId"];
    if (chatId == null || chatId.isEmpty) return;

    setState(() => _isSubsLoading = true);

    try {
      final chatRef = FirebaseFirestore.instance.collection("chats").doc(chatId);
      
      // 1. Delete all messages
      final messagesSnap = await chatRef.collection("messages").get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete the chat document 
      batch.delete(chatRef);
      
      await batch.commit();

      if (mounted) {
        Toaster.show(context, "Chat with ${client["name"]} deleted.");
      }
      // No need to manually refresh, stream handles it
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error deleting chat: $e", isError: true);
        setState(() => _isSubsLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _subsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please log in"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Text(
            "Messages",
            style: TextStyle(color: purple, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
          ),
        ),
        // Content
        Expanded(
          child: _isSubsLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("chats")
                      .where("participants", arrayContains: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<Map<String, dynamic>> chatsData = [];
                    final Set<String> chatUserIds = {};

                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data();
                      final participants = List<String>.from(data["participants"] ?? []);
                      final otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => "");
                      if (otherUserId.isEmpty) continue;

                      // FIX: Only show the chat if the user has an active plan with Priority Support
                      if (_prioritySupportMap[otherUserId] != true) continue;

                      chatUserIds.add(otherUserId);
                      chatsData.add({
                        "userId": otherUserId,
                        "chatId": doc.id,
                        "lastMessage": data["lastMessage"] ?? "",
                        "lastMessageTime": data["lastMessageTime"],
                        "unreadCount": data["nutritionistUnread"] ?? 0,
                        "typingStatus": data["typingStatus"] as Map<String, dynamic>?,
                      });
                    }

                    // Merge active subscribers who don't have a chat yet
                    for (var subId in _activeSubscriberIds) {
                      if (!chatUserIds.contains(subId)) {
                        chatsData.add({
                          "userId": subId,
                          "chatId": "chat_${subId}_${user.uid}",
                          "lastMessage": "",
                          "lastMessageTime": null,
                          "unreadCount": 0,
                        });
                      }
                    }

                    if (chatsData.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: purple.withValues(alpha:0.2)),
                            const SizedBox(height: 16),
                            Text(
                              "No subscribers yet.",
                              style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort: most recent first
                    chatsData.sort((a, b) {
                      final aTime = a["lastMessageTime"] as Timestamp?;
                      final bTime = b["lastMessageTime"] as Timestamp?;
                      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
                      if (aTime != null) return -1;
                      if (bTime != null) return 1;
                      return 0;
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      itemCount: chatsData.length,
                      itemBuilder: (context, index) {
                        final client = chatsData[index];
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getUserDetails(client["userId"]),
                          builder: (context, userSnap) {
                            final userData = userSnap.data ?? {"name": "User"};
                            return _buildClientTile({...client, ...userData});
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClientTile(Map<String, dynamic> client) {
    final String name = client["name"] ?? "User";
    final String? photoUrl = client["photoUrl"] as String?;
    final String lastMsg = client["lastMessage"] ?? "";
    final Timestamp? timestamp = client["lastMessageTime"] as Timestamp?;
    final String chatId = client["chatId"] ?? "";
    final int unread = client["unreadCount"] ?? 0;
    final Map<String, dynamic>? typingMap = client["typingStatus"];
    
    bool isTyping = false;
    if (typingMap != null && typingMap.containsKey(client["userId"])) {
      isTyping = typingMap[client["userId"]] == true;
    }

    return GestureDetector(
      onLongPress: () => _confirmDeleteChat(client),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatInterface(
              nutritionistId: FirebaseAuth.instance.currentUser!.uid,
              nutritionistData: {},
              chatIdOverride: chatId,
              otherUserName: name,
              otherUserPhoto: photoUrl, // Pass photo for header
              clientId: client["userId"], // Added
            ),
          ),
        ).then((_) {
          // No need to manually refresh, stream handles it
        }); 
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9E3D5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: purple.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: orange.withValues(alpha:0.1),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? Icon(Icons.person, color: orange) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: "Satoshi"),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isTyping 
                              ? "Typing..." 
                              : lastMsg.isNotEmpty ? lastMsg : "Tap to start chatting",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isTyping 
                                ? orange 
                                : lastMsg.isEmpty
                                    ? purple.withValues(alpha:0.3)
                                    : unread > 0
                                        ? purple
                                        : purple.withValues(alpha:0.5),
                            fontWeight: (unread > 0 || isTyping) ? FontWeight.bold : FontWeight.normal,
                            fontStyle: (lastMsg.isEmpty && !isTyping) ? FontStyle.italic : FontStyle.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: orange, shape: BoxShape.circle),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
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

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}";
  }
}
