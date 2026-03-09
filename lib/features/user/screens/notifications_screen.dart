import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';
import 'package:hidden_pantry_app/features/user/models/notification_model.dart';
import 'package:intl/intl.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';

class NotificationsScreen extends StatelessWidget {
  final bool isNutritionist;
  const NotificationsScreen({super.key, this.isNutritionist = false});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final topPad = MediaQuery.of(context).padding.top;
    final Color purple = const Color(0xFF462F4D);
    final Color orange = const Color(0xFFEF8A54);
    final Color bg = const Color(0xFFFFF3EB);

    return Scaffold(
      backgroundColor: isNutritionist ? Colors.white : bg,
      body: ClipRRect(
        borderRadius: isNutritionist ? BorderRadius.circular(30.sw) : BorderRadius.zero,
        child: Container(
          color: bg,
          child: Stack(
            children: [
              const PatternBackground(),
              
              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 96.sh), // Standardized gap for fixed header
                    Expanded(
                      child: StreamBuilder<List<AppNotification>>(
                        stream: NotificationService().streamNotifications(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: purple, fontFamily: "Satoshi")));
                          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: orange));
    
                          final notifications = snapshot.data!;
                          if (notifications.isEmpty) {
                            return _buildEmptyState(purple, orange);
                          }
    
                          final grouped = _groupNotifications(notifications);
    
                          return ListView.builder(
                            itemCount: grouped.keys.length,
                            padding: EdgeInsets.only(bottom: 20.sh),
                            itemBuilder: (context, index) {
                              final section = grouped.keys.elementAt(index);
                              final items = grouped[section]!;
    
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(22.sw, 20.sh, 22.sw, 10.sh),
                                    child: Text(
                                      section,
                                      style: TextStyle(
                                        color: purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                        fontFamily: "Satoshi",
                                      ),
                                    ),
                                  ),
                                  ...items.map((notif) => _buildNotificationItem(context, notif, purple, orange)).toList(),
                                ],
                              );
                            },
                          );
                        },
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
                      color: purple,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      "Notifications",
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
    );
  }

  Widget _buildEmptyState(Color purple, Color orange) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80.sw, color: purple.withValues(alpha:0.1)),
          SizedBox(height: 20.sh),
          Text(
            "No notifications yet",
            style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 18.sp),
          ),
          SizedBox(height: 8.sh),
          Text(
            "We'll notify you when something happens.",
            style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, AppNotification notif, Color purple, Color orange) {
    return _NotificationItemWidget(
      notif: notif,
      purple: purple,
      orange: orange,
    );
  }


  Map<String, List<AppNotification>> _groupNotifications(List<AppNotification> notifications) {
    Map<String, List<AppNotification>> grouped = {};
    final now = DateTime.now();

    for (var n in notifications) {
      String section;
      final diff = now.difference(n.timestamp).inDays;

      if (diff == 0) {
        section = "Today";
      } else if (diff == 1) {
        section = "Yesterday";
      } else if (diff < 7) {
        section = "Last 7 Days";
      } else {
        section = "Last 30 Days";
      }

      grouped.putIfAbsent(section, () => []).add(n);
    }
    return grouped;
  }
}

class _NotificationItemWidget extends StatefulWidget {
  final AppNotification notif;
  final Color purple;
  final Color orange;

  const _NotificationItemWidget({
    required this.notif,
    required this.purple,
    required this.orange,
  });

  @override
  State<_NotificationItemWidget> createState() => _NotificationItemWidgetState();
}

class _NotificationItemWidgetState extends State<_NotificationItemWidget> {
  String _displayTitle = "";

  @override
  void initState() {
    super.initState();
    _resolveTitle();
  }

  Future<void> _resolveTitle() async {
    String title = widget.notif.title;
    
    // Quick fallback checks
    if (title.contains("from Nutritionist") || title.contains("from User") || title.contains("from Someone")) {
      try {
        // Fetch from nutritionists
        var doc = await FirebaseFirestore.instance.collection('nutritionists').doc(widget.notif.senderId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final name = data['fullName'] ?? data['name'] ?? "";
          if (name.isNotEmpty) {
            if (mounted) {
              setState(() {
                _displayTitle = title.replaceAll(RegExp(r'(Nutritionist|User|Someone)'), name);
              });
            }
            return;
          }
        }

        // Fetch from users
        doc = await FirebaseFirestore.instance.collection('users').doc(widget.notif.senderId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final name = data['fullName'] ?? data['userName'] ?? data['name'] ?? "";
          if (name.isNotEmpty) {
            if (mounted) {
              setState(() {
                _displayTitle = title.replaceAll(RegExp(r'(Nutritionist|User|Someone)'), name);
              });
            }
            return;
          }
        }
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() {
        _displayTitle = title;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.sw),
        color: Colors.red,
        child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24.sw),
      ),
      onDismissed: (_) {
        NotificationService().deleteNotification(widget.notif.id);
      },
      child: InkWell(
        onTap: () {
          NotificationService().markAsRead(widget.notif.id);
          NotificationService().navigateByNotification(context, widget.notif);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.sw, vertical: 15.sh),
          child: Row(
            children: [
              _buildLeadingWidget(widget.notif, widget.orange, widget.purple),
              SizedBox(width: 15.sw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: widget.purple, fontSize: 14.sp, fontFamily: "Satoshi"),
                        children: [
                          TextSpan(
                            text: _displayTitle.isEmpty ? widget.notif.title : _displayTitle,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const TextSpan(text: " "),
                          TextSpan(text: widget.notif.body),
                        ],
                      ),
                    ),
                    SizedBox(height: 5.sh),
                    Text(
                      DateFormat.jm().format(widget.notif.timestamp),
                      style: TextStyle(color: widget.purple.withValues(alpha:0.4), fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              if (!widget.notif.isRead)
                Container(
                  width: 8.sw,
                  height: 8.sw,
                  decoration: BoxDecoration(color: widget.orange, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget(AppNotification notif, Color orange, Color purple) {
    if (notif.senderPhotoUrl != null && notif.senderPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(notif.senderPhotoUrl!),
      );
    }

    IconData icon;
    switch (notif.type) {
      case NotificationType.like:
        icon = Icons.favorite_rounded;
        break;
      case NotificationType.comment:
      case NotificationType.reply:
        icon = Icons.chat_bubble_rounded;
        break;
      case NotificationType.follow:
        icon = Icons.person_add_rounded;
        break;
      case NotificationType.chat_message:
        icon = Icons.mail_rounded;
        break;
      case NotificationType.nutritionist_post:
        icon = Icons.article_rounded;
        break;
    }

    return Container(
      width: 40.sw,
      height: 40.sw,
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: orange, size: 20.sw),
    );
  }
}
