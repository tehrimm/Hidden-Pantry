import 'package:flutter/material.dart';
import 'dart:math' as math;
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
              
              // Decorative shapes
              Positioned(
                top: -30.sh, right: -30.sw,
                child: Container(width: 120.sw, height: 120.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.06))),
              ),
              Positioned(
                bottom: -40.sh, left: -40.sw,
                child: Container(width: 160.sw, height: 160.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: purple.withValues(alpha: 0.04))),
              ),
              Positioned(
                top: 200.sh, left: 16.sw,
                child: Container(width: 10.sw, height: 10.sw,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: orange.withValues(alpha: 0.15))),
              ),
              Positioned(
                top: 320.sh, right: 20.sw,
                child: Transform.rotate(angle: math.pi / 4,
                  child: Container(width: 16.sw, height: 16.sw,
                    decoration: BoxDecoration(color: purple.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3.sw)))),
              ),

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
                            key: const PageStorageKey('notifications_list'),
                            itemCount: grouped.keys.length,
                            padding: EdgeInsets.only(bottom: 20.sh),
                            itemBuilder: (context, index) {
                              final section = grouped.keys.elementAt(index);
                              final items = grouped[section]!;
    
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FadeSlideEntry(
                                    delayMs: 50 + (index * 50),
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(24.sw, 20.sh, 24.sw, 10.sh),
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
                                  ),
                                  ...items.asMap().entries.map((entry) {
                                    int itemIndex = entry.key;
                                    AppNotification notif = entry.value;
                                    return _FadeSlideEntry(
                                      key: ValueKey(notif.id),
                                      delayMs: 100 + (index * 50) + (itemIndex * 50),
                                      child: _buildNotificationItem(context, notif, purple, orange),
                                    );
                                  }).toList(),
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
                left: 24.sw,
                right: 24.sw,
                child: Row(
                  children: [
                    BackButtonWidget(
                      color: purple,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        "Notifications",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: purple,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Satoshi",
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
    );
  }

  Widget _buildEmptyState(Color purple, Color orange) {
    return _FadeSlideEntry(
      delayMs: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.sw, height: 100.sw,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [orange.withValues(alpha: 0.15), orange.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: orange.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Icon(Icons.notifications_none_rounded, size: 44.sw, color: orange),
            ),
            SizedBox(height: 24.sh),
            Text(
              "No notifications yet",
              style: TextStyle(color: purple, fontWeight: FontWeight.w800, fontSize: 20.sp, fontFamily: "Satoshi"),
            ),
            SizedBox(height: 8.sh),
            Text(
              "We'll notify you when something happens.",
              style: TextStyle(color: purple.withValues(alpha:0.5), fontSize: 15.sp, fontFamily: "Satoshi"),
            ),
          ],
        ),
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
    super.key,
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

  @override
  void didUpdateWidget(covariant _NotificationItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notif.id != widget.notif.id || oldWidget.notif.title != widget.notif.title) {
      _resolveTitle();
    }
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 6.sh),
      child: Dismissible(
        key: Key(widget.notif.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.sw),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20.sw),
          ),
          child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24.sw),
        ),
        onDismissed: (_) {
          NotificationService().deleteNotification(widget.notif.id);
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(20.sw),
          onTap: () {
            NotificationService().markAsRead(widget.notif.id);
            NotificationService().navigateByNotification(context, widget.notif);
          },
          child: Container(
            padding: EdgeInsets.all(16.sw),
            decoration: BoxDecoration(
              color: widget.notif.isRead 
                 ? Colors.white.withValues(alpha: 0.5) 
                 : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20.sw),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.purple.withValues(alpha: widget.notif.isRead ? 0.03 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6)
                ),
              ],
            ),
            child: Row(
              children: [
                _buildLeadingWidget(widget.notif, widget.orange, widget.purple),
                SizedBox(width: 16.sw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: widget.purple, fontSize: 14.sp, fontFamily: "Satoshi", height: 1.3),
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
                      SizedBox(height: 8.sh),
                      Text(
                        DateFormat.jm().format(widget.notif.timestamp),
                        style: TextStyle(color: widget.purple.withValues(alpha:0.45), fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (!widget.notif.isRead) ...[
                  SizedBox(width: 12.sw),
                  Container(
                    width: 10.sw,
                    height: 10.sw,
                    decoration: BoxDecoration(
                      color: widget.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: widget.orange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))
                      ]
                    ),
                  ),
                ],
              ],
            ),
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
      case NotificationType.subscription_alert:
        icon = Icons.stars_rounded;
        break;
      case NotificationType.admin_alert:
        icon = Icons.gavel_rounded;
        break;
      case NotificationType.moderation_report:
        icon = Icons.report_problem_rounded;
        break;
      case NotificationType.nutritionist_application:
        icon = Icons.verified_user_rounded;
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

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({super.key, required this.child, this.delayMs = 0});
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
  }
}

