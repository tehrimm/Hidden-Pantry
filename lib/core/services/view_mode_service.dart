import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage view mode for nutritionists
/// Allows nutritionists to toggle between their dashboard and user view
class ViewModeService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static final ViewModeService _instance = ViewModeService._internal();
  factory ViewModeService({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
    if (auth != null || firestore != null) {
      return ViewModeService._internal(auth: auth, firestore: firestore);
    }
    return _instance;
  }

  ViewModeService._internal({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _viewModeKey = 'nutritionist_user_view_mode';
  
  SharedPreferences? _prefs;
  bool? _cachedIsNutritionist;
  String? _lastCheckedUid;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if current user is a nutritionist
  /// Caches result per UID to avoid repeated Firestore calls
  Future<bool> isNutritionist() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Return cached result if checking same user
    if (_lastCheckedUid == user.uid && _cachedIsNutritionist != null) {
      return _cachedIsNutritionist!;
    }

    try {
      final doc = await _firestore
          .collection('nutritionists')
          .doc(user.uid)
          .get();
      
      _lastCheckedUid = user.uid;
      _cachedIsNutritionist = doc.exists;
      return doc.exists;
    } catch (e) {
      print('Error checking nutritionist status: $e');
      return false;
    }
  }

  /// Check if nutritionist is currently in user view mode
  Future<bool> isInUserView() async {
    await init();
    final isNutr = await isNutritionist();
    if (!isNutr) return false; // Regular users are always in "user view"
    
    return _prefs?.getBool(_viewModeKey) ?? false;
  }

  /// Switch to user view (only applies to nutritionists)
  Future<void> setUserView(bool enabled) async {
    await init();
    await _prefs?.setBool(_viewModeKey, enabled);
  }

  /// Clear cached role check (call when user logs out)
  void clearCache() {
    _cachedIsNutritionist = null;
    _lastCheckedUid = null;
  }

  /// Reset to nutritionist view
  Future<void> resetToNutritionistView() async {
    await setUserView(false);
  }
}
