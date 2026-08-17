import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/food_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'meu_app_dieta.db');
    return await openDatabase(
      path,
      version: 16, // v16: Fix null-safe seeding + per-item error handling
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createHistoryTable(db);
    await _createCacheTable(db);
    await _createLocalFoodsTable(db);
    await _createMealsTable(db);
    await _createUserFoodsTable(db);
    await _seedDatabase(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createLocalFoodsTable(db);
      await _seedDatabase(db);
    }
    if (oldVersion < 3) {
      await _createMealsTable(db);
      await _createUserFoodsTable(db);
    }
    if (oldVersion < 4) {
      await _seedDatabase(db);
    }
    if (oldVersion < 5) {
      await _seedDatabase(db);
    }
    if (oldVersion < 6) {
      await _seedDatabase(db);
    }
    if (oldVersion < 7) {
      // Re-seed for ML unit column addition
      await db.execute('ALTER TABLE local_foods ADD COLUMN serving_unit TEXT DEFAULT "g"');
      await _seedDatabase(db);
    }
    if (oldVersion < 8) {
      await _seedDatabase(db);
    }
    if (oldVersion < 9) {
      // Add normalization columns for accent-insensitive search
      await db.execute('ALTER TABLE local_foods ADD COLUMN normalized_name TEXT');
      await db.execute('ALTER TABLE local_foods ADD COLUMN normalized_brand TEXT');
      await _seedDatabase(db);
    }
    if (oldVersion < 10) {
      // Add sodium column
      await db.execute('ALTER TABLE local_foods ADD COLUMN sodium REAL DEFAULT 0.0');
      await _seedDatabase(db);
    }
    if (oldVersion < 11) {
      // Re-seed for more brands (Tapioca Akio, etc)
      await _seedDatabase(db);
    }
    if (oldVersion < 12) {
      // Re-seed with massive FatSecret BR data expansion
      await _seedDatabase(db);
    }
    if (oldVersion < 13) {
      // Final massive premium data seed (Wickbold, Sadia, etc)
      await _seedDatabase(db);
    }
    if (oldVersion < 14) {
      // FULL TACO Integration
      await _seedDatabase(db);
    }
    if (oldVersion < 15) {
      // Re-seed: auto-generate macro descriptions for TACO items
      await _seedDatabase(db);
    }
    if (oldVersion < 16) {
      // v16: Re-seed with null-safe parsing (fixes failed seeds on iOS)
      await _seedDatabase(db);
    }
  }

  Future<void> _createHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT UNIQUE,
        timestamp INTEGER
      )
    ''');
  }

  Future<void> _createCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE food_cache (
        id TEXT PRIMARY KEY,
        name TEXT,
        brand TEXT,
        description TEXT,
        image_url TEXT,
        json_data TEXT,
        timestamp INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_cache_name ON food_cache(name)');
  }

  Future<void> _createLocalFoodsTable(Database db) async {
    await db.execute('''
      CREATE TABLE local_foods (
        id TEXT PRIMARY KEY,
        name TEXT,
        brand TEXT,
        calories REAL,
        protein REAL,
        carbohydrates REAL,
        fat REAL,
        fiber REAL,
        sodium REAL,
        serving_unit TEXT DEFAULT "g",
        description TEXT,
        image_url TEXT,
        json_data TEXT,
        normalized_name TEXT,
        normalized_brand TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_local_name ON local_foods(name)');
    await db.execute('CREATE INDEX idx_local_norm_name ON local_foods(normalized_name)');
  }

  Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        total_calories REAL,
        json_items TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_meals_date ON meals(date)');
  }

  Future<void> _createUserFoodsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_foods (
        id TEXT PRIMARY KEY,
        name TEXT,
        brand TEXT,
        description TEXT,
        image_url TEXT,
        usage_count INTEGER,
        json_data TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_user_food_name ON user_foods(name)');
  }

  String _normalize(String text) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
    String result = text;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result.toLowerCase();
  }

  /// Generates a standardized macro description from numeric fields.
  /// Example output: "Por 100g | Cals: 123.5kcal | Prot: 2.6g | Carbs: 25.8g | Fat: 1g"
  String _buildMacroDescription(Map<String, dynamic> item) {
    final unit = item['servingUnit'] ?? 'g';
    final cals = (item['calories'] as num?)?.toDouble() ?? 0.0;
    final prot = (item['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (item['carbohydrates'] as num?)?.toDouble() ?? 0.0;
    final fat = (item['fat'] as num?)?.toDouble() ?? 0.0;

    String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    return 'Por 100$unit | Cals: ${_fmt(cals)}kcal | Prot: ${_fmt(prot)}g | Carbs: ${_fmt(carbs)}g | Fat: ${_fmt(fat)}g';
  }

  /// Returns true if the description already contains formatted macro info.
  bool _hasMacroDescription(String? desc) {
    if (desc == null || desc.isEmpty) return false;
    return desc.contains('Cals:') && desc.contains('Prot:');
  }

  Future<void> _seedDatabase(Database db) async {
    try {
      final List<String> seedFiles = [
        'assets/db/foods_seed.json',
        'assets/db/taco_full.json',
      ];
      
      final batch = db.batch();
      int successCount = 0;
      
      for (String fileName in seedFiles) {
        try {
          final String response = await rootBundle.loadString(fileName);
          final List<dynamic> data = jsonDecode(response);
          
          for (var item in data) {
            try {
              // Auto-generate macro description if missing (e.g. TACO items)
              final rawDesc = item['description'] as String? ?? '';
              final description = _hasMacroDescription(rawDesc)
                  ? rawDesc
                  : _buildMacroDescription(item);

              // Update the item map so json_data also carries the correct description
              final enrichedItem = Map<String, dynamic>.from(item);
              enrichedItem['description'] = description;

              batch.insert(
                'local_foods',
                {
                  'id': item['id'],
                  'name': item['name'],
                  'brand': item['brand'] ?? '',
                  'calories': (item['calories'] as num?)?.toDouble() ?? 0.0,
                  'protein': (item['protein'] as num?)?.toDouble() ?? 0.0,
                  'carbohydrates': (item['carbohydrates'] as num?)?.toDouble() ?? 0.0,
                  'fat': (item['fat'] as num?)?.toDouble() ?? 0.0,
                  'fiber': (item['fiber'] as num?)?.toDouble() ?? 0.0,
                  'sodium': (item['sodium'] as num?)?.toDouble() ?? 0.0,
                  'serving_unit': item['servingUnit'] ?? 'g',
                  'description': description,
                  'image_url': item['imageUrl'],
                  'json_data': jsonEncode(enrichedItem),
                  'normalized_name': _normalize(item['name'] ?? ''),
                  'normalized_brand': _normalize(item['brand'] ?? ''),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              successCount++;
            } catch (itemError) {
              debugPrint('Error seeding item ${item['id']}: $itemError');
            }
          }
        } catch (e) {
          debugPrint('Error loading seed file $fileName: $e');
        }
      }
      
      await batch.commit(noResult: true);
      debugPrint('Database seeded successfully: $successCount items');
    } catch (e) {
      debugPrint('Error seeding database: $e');
    }
  }

  // History Operations
  Future<void> saveQuery(String query) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'search_history',
      {'query': query, 'timestamp': timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.execute('''
      DELETE FROM search_history 
      WHERE id NOT IN (
        SELECT id FROM search_history 
        ORDER BY timestamp DESC 
        LIMIT 20
      )
    ''');
  }

  Future<List<String>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => maps[i]['query'] as String);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  // Food Cache Operations
  Future<void> cacheFoods(List<FoodModel> foods) async {
    final db = await database;
    final batch = db.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var food in foods) {
      batch.insert(
        'food_cache',
        {
          'id': food.id,
          'name': food.name,
          'brand': food.brand,
          'description': food.description,
          'image_url': food.imageUrl,
          'json_data': jsonEncode(food.toJson()),
          'timestamp': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FoodModel>> searchCache(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'food_cache',
      where: 'name LIKE ? OR brand LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
    return List.generate(maps.length, (i) {
      return FoodModel.fromJson(jsonDecode(maps[i]['json_data']));
    });
  }

  // Local Foods Research
  Future<List<FoodModel>> searchLocalFoods(String query) async {
    final db = await database;
    final normalizedQuery = _normalize(query);
    final words = normalizedQuery.split(' ').where((w) => w.trim().isNotEmpty).toList();

    if (words.isEmpty) return [];

    // Build dynamic WHERE clause for multi-token search
    // Example: "pão wickbold" -> (name LIKE %pão% OR brand LIKE %pão%) AND (name LIKE %wickbold% OR brand LIKE %wickbold%)
    final whereClause = words.map((_) => '(normalized_name LIKE ? OR normalized_brand LIKE ?)').join(' AND ');
    final whereArgs = <String>[];
    for (var word in words) {
      whereArgs.add('%$word%');
      whereArgs.add('%$word%');
    }

    // Add arguments for the ORDER BY clause
    whereArgs.add('$normalizedQuery%');
    whereArgs.add('%$normalizedQuery%');

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM local_foods 
      WHERE $whereClause
      ORDER BY CASE 
        WHEN normalized_name LIKE ? THEN 0 
        WHEN normalized_name LIKE ? THEN 1 
        ELSE 2 
      END, name ASC
      LIMIT 50
      ''',
      whereArgs,
    );
    return List.generate(maps.length, (i) {
      return FoodModel.fromJson(jsonDecode(maps[i]['json_data']));
    });
  }

  Future<void> clearOldCache() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await db.delete('food_cache', where: 'timestamp < ?', whereArgs: [sevenDaysAgo]);
  }
}
