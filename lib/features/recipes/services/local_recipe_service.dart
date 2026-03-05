import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';

class LocalRecipeService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_recipes.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version to apply schema change
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recipes (
            id TEXT,
            userId TEXT,
            name TEXT,
            data TEXT,
            createdAt TEXT,
            PRIMARY KEY (id, userId)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add userId column and migrate existing records (default to 'unknown' or current user)
          await db.execute('ALTER TABLE recipes ADD COLUMN userId TEXT DEFAULT "unknown"');
          // Update primary key by creating a new table and copying data
          await db.execute('ALTER TABLE recipes RENAME TO recipes_old');
          await db.execute('''
            CREATE TABLE recipes (
              id TEXT,
              userId TEXT,
              name TEXT,
              data TEXT,
              createdAt TEXT,
              PRIMARY KEY (id, userId)
            )
          ''');
          await db.execute('''
            INSERT INTO recipes (id, userId, name, data, createdAt)
            SELECT id, userId, name, data, createdAt FROM recipes_old
          ''');
          await db.execute('DROP TABLE recipes_old');
        }
      },
    );
  }

  Future<void> saveRecipeOffline(Recipe recipe, String userId) async {
    final db = await database;
    final data = jsonEncode(recipe.toJson());
    
    await db.insert(
      'recipes',
      {
        'id': recipe.id,
        'userId': userId,
        'name': recipe.name,
        'data': data,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("[LocalRecipeService] Recipe ${recipe.id} saved offline");
  }

  Future<List<Recipe>> getOfflineRecipes(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recipes', 
      where: 'userId = ?', 
      whereArgs: [userId],
      orderBy: 'createdAt DESC'
    );

    return List.generate(maps.length, (i) {
      final data = jsonDecode(maps[i]['data']);
      return Recipe.fromJson(data);
    });
  }

  Future<List<Recipe>> getRecipesByIds(List<String> ids, String userId) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.generate(ids.length, (index) => '?').join(',');
    
    // Add userId to the end of the query arguments
    final args = List<dynamic>.from(ids)..add(userId);

    final List<Map<String, dynamic>> maps = await db.query(
      'recipes',
      where: 'id IN ($placeholders) AND userId = ?',
      whereArgs: args,
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      final data = jsonDecode(maps[i]['data']);
      return Recipe.fromJson(data);
    });
  }

  Future<void> removeRecipeOffline(String id, String userId) async {
    final db = await database;
    await db.delete('recipes', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    print("[LocalRecipeService] Recipe $id removed from offline for user $userId");
  }

  Future<bool> isRecipeOffline(String id, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recipes', 
      where: 'id = ? AND userId = ?', 
      whereArgs: [id, userId]
    );
    return maps.isNotEmpty;
  }
}



