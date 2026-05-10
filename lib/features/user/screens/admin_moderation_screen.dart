import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/services/moderation_service.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'dart:ui' as ui;

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final ModerationService _moderationService = ModerationService();
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _loading = true);
    try {
      final reports = await _moderationService.getReportSummary();
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching reports: $e')),
        );
      }
    }
  }

  Future<void> _suspendUser(String userId, int days) async {
    try {
      await _moderationService.suspendUser(userId, days);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User suspended for $days days')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error suspending user: $e')),
        );
      }
    }
  }

  Future<void> _takeAction(String contentType, String contentId, String action) async {
    try {
      await _moderationService.takeAction(contentType, contentId, action);
      _fetchReports(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action "$action" completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking action: $e')),
        );
      }
    }
  }

  void _showActionDialog(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionBottomSheet(
        report: report,
        onSuspend: (days) {
          Navigator.pop(context);
          _suspendUser(report['authorId'], days);
        },
        onDelete: () {
          Navigator.pop(context);
          _takeAction(report['contentType'], report['contentId'], 'delete');
        },
        onDismiss: () {
          Navigator.pop(context);
          _moderationService.dismissReports(report['contentId']).then((_) => _fetchReports());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final purple = const Color(0xFF462F4D);
    final bg = const Color(0xFFFFF3EB);

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
                      Text(
                        'Moderation Dashboard',
                        style: TextStyle(
                          color: purple,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2894F)))
                      : _reports.isEmpty
                          ? Center(
                              child: Text(
                                'No pending reports',
                                style: TextStyle(
                                  color: purple.withOpacity(0.5),
                                  fontSize: 16.sp,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 25.sw),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                final report = _reports[index];
                                return _ReportCard(
                                  report: report,
                                  onTap: () => _showActionDialog(report),
                                );
                              },
                            ),
                ),
              ],
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
    final purple = const Color(0xFF462F4D);
    final orange = const Color(0xFFF2894F);

    return Container(
      margin: EdgeInsets.only(bottom: 16.sh),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.sw),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16.sw),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20.sw),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                        decoration: BoxDecoration(
                          color: orange.withOpacity(0.1),
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
                    'Content ID: ${report['contentId']}',
                    style: TextStyle(
                      color: purple,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  SizedBox(height: 4.sh),
                  Text(
                    'Reason: ${report['reason']}',
                    style: TextStyle(
                      color: purple.withOpacity(0.7),
                      fontSize: 13.sp,
                      fontFamily: 'Satoshi',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBottomSheet extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(int) onSuspend;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const _ActionBottomSheet({
    required this.report,
    required this.onSuspend,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF462F4D);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.sw)),
      ),
      padding: EdgeInsets.all(25.sw),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.sw,
            height: 4.sh,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2.sw),
            ),
          ),
          SizedBox(height: 25.sh),
          Text(
            'Take Action',
            style: TextStyle(
              color: purple,
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 10.sh),
          Text(
            'Managing ${report['contentType']} reported ${report['reportCount']} times',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: purple.withOpacity(0.6),
              fontSize: 14.sp,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 30.sh),
          _actionTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Content',
            subtitle: 'Permanently remove this ${report['contentType']}',
            color: Colors.redAccent,
            onTap: onDelete,
          ),
          _actionTile(
            icon: Icons.timer_outlined,
            title: 'Suspend Author',
            subtitle: 'Restrict access for 7 days',
            color: const Color(0xFFF2894F),
            onTap: () => onSuspend(7),
          ),
          _actionTile(
            icon: Icons.done_all_rounded,
            title: 'Dismiss Reports',
            subtitle: 'Mark as reviewed and keep content',
            color: Colors.green,
            onTap: onDismiss,
          ),
          SizedBox(height: 20.sh),
        ],
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
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10.sw),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF462F4D),
          fontWeight: FontWeight.w800,
          fontFamily: 'Satoshi',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: const Color(0xFF462F4D).withOpacity(0.6),
          fontSize: 12.sp,
          fontFamily: 'Satoshi',
        ),
      ),
      onTap: onTap,
    );
  }
}
