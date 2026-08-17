import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/food_model.dart';
import 'database_service.dart';

class UserFoodStorage {
  final DatabaseService _db = DatabaseService();
  static const String _oldKey = 'user_custom_foods';

  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_oldKey)) {
      final List<String>? oldData = prefs.getStringList(_oldKey);
      if (oldData != null && oldData.isNotEmpty) {
        final db = await _db.database;
        final batch = db.batch();
        for (final encoded in oldData) {
          try {
            final decoded = jsonDecode(encoded) as Map<String, dynamic>;
            batch.insert('user_foods', {
              'id': decoded['id'],
              'name': decoded['name'],
              'brand': decoded['brand'] ?? '',
              'description': decoded['description'] ?? '',
              'image_url': decoded['imageUrl'],
              'usage_count': decoded['usageCount'] ?? 0,
              'json_data': encoded,
            });
          } catch (_) {}
        }
        await batch.commit(noResult: true);
      }
      await prefs.remove(_oldKey);
    }
  }

  Future<void> saveFood(FoodModel food) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    
    await db.insert(
      'user_foods',
      {
        'id': food.id,
        'name': food.name,
        'brand': food.brand,
        'description': food.description,
        'image_url': food.imageUrl,
        'usage_count': food.usageCount ?? 0,
        'json_data': jsonEncode(food.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FoodModel>> getFoods() async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('user_foods', orderBy: 'usage_count DESC');
    
    return maps.map((m) {
      return FoodModel.fromJson(jsonDecode(m['json_data']));
    }).toList();
  }

  Future<void> deleteFood(String id) async {
    final db = await _db.database;
    await db.delete('user_foods', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementUsage(String id) async {
    final db = await _db.database;
    await db.execute(
      'UPDATE user_foods SET usage_count = usage_count + 1 WHERE id = ?',
      [id]
    );
  }

  Future<List<FoodModel>> search(String query) async {
    await _migrateIfNeeded();
    if (query.isEmpty) return await getFoods();
    
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_foods',
      where: 'name LIKE ? OR brand LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'usage_count DESC'
    );
    
    return maps.map((m) {
      return FoodModel.fromJson(jsonDecode(m['json_data']));
    }).toList();
  }
}
