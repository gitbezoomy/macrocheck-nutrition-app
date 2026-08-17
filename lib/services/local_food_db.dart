import '../models/food_model.dart';
import 'database_service.dart';
import 'dart:convert';

/// Service to query the local enriched database of Brazilian foods.
/// Now powered by SQLite instead of a hardcoded list for better scale and performance.
class LocalFoodDb {
  static final DatabaseService _db = DatabaseService();

  /// Searches for foods in the local prepopulated database.
  static Future<List<FoodModel>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return await _db.searchLocalFoods(query.trim());
  }

  /// Returns popular/common local foods for the empty-search placeholder.
  static Future<List<FoodModel>> getPopular({int limit = 10}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_foods',
      where: "id LIKE 'local_%'",
      orderBy: 'name ASC',
      limit: limit,
    );
    return maps.map((m) => FoodModel.fromJson(jsonDecode(m['json_data']))).toList();
  }

  /// Retrieves details for a specific local food by name or ID.
  /// Note: ID format is usually 'local_<name_slug>'.
  static Future<FoodDetails?> getDetails(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_foods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final item = maps.first;
    final unit = item['serving_unit'] ?? 'g';
    final serving = Serving(
      calories: (item['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (item['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrate: (item['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (item['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (item['fiber'] as num?)?.toDouble(),
      sodium: (item['sodium'] as num?)?.toDouble(),
      servingDescription: '100$unit (base)',
      metricServingAmount: 100,
      metricServingUnit: unit,
    );

    return FoodDetails(
      id: item['id'],
      name: item['name'],
      brand: item['brand'],
      description: item['description'],
      imageUrl: item['image_url'],
      servings: [serving],
    );
  }
}
