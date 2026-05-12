import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/glass_dialog.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';


class CreatePlanScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPlan;
  final String? planId; // Added for editing
  const CreatePlanScreen({super.key, this.initialPlan, this.planId});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final Color bg = const Color(0xFFFFF3EB);
  final Color purple = const Color(0xFF462F4D);
  final Color orange = const Color(0xFFEF8A54);

  late TextEditingController _nameController;
  
  String _selectedInterval = "Monthly";
  final List<String> _intervals = ["Monthly", "Quarterly"];
  
  // NEW: Tier Handling
  String _selectedTier = "Tier 1 (Silver)";
  final List<String> _tiers = ["Tier 1 (Silver)", "Tier 2 (Gold)", "Tier 3 (Platinum)"];

  int get _tierLevel {
    if (_selectedTier.contains("Tier 1")) return 1;
    if (_selectedTier.contains("Tier 2")) return 2;
    if (_selectedTier.contains("Tier 3")) return 3;
    return 1;
  }

  String get _calculatedPrice {
    final bool isQuarterly = _selectedInterval == "Quarterly";
    if (_tierLevel == 1) return isQuarterly ? "11000" : "4000";
    if (_tierLevel == 2) return isQuarterly ? "19000" : "7000";
    if (_tierLevel == 3) return isQuarterly ? "27000" : "10000";
    return "0";
  }

  List<Map<String, dynamic>> _benefits = [
    {"icon": Icons.restaurant_menu_rounded, "title": "InChat meal plans", "subtitle": "Direct meal plan sharing", "enabled": true},
    {"icon": Icons.chat_bubble_rounded, "title": "Priority Support", "subtitle": "Direct chat access", "enabled": true},
    {"icon": Icons.medical_services_rounded, "title": "Supplement Guide", "subtitle": "Personalized recommendations", "enabled": false},
    {"icon": Icons.verified_rounded, "title": "Nutritionist Approved Recipes", "subtitle": "Exclusive recipe access", "enabled": false},
  ];

  bool _isPublishing = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlan?['title'] ?? "");
    _selectedInterval = widget.initialPlan?['interval'] ?? "Monthly";
    _isActive = widget.initialPlan?['isActive'] ?? true;
    
    // Initialize Tier
    if (widget.initialPlan != null && widget.initialPlan!['tierLevel'] != null) {
      final level = widget.initialPlan!['tierLevel'];
      if (level == 1) _selectedTier = "Tier 1 (Silver)";
      if (level == 2) _selectedTier = "Tier 2 (Gold)";
      if (level == 3) _selectedTier = "Tier 3 (Platinum)";
    }
    
    // If editing, map the benefits
    if (widget.initialPlan?['benefits'] != null) {
      final List incoming = widget.initialPlan!['benefits'];
      
      // 1. Mark existing default benefits as enabled/disabled
      for (var b in _benefits) {
        final found = incoming.any((element) => 
          element['title']?.toString().toLowerCase().trim() == b['title'].toString().toLowerCase().trim()
        );
        b['enabled'] = found;
      }
      
      // 2. Add custom benefits (those not in the default list)
      final List<String> defaultTitles = ["InChat meal plans", "Priority Support", "Supplement Guide", "Nutritionist Approved Recipes"]
          .map((e) => e.toLowerCase()).toList();

      for (var element in incoming) {
        final title = element['title']?.toString() ?? "";
        if (!defaultTitles.contains(title.toLowerCase().trim())) {
          _benefits.add({
            "icon": Icons.star_outline_rounded,
            "title": title,
            "subtitle": element["subtitle"] ?? "Custom benefit",
            "enabled": true,
            "isCustom": true,
          });
        }
      }
    }
    
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _publishPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.isEmpty) {
      Toaster.show(context, "Please fill in plan name", isError: true);
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final cleanedBenefits = _benefits
          .where((b) => b["enabled"])
          .map((b) => {
                "title": b["title"],
                "subtitle": b["subtitle"],
              })
          .toList();

      final planData = {
        "title": _nameController.text,
        "price": _calculatedPrice, 
        "interval": _selectedInterval,
        "benefits": cleanedBenefits,
        "nutritionistId": user.uid,
        "createdAt": widget.planId == null ? FieldValue.serverTimestamp() : (widget.initialPlan?['createdAt'] ?? FieldValue.serverTimestamp()),
        "updatedAt": FieldValue.serverTimestamp(),
        "isActive": _isActive,
        "tierLevel": _tierLevel, // NEW: Save tier level
      };

      final collection = FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(user.uid)
          .collection("subscription_plans");

      if (widget.planId != null) {
        await collection.doc(widget.planId).update(planData);
      } else {
        await collection.add(planData);
      }

      if (mounted) {
        Toaster.show(context, widget.planId != null ? "Plan updated successfully!" : "Plan published successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toaster.show(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _deletePlan() async {
    if (widget.planId == null) return;

    final confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Delete Plan?", style: TextStyle(color: purple, fontWeight: FontWeight.bold, fontFamily: "Satoshi")),
        content: Text("This tier will no longer be available for new subscribers. Existing subscribers will not be affected.", style: TextStyle(color: purple.withValues(alpha: 0.7), fontFamily: "Satoshi")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPublishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection("nutritionists")
          .doc(user.uid)
          .collection("subscription_plans")
          .doc(widget.planId)
          .delete();

      if (mounted) {
        Toaster.show(context, "Plan deleted successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Toaster.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: Container(
        color: bg,
        child: Stack(
          children: [
            const PatternBackground(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 22.sw,
                        right: 22.sw,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 40.sh,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FadeSlideEntry(
                            delayMs: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 16.sh),
                                _sectionHeader("LIVE PREVIEW"),
                                SizedBox(height: 16.sh),
                                _livePreviewCard(),
                              ],
                            ),
                          ),
                          SizedBox(height: 32.sh),
                          _FadeSlideEntry(
                            delayMs: 200,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionHeader("PLAN DETAILS"),
                                SizedBox(height: 16.sh),
                                _inputField("PLAN NAME", _nameController),
                                SizedBox(height: 16.sh),
                                Row(
                                  children: [
                                    Expanded(child: _readOnlyPriceField(
                                      "FIXED PRICE", 
                                      _calculatedPrice, 
                                      prefix: "Rs. ",
                                    )),
                                    SizedBox(width: 16.sw),
                                    Expanded(child: _intervalDropdown()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24.sh),
                          _FadeSlideEntry(
                            delayMs: 300,
                            child: _tierSelector(),
                          ),
                          SizedBox(height: 32.sh),
                          _FadeSlideEntry(
                            delayMs: 400,
                            child: _visibilityToggle(),
                          ),
                          SizedBox(height: 32.sh),
                          _FadeSlideEntry(
                            delayMs: 500,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _sectionHeader("SELECT BENEFITS"),
                                    GestureDetector(
                                      onTap: _showAddBenefitDialog,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.sw, vertical: 6.sh),
                                        decoration: BoxDecoration(
                                          color: orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10.sw),
                                        ),
                                        child: Text(
                                          "+ Add Custom",
                                          style: TextStyle(color: orange, fontSize: 11.sp, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ..._benefits.asMap().entries.map((entry) => _benefitToggle(entry.key, entry.value)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          if (widget.planId != null) ...[
                            _FadeSlideEntry(
                              delayMs: 600,
                              child: _deleteButton(),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Fixed header – back button
            Positioned(
              left: 30.sw,
              top: 51.sh,
              child: BackButtonWidget(
                onPressed: () => Navigator.pop(context),
                color: const Color(0xFF433020),
              ),
            ),
            // Fixed header – title
            Positioned(
              left: 0,
              right: 0,
              top: 51.sh,
              height: 50.sh,
              child: Center(
                child: Text(
                  widget.planId != null ? "Edit Plan" : "Create Plan",
                  style: TextStyle(
                    color: purple,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ),
            // Fixed header – publish/update button
            Positioned(
              right: 22.sw,
              top: 51.sh,
              height: 50.sh,
              child: Center(
                child: _isPublishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF8A54)),
                      )
                    : GestureDetector(
                        onTap: _publishPlan,
                        child: Text(
                          widget.planId != null ? "Update" : "Publish",
                          style: TextStyle(
                            color: orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            fontFamily: "Satoshi",
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: purple.withValues(alpha: 0.4),
        fontSize: 11.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0.sw,
      ),
    );
  }

  Widget _livePreviewCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: EdgeInsets.all(24.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(32.sw),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _nameController.text.isEmpty ? "Plan Name" : _nameController.text,
                  style: TextStyle(color: purple, fontSize: 24.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.sw, vertical: 4.sh),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.sw),
                ),
                child: Text(
                  _selectedTier.split(' ').first,
                  style: TextStyle(color: orange, fontSize: 10.sp, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.sh),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. $_calculatedPrice",
                style: TextStyle(color: orange, fontSize: 32.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6.sh, left: 4.sw),
                child: Text(
                  "/ $_selectedInterval",
                  style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.sh),
          ..._benefits.where((b) => b["enabled"]).map((b) => _benefitPreviewRow(b["title"])),
          SizedBox(height: 32.sh),
          Container(
            width: double.infinity,
            height: 56.sh,
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(20.sw),
              boxShadow: [
                BoxShadow(color: purple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Text(
                "Subscribe Now",
                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
            ),
          ),
          SizedBox(height: 16.sh),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, size: 14.sw, color: purple.withValues(alpha: 0.4)),
                SizedBox(width: 6.sw),
                Text(
                  "Client view preview",
                  style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 11.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitPreviewRow(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.sh),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: purple, fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: "Satoshi"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyPriceField(
    String label, 
    String value, {
    String? prefix,
  }) {
    return Container(
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5).withValues(alpha: 0.6), 
        borderRadius: BorderRadius.circular(16.sw),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.w900),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8.sh),
            child: Text(
              "$prefix$value",
              style: TextStyle(color: purple.withValues(alpha: 0.7), fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(
    String label, 
    TextEditingController controller, {
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(16.sw),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.w900),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(top: 8.sh),
              border: InputBorder.none,
              prefixText: prefix,
              prefixStyle: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitToggle(int index, Map<String, dynamic> benefit) {
    bool enabled = benefit["enabled"];
    bool isCustom = benefit["isCustom"] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 12.sh),
      padding: EdgeInsets.all(16.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: enabled ? orange : Colors.transparent, width: 1.sw),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.sw),
            decoration: BoxDecoration(
              color: enabled ? orange.withValues(alpha: 0.05) : bg,
              borderRadius: BorderRadius.circular(12.sw),
            ),
            child: Icon(benefit["icon"], color: enabled ? orange : purple.withValues(alpha: 0.3), size: 20.sw),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit["title"],
                  style: TextStyle(color: purple, fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  benefit["subtitle"],
                  style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp),
                ),
              ],
            ),
          ),
          if (isCustom)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20.sw),
              onPressed: () {
                setState(() {
                  _benefits.removeAt(index);
                });
              },
            ),
          Switch(
            value: enabled,
            onChanged: (v) => setState(() => _benefits[index]["enabled"] = v),
            activeThumbColor: orange,
            activeTrackColor: orange.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _intervalDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "INTERVAL",
            style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.w900),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedInterval,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: purple, size: 24.sw),
              dropdownColor: const Color(0xFFFFF3EB),
              style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
              items: _intervals.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) setState(() => _selectedInterval = newValue);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBenefitDialog() {
    final controller = TextEditingController();
    GlassDialog.show(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Add Custom Benefit", style: TextStyle(color: purple, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "e.g. Daily Motivation Quotes",
            hintStyle: TextStyle(color: purple.withValues(alpha: 0.3)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha: 0.5), fontWeight: FontWeight.w600, fontFamily: "Satoshi")),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _benefits.add({
                    "icon": Icons.star_outline_rounded,
                    "title": controller.text,
                    "subtitle": "Custom benefit",
                    "enabled": true,
                    "isCustom": true,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: Text("Add", style: TextStyle(color: orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _visibilityToggle() {
    return Container(
      padding: EdgeInsets.all(20.sw),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20.sw),
        border: Border.all(color: _isActive ? orange.withValues(alpha: 0.3) : Colors.transparent, width: 1.sw),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.sw),
            decoration: BoxDecoration(
              color: _isActive ? orange.withValues(alpha: 0.1) : bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: _isActive ? orange : purple.withValues(alpha: 0.3),
              size: 20.sw,
            ),
          ),
          SizedBox(width: 16.sw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Public Visibility",
                  style: TextStyle(color: purple, fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isActive ? "Visible to new users" : "Hidden from new users",
                  style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            activeThumbColor: orange,
            activeTrackColor: orange.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _tierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("TIER LEVEL"),
        SizedBox(height: 12.sh),
        Container(
          height: 64.sh,
          padding: EdgeInsets.all(6.sw),
          decoration: BoxDecoration(
            color: const Color(0xFFF9E3D5),
            borderRadius: BorderRadius.circular(20.sw),
          ),
          child: Row(
            children: _tiers.map((tier) {
              final isSelected = _selectedTier == tier;
              final shortName = tier.contains("Silver") ? "SILVER" : (tier.contains("Gold") ? "GOLD" : "PLATINUM");
              final tierColor = shortName == "SILVER" ? const Color(0xFF8A9EA7) : (shortName == "GOLD" ? const Color(0xFFD4AF37) : const Color(0xFF6A4C93));

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTier = tier);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14.sw),
                      boxShadow: isSelected ? [
                        BoxShadow(color: tierColor.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ] : [],
                    ),
                    child: Center(
                      child: Text(
                        shortName,
                        style: TextStyle(
                          color: isSelected ? tierColor : purple.withValues(alpha: 0.4),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _deleteButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _deletePlan,
        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withValues(alpha: 0.7), size: 20.sw),
        label: Text(
          "Delete Plan",
          style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 0.5),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24.sw, vertical: 12.sh),
          backgroundColor: Colors.red.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.sw),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
          ),
        ),
      ),
    );
  }
}

class _FadeSlideEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideEntry({required this.child, required this.delayMs});

  @override
  State<_FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<_FadeSlideEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
