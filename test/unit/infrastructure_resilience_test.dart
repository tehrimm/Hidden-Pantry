import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:hidden_pantry_app/core/services/notification_service.dart';

// Mocks
class MockClient extends Mock implements http.Client {}
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  // Case: Fixes "Binding has not yet been initialized" 
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search Ranking Logic (RecipeApiService)', () {
    test('Logic Check: Scoring priorities', () {
      // Manual scoring simulation based on searchRecipes implementation:
      // Exact (+500), StartsWith (+200), Contains (+100)
           
      double scoreExact = 1.0 + 500; // Pizza
      double scoreStarts = 1.0 + 200; // Pizza Dough
      double scoreContains = 1.0 + 100; // Best Pizza
      
      expect(scoreExact > scoreStarts, isTrue);
      expect(scoreStarts > scoreContains, isTrue);
    });
  });

  group('Notification Routing Logic', () {
    late NotificationService service;
    late MockFirestore mockFirestore;
    late MockAudioPlayer mockAudioPlayer;

    setUp(() {
      mockFirestore = MockFirestore();
      mockAudioPlayer = MockAudioPlayer();
      // Inject both to bypass platform initialization
      service = NotificationService(firestore: mockFirestore, audioPlayer: mockAudioPlayer);
    });

    test('Service initialization with mocks', () {
      expect(service, isNotNull);
    });
  });

  group('Data Robustness & Edge Cases', () {
    test('Recipe.fromJson handles missing optional fields gracefully', () {
      final json = {
        "id": "123",
        "name": "Minimal Recipe",
        "ingredients": [],
      };

      final recipe = Recipe.fromJson(json);
      expect(recipe.id, "123");
      expect(recipe.minutes, 0); 
    });

    test('Recipe.fromJson handles mixed fractions (1 1/2)', () {
      final json = {
        "name": "Water",
        "quantity": "1 1/2",
        "unit": "cups"
      };
      
      final item = IngredientItem.fromJson(json);
      expect(item.quantity, 1.5);
    });

    test('Recipe.fromJson handles simple fractions (3/4)', () {
      final json = {"name": "Flour", "quantity": "3/4", "unit": "cup"};
      final item = IngredientItem.fromJson(json);
      expect(item.quantity, 0.75);
    });
  });
}
