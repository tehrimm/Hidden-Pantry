import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/core/widgets/pattern_background.dart';
import 'package:hidden_pantry_app/core/widgets/back_button_widget.dart';
import 'package:hidden_pantry_app/core/utils/toaster.dart';

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
  late TextEditingController _priceController;
  
  String _selectedInterval = "Monthly";
  final List<String> _intervals = ["Weekly", "Monthly", "Quarterly", "Yearly"];
  
  // NEW: Tier Handling
  String _selectedTier = "Tier 1 (Silver)";
  final List<String> _tiers = ["Tier 1 (Silver)", "Tier 2 (Gold)", "Tier 3 (Platinum)"];
  int get _tierLevel {
    if (_selectedTier.contains("Tier 1")) return 1;
    if (_selectedTier.contains("Tier 2")) return 2;
    if (_selectedTier.contains("Tier 3")) return 3;
    return 1;
  }

  List<Map<String, dynamic>> _benefits = [
    {"icon": Icons.restaurant_rounded, "title": "Customized Recipes", "subtitle": "Based on preferences", "enabled": true},
    {"icon": Icons.calendar_today_rounded, "title": "Weekly Check-ins", "subtitle": "30 min video call", "enabled": true},
    {"icon": Icons.chat_bubble_rounded, "title": "Priority Support", "subtitle": "Direct chat access", "enabled": true},
    {"icon": Icons.medical_services_rounded, "title": "Supplement Guide", "subtitle": "Personalized recommendations", "enabled": false},
  ];

  bool _isPublishing = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlan?['title'] ?? "");
    _priceController = TextEditingController(text: widget.initialPlan?['price'] ?? "");
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
      // We need to preserve icons if they exist in our default list
      for (var b in _benefits) {
        final found = incoming.any((element) => element['title'] == b['title']);
        b['enabled'] = found;
      }
      
      // Also add any custom benefits that aren't in the default list
      for (var element in incoming) {
        final isDefault = _benefits.any((b) => b['title'] == element['title']);
        if (!isDefault) {
          _benefits.add({
            "icon": Icons.star_outline_rounded,
            "title": element["title"],
            "subtitle": element["subtitle"] ?? "Custom benefit",
            "enabled": true
          });
        }
      }
    }
    
    _nameController.addListener(() => setState(() {}));
    _priceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _publishPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      Toaster.show(context, "Please fill in plan name and price", isError: true);
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
        "price": _priceController.text.replaceAll(',', ''), // Ensure no commas
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Delete Plan?"),
        content: const Text("This tier will no longer be available for new subscribers. Existing subscribers will not be affected."),
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
                      padding: EdgeInsets.only(
                        left: 22,
                        right: 22,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _sectionHeader("LIVE PREVIEW"),
                          const SizedBox(height: 16),
                          _livePreviewCard(),
                          const SizedBox(height: 32),
                          _sectionHeader("PLAN DETAILS"),
                          const SizedBox(height: 16),
                          _inputField("PLAN NAME", _nameController),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _inputField(
                                "PRICE", 
                                _priceController, 
                                prefix: "Rs. ",
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                ],
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: _intervalDropdown()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _tierDropdown(), // NEW: Tier Selection
                          const SizedBox(height: 32),
                          _visibilityToggle(),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _sectionHeader("SELECT BENEFITS"),
                              GestureDetector(
                                onTap: _showAddBenefitDialog,
                                child: Text(
                                  "+ Add Custom",
                                  style: TextStyle(color: orange, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._benefits.asMap().entries.map((entry) => _benefitToggle(entry.key, entry.value)),
                          const SizedBox(height: 40),
                          if (widget.planId != null) ...[
                            _deleteButton(),
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
              left: 30,
              top: 51,
              child: BackButtonWidget(
                onPressed: () => Navigator.pop(context),
                color: const Color(0xFF433020),
              ),
            ),
            // Fixed header – title
            Positioned(
              left: 0,
              right: 0,
              top: 51,
              height: 50,
              child: Center(
                child: Text(
                  widget.planId != null ? "Edit Plan" : "Create Plan",
                  style: TextStyle(
                    color: purple,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Satoshi",
                  ),
                ),
              ),
            ),
            // Fixed header – publish/update button
            Positioned(
              right: 22,
              top: 51,
              height: 50,
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
                            fontSize: 16,
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
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _livePreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nameController.text.isEmpty ? "Plan Name" : _nameController.text,
            style: TextStyle(color: purple, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${_priceController.text.isEmpty ? "0" : _priceController.text}",
                style: TextStyle(color: orange, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: "Satoshi"),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  "/ $_selectedInterval",
                  style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._benefits.where((b) => b["enabled"]).map((b) => _benefitPreviewRow(b["title"])),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                "Subscribe Now",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: purple.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(
                  "Client view preview",
                  style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: purple, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: "Satoshi"),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w900),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8),
              border: InputBorder.none,
              prefixText: prefix,
              prefixStyle: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitToggle(int index, Map<String, dynamic> benefit) {
    bool enabled = benefit["enabled"];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: enabled ? orange : Colors.transparent, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: enabled ? orange.withValues(alpha: 0.05) : bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(benefit["icon"], color: enabled ? orange : purple.withValues(alpha: 0.3), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit["title"],
                  style: TextStyle(color: purple, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  benefit["subtitle"],
                  style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
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
            style: TextStyle(color: purple.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w900),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedInterval,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: purple),
              style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
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
    showDialog(
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
            child: Text("Cancel", style: TextStyle(color: purple.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _benefits.add({
                    "icon": Icons.star_outline_rounded,
                    "title": controller.text,
                    "subtitle": "Custom benefit",
                    "enabled": true
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E3D5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isActive ? orange.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isActive ? orange.withValues(alpha: 0.1) : bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: _isActive ? orange : purple.withValues(alpha: 0.3),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Public Visibility",
                  style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isActive ? "Visible to new users" : "Hidden from new users",
                  style: TextStyle(color: purple.withValues(alpha: 0.5), fontSize: 12),
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

  Widget _tierDropdown() {
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
            "TIER LEVEL",
            style: TextStyle(color: purple.withValues(alpha:0.4), fontSize: 10, fontWeight: FontWeight.w900),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTier,
              isExpanded: true,
              icon: Icon(Icons.layers_rounded, color: purple),
              style: TextStyle(color: purple, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: "Satoshi"),
              items: _tiers.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) setState(() => _selectedTier = newValue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _deletePlan,
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
        label: const Text(
          "Delete Plan",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: Colors.red.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
