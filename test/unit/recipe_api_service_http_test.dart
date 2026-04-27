import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';


void main() {
  HttpServer? server;
  late String baseUrl;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server!.address.host}:${server!.port}';
    // Simple router
    server!.listen((HttpRequest req) async {
      final path = req.uri.path;
      final method = req.method.toUpperCase();
      try {
        if (method == 'POST' && path == '/recommend') {
          final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
          final query = (body['query'] ?? '').toString();
          final results = [
            {
              'id': 'ra',
              'title': query.isEmpty ? 'Alpha' : query,
              'minutes': 9,
              'avg_rating': 3.5,
              'ingredients': ['Flour', 'Eggs'],
              'directions': ['Mix', 'Bake'],
              'tags': ['baking']
            },
            {
              'id': 'rb',
              'title': 'Bravo',
              'minutes': 12,
              'avg_rating': 4.0,
              'ingredients': ['Tomato'],
              'directions': ['Chop'],
              'tags': ['italian']
            }
          ];
          final payload = jsonEncode({'results': results});
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(payload);
          await req.response.close();
          return;
        }
        if (method == 'GET' && path.startsWith('/recipes/')) {
          final id = path.split('/').last;
          final payload = jsonEncode({
            'recipe': {
              'id': id,
              'title': id == 'id1' ? 'Pizza' : 'Pasta',
              'minutes': id == 'id1' ? 30 : 20,
              'avg_rating': 4.1,
              'ingredients': ['A'],
              'directions': ['B']
            }
          });
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(payload);
          await req.response.close();
          return;
        }
        if (method == 'GET' && path == '/authors/a1/recipe_count') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'count': 12}));
          await req.response.close();
          return;
        }
        if (method == 'GET' && path == '/authors/a1/stats') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'followers': 5, 'rating': 4.2}));
          await req.response.close();
          return;
        }
        if (method == 'GET' && path == '/authors/a1/recipes') {
          final payload = jsonEncode({
            'results': [
              {'id': 'r1', 'title': 'S', 'minutes': 10, 'avg_rating': 4.0},
              {'id': 'r2', 'title': 'T', 'minutes': 15, 'avg_rating': 4.5}
            ]
          });
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(payload);
          await req.response.close();
          return;
        }
        // default 404
        req.response
          ..statusCode = 404
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'not found'}));
        await req.response.close();
      } catch (e) {
        req.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': e.toString()}));
        await req.response.close();
      }
    });
  });

  tearDownAll(() async {
    await server?.close(force: true);
  });

  test('getRecipeById maps fields from /recipes/<id>', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final r1 = await api.getRecipeById('id1');
    expect(r1.id, 'id1');
    expect(r1.name.toLowerCase(), 'pizza');
    expect(r1.minutes, 30);
    final r2 = await api.getRecipeById('id2');
    expect(r2.id, 'id2');
    expect(r2.name.toLowerCase(), 'pasta');
    expect(r2.minutes, 20);
  });

  test('countRecipesByAuthor returns integer', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final c = await api.countRecipesByAuthor('a1');
    expect(c, 12);
  });

  test('getAuthorStats returns map data', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final m = await api.getAuthorStats('a1');
    expect(m['followers'], 5);
    expect(m['rating'], 4.2);
  });

  test('fetchRecipesByAuthor returns list of recipes', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final list = await api.fetchRecipesByAuthor('a1', limit: 10);
    expect(list.length, 2);
    expect(list.first.id, 'r1');
  });

  test('recommend returns results from POST', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final res = await api.recommend(query: 'query', ingredients: const ['x'], topK: 5);
    expect(res.length, 2);
    expect(res.first.name.isNotEmpty, true);
  });

  test('searchRecipes returns results and applies local filters', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final res = await api.searchRecipes('alpha', limit: 10, ingredients: const ['Flour'], maxMinutes: 60, tags: const ['baking']);
    expect(res.isNotEmpty, true);
    expect(res.first.name.isNotEmpty, true);
  });

  test('searchRecipes by keyword only', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final res = await api.searchRecipes('alpha');
    expect(res.isNotEmpty, true);
    expect(res.first.name.toLowerCase(), contains('alpha'));
  });

  test('searchRecipes by ingredients only', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    final res = await api.searchRecipes('', ingredients: ['Tomato']);
    expect(res.any((r) => r.id == 'rb'), isTrue);
  });

  test('searchRecipes with no matching results returns empty list', () async {
    final api = RecipeApiService(baseUrl: baseUrl);
    // Mock server returns ra and rb. Searching for something else with strict ingredients:
    final res = await api.searchRecipes('nonexistent', ingredients: ['Plastic']);
    expect(res, isEmpty);
  });
}
