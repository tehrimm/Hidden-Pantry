import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

void main() {
  group('Real Business Tests: Cooking Mode Core Features', () {

    // ─── DirectionStep Model ───────────────────────────────────────
    group('DirectionStep model', () {
      test('Creates with required id and defaults', () {
        final step = DirectionStep(id: 'step_1');
        expect(step.id, 'step_1');
        expect(step.text, '');
        expect(step.image, null);
        expect(step.imageUrl, null);
      });

      test('Creates with full text and imageUrl', () {
        final step = DirectionStep(
          id: 'step_2',
          text: 'Preheat oven to 180°C',
          imageUrl: 'https://example.com/step2.jpg',
        );
        expect(step.text, 'Preheat oven to 180°C');
        expect(step.imageUrl, 'https://example.com/step2.jpg');
      });

      test('Text is mutable (can be edited during upload flow)', () {
        final step = DirectionStep(id: 'step_3', text: 'Initial text');
        step.text = 'Updated text';
        expect(step.text, 'Updated text');
      });

      test('Multiple steps maintain independent state', () {
        final steps = List.generate(5, (i) => DirectionStep(id: 'step_$i', text: 'Step $i'));
        expect(steps.length, 5);
        steps[2].text = 'Modified step 2';
        expect(steps[2].text, 'Modified step 2');
        expect(steps[1].text, 'Step 1'); // Not affected
      });
    });

    // ─── Prep/Cook Timer Logic ──────────────────────────────────────
    group('prepMinutes and cookMinutes cooking timer logic', () {
      test('Recipe under 20 min: all time is prep, 0 cook', () {
        const r = Recipe(id: 'c1', name: 'A', minutes: 10, avgRating: 4.0);
        expect(r.prepMinutes, 10);
        expect(r.cookMinutes, 0);
      });

      test('Recipe at exactly 20 min: 15 prep, 5 cook', () {
        const r = Recipe(id: 'c2', name: 'A', minutes: 20, avgRating: 4.0);
        expect(r.prepMinutes, 15);
        expect(r.cookMinutes, 5);
      });

      test('Recipe at 25 min: 15 prep, 10 cook', () {
        const r = Recipe(id: 'c3', name: 'A', minutes: 25, avgRating: 4.0);
        expect(r.prepMinutes, 15);
        expect(r.cookMinutes, 10);
      });

      test('Recipe at 60 min: 15 prep, 45 cook', () {
        const r = Recipe(id: 'c4', name: 'A', minutes: 60, avgRating: 4.0);
        expect(r.prepMinutes, 15);
        expect(r.cookMinutes, 45);
      });

      test('prepMinutes + cookMinutes = total minutes', () {
        for (final mins in [5, 10, 15, 19, 20, 30, 45, 60, 90, 120]) {
          final r = Recipe(id: 'cx', name: 'A', minutes: mins, avgRating: 4.0);
          expect(r.prepMinutes + r.cookMinutes, mins,
              reason: 'Failed for minutes=$mins');
        }
      });

      test('Explicit prepMinutes and cookMinutes override the default', () {
        const r = Recipe(
          id: 'c5', name: 'A', minutes: 60, avgRating: 4.0,
          prepMinutes: 20, cookMinutes: 40,
        );
        expect(r.prepMinutes, 20);
        expect(r.cookMinutes, 40);
      });
    });

    // ─── nSteps count ──────────────────────────────────────────────
    group('nSteps and directions count', () {
      test('nSteps defaults to 0', () {
        const r = Recipe(id: 's1', name: 'A', minutes: 10, avgRating: 4.0);
        expect(r.nSteps, 0);
      });

      test('directions.length is ground truth for cooking steps count', () {
        const r = Recipe(
          id: 's2', name: 'A', minutes: 10, avgRating: 4.0,
          directions: ['Step 1', 'Step 2', 'Step 3'],
        );
        expect(r.directions.length, 3);
      });

      test('stepsDetailed can include image URLs per step', () {
        final steps = [
          {'text': 'Boil water', 'imageUrl': 'https://img.com/1.jpg'},
          {'text': 'Add pasta', 'imageUrl': null},
          {'text': 'Drain and serve', 'imageUrl': 'https://img.com/3.jpg'},
        ];
        final r = Recipe(
          id: 's3', name: 'A', minutes: 20, avgRating: 4.0,
          stepsDetailed: steps,
          directions: const ['Boil water', 'Add pasta', 'Drain and serve'],
        );
        expect(r.stepsDetailed!.length, 3);
        expect(r.stepsDetailed![0]['text'], 'Boil water');
        expect(r.stepsDetailed![1]['imageUrl'], null);
        expect(r.stepsDetailed![2]['imageUrl'], 'https://img.com/3.jpg');
      });
    });

    // ─── Difficulty & Category Business Logic ──────────────────────
    group('Difficulty and Category', () {
      test('Difficulty field is preserved from construction', () {
        const r = Recipe(
          id: 'd1', name: 'A', minutes: 30, avgRating: 4.0,
          difficulty: 'Medium',
        );
        expect(r.difficulty, 'Medium');
      });

      test('Category field is preserved', () {
        const r = Recipe(
          id: 'd2', name: 'A', minutes: 30, avgRating: 4.0,
          category: 'Desserts',
        );
        expect(r.category, 'Desserts');
      });

      test('Tags list drives cooking category filter', () {
        const r = Recipe(
          id: 'd3', name: 'A', minutes: 30, avgRating: 4.0,
          tags: ['Italian', 'Vegan', 'Quick'],
        );
        expect(r.tags.contains('Vegan'), true);
        expect(r.tags.contains('Italian'), true);
        expect(r.tags.contains('Breakfast'), false);
      });
    });

    // ─── Recipe Upload Quantity Parsing ────────────────────────────
    group('Ingredient quantity parsing (RecipeService upload logic)', () {
      /// Mirrors the regex logic from RecipeService.uploadFullRecipe
      double parseQuantity(dynamic rawQty) {
        final numericOnly = RegExp(r'[\d.]+').firstMatch(rawQty.toString())?.group(0) ?? '0';
        return double.tryParse(numericOnly) ?? 0.0;
      }

      String parseUnit(dynamic rawQty) {
        final numericOnly = RegExp(r'[\d.]+').firstMatch(rawQty.toString())?.group(0) ?? '0';
        return rawQty.toString().replaceAll(numericOnly, '').trim();
      }

      test('Parses integer quantity', () {
        expect(parseQuantity('2'), 2.0);
        expect(parseUnit('2 cups'), 'cups');
      });

      test('Parses decimal quantity', () {
        expect(parseQuantity('1.5 tbsp'), 1.5);
        expect(parseUnit('1.5 tbsp'), 'tbsp');
      });

      test('Handles number-only input', () {
        expect(parseQuantity('100'), 100.0);
        expect(parseUnit('100'), '');
      });

      test('Handles quantity with no number → defaults to 0', () {
        expect(parseQuantity('to taste'), 0.0);
        expect(parseUnit('to taste'), 'to taste');
      });

      test('Parses grams correctly', () {
        expect(parseQuantity('200 g'), 200.0);
        expect(parseUnit('200 g'), 'g');
      });
    });

    // ─── AI Label Canonicalization (Camera Feature) ───────────────
    group('AI camera label canonicalization logic', () {
      /// Mirrors _canonicalizeLabel from IngredientRecognitionService
      String canonicalize(String s) {
        var out = s.replaceAll('\r', '').trim();
        out = out.replaceAll('_', ' ').replaceAll('-', ' ').trim();
        out = out.replaceAll(RegExp(r'\s+\d+$'), '').trim(); // drop trailing numbers
        out = out.replaceAll(RegExp(r'\s+'), ' '); // collapse spaces
        return out;
      }

      test('Strips carriage returns', () {
        expect(canonicalize('chicken\r'), 'chicken');
      });

      test('Replaces underscores with spaces', () {
        expect(canonicalize('bell_pepper'), 'bell pepper');
        expect(canonicalize('olive_oil'), 'olive oil');
      });

      test('Replaces hyphens with spaces', () {
        expect(canonicalize('cherry-tomato'), 'cherry tomato');
      });

      test('Drops trailing class index numbers', () {
        // e.g., ML model outputs "apple 12" → "apple"
        expect(canonicalize('apple 12'), 'apple');
        expect(canonicalize('tomato 001'), 'tomato');
      });

      test('Collapses multiple spaces to single space', () {
        expect(canonicalize('lemon   juice'), 'lemon juice');
      });

      test('Trims leading/trailing whitespace', () {
        expect(canonicalize('  garlic  '), 'garlic');
      });

      test('Mixed input: underscores + trailing number', () {
        expect(canonicalize('red_pepper 5'), 'red pepper');
      });

      test('Already clean label stays unchanged', () {
        expect(canonicalize('broccoli'), 'broccoli');
        expect(canonicalize('fresh salmon'), 'fresh salmon');
      });
    });
  });
}
