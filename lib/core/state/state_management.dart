import 'package:flutter/foundation.dart';

// STATE MANAGEMENT CONTROLLERS (Mocks/Prototypes for Logic Testing)



class CartController extends ChangeNotifier {
  final Map<String, int> _items = {}; // ingredientName -> quantity

  Map<String, int> get items => _items;
  int get totalCount => _items.values.fold(0, (sum, q) => sum + q);

  void addItem(String name) {
    if (_items.containsKey(name)) {
      _items[name] = _items[name]! + 1; 
    } else {
      _items[name] = 1; 
    }
    notifyListeners();
  }

  void removeItem(String name) {
    if (_items.containsKey(name)) {
      if (_items[name]! > 1) {
        _items[name] = _items[name]! - 1;
      } else {
        _items.remove(name); 
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}


class FridgeController extends ChangeNotifier {
  final List<String> _inventory = [];

  List<String> get inventory => _inventory;

  void addItem(String item) {
    final trimmedItem = item.trim();
    if (trimmedItem.isNotEmpty && !_inventory.contains(trimmedItem)) {
      _inventory.add(trimmedItem); 
      notifyListeners();
    }
  }

  void removeItem(String item) {
    if (_inventory.remove(item)) { 
      notifyListeners();
    }
  }

  void clearInventory() {
    _inventory.clear();
    notifyListeners();
  }

  void addMultipleItems(List<String> items) {
    for (final item in items) {
      addItem(item);
    }
  }
}


class SubscriptionController extends ChangeNotifier {
  String _activeTier = 'Silver';

  String get activeTier => _activeTier;

  void upgradeTier() {
    _activeTier = 'Gold'; 
    notifyListeners();
  }

  void downgradeTier() {
    _activeTier = 'Silver';
    notifyListeners();
  }
}


class TTSController extends ChangeNotifier {
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  void speak() {
    _isPlaying = true; 
    notifyListeners();
  }

  void stop() {
    _isPlaying = false; 
    notifyListeners();
  }
}


class ReviewController extends ChangeNotifier {
  final List<String> _reviews = [];

  List<String> get reviews => _reviews;

  void pushReview(String review) {
    if (review.trim().isEmpty) return;
    _reviews.insert(0, review);
    notifyListeners();
  }
}
class ChatController extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  void handleIncomingMessage() {
    _unreadCount++; 
    notifyListeners();
  }

  void markAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  void resetUnread() {
    _unreadCount = 0;
    notifyListeners();
  }
}
