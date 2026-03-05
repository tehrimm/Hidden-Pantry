import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/state/state_management.dart';


void main() {
  group('CartState Logic (41-43) & Extensions', () {
    late CartController cart;

    setUp(() {
      cart = CartController();
    });

    test('Case 41: Adding an ingredient increases the cart count by 1', () {
      cart.addItem('Tomato');
      expect(cart.totalCount, 1);
      cart.addItem('Onion');
      expect(cart.totalCount, 2);
    });

    test('Case 42: Removing an item decreases the cart count', () {
      cart.addItem('Tomato');
      cart.addItem('Onion');
      cart.removeItem('Tomato');
      expect(cart.totalCount, 1);
      expect(cart.items.containsKey('Tomato'), isFalse);
    });

    test('Case 43: Adding a duplicate item updates quantity rather than adding a new row', () {
      cart.addItem('Tomato');
      cart.addItem('Tomato');
      expect(cart.items['Tomato'], 2);
      expect(cart.items.length, 1); // Only 1 unique item row
    });

    test('Edge Case: Removing an item with multi-quantity decreases quantity', () {
      cart.addItem('Tomato');
      cart.addItem('Tomato');
      cart.removeItem('Tomato');
      expect(cart.items['Tomato'], 1);
      expect(cart.totalCount, 1);
    });

    test('Edge Case: Clearing the cart resets everything', () {
      cart.addItem('Tomato');
      cart.addItem('Salt');
      cart.clearCart();
      expect(cart.totalCount, 0);
      expect(cart.items.isEmpty, isTrue);
    });

    test('Edge Case: Removing non-existent item does nothing', () {
      cart.addItem('Tomato');
      cart.removeItem('Potato');
      expect(cart.totalCount, 1);
    });
  });

  group('FridgeState Logic (44-45) & Extensions', () {
    late FridgeController fridge;

    setUp(() {
      fridge = FridgeController();
    });

    test('Case 44: Adding scanned item updates the active fridge inventory list', () {
      fridge.addItem('Milk');
      expect(fridge.inventory, contains('Milk'));
    });

    test('Case 45: Deleting an inventory item removes it from the list', () {
      fridge.addItem('Milk');
      fridge.removeItem('Milk');
      expect(fridge.inventory, isNot(contains('Milk')));
    });

    test('Edge Case: Adding duplicate item should not create duplicates in list', () {
      fridge.addItem('Milk');
      fridge.addItem('Milk');
      expect(fridge.inventory.length, 1);
    });

    test('Edge Case: Clearing inventory', () {
      fridge.addItem('Milk');
      fridge.addItem('Eggs');
      fridge.clearInventory();
      expect(fridge.inventory, isEmpty);
    });

    test('Edge Case: Adding multiple items at once', () {
      fridge.addMultipleItems(['Bread', 'Butter', 'Jam']);
      expect(fridge.inventory.length, 3);
      expect(fridge.inventory, contains('Butter'));
    });
  });

  group('SubscriptionState Logic (46)', () {
    test('Case 46: Upgrading tier changes activeTier from Silver to Gold', () {
      final sub = SubscriptionController();
      expect(sub.activeTier, 'Silver');
      sub.upgradeTier();
      expect(sub.activeTier, 'Gold');
    });

    test('Edge Case: Downgrading tier', () {
      final sub = SubscriptionController();
      sub.upgradeTier();
      sub.downgradeTier();
      expect(sub.activeTier, 'Silver');
    });
  });

  group('TTS Controller Logic (47-48)', () {
    late TTSController tts;

    setUp(() {
      tts = TTSController();
    });

    test('Case 47: speak() sets isPlaying state to true', () {
      expect(tts.isPlaying, isFalse);
      tts.speak();
      expect(tts.isPlaying, isTrue);
    });

    test('Case 48: stop() sets isPlaying state to false', () {
      tts.speak();
      tts.stop();
      expect(tts.isPlaying, isFalse);
    });
  });

  group('Review State Logic (49)', () {
    test('Case 49: Pushing a new review optimally adds it to the top of the local review list', () {
      final reviews = ReviewController();
      reviews.pushReview('Old Review');
      reviews.pushReview('New Review');
      expect(reviews.reviews.first, 'New Review');
    });

    test('Edge Case: Cannot push empty review', () {
      final reviews = ReviewController();
      reviews.pushReview('  ');
      expect(reviews.reviews, isEmpty);
    });
  });

  group('Chat State Logic (50)', () {
    test('Case 50: New incoming message locally updates the unread message count', () {
      final chat = ChatController();
      expect(chat.unreadCount, 0);
      chat.handleIncomingMessage();
      expect(chat.unreadCount, 1);
      chat.handleIncomingMessage();
      expect(chat.unreadCount, 2);
    });

    test('Edge Case: Resetting unread count', () {
      final chat = ChatController();
      chat.handleIncomingMessage();
      chat.resetUnread();
      expect(chat.unreadCount, 0);
    });
  });
}
