import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_item.dart';
import '../utils/app_date_utils.dart';
import 'database_service.dart';

class MealStorage {
  final DatabaseService _db = DatabaseService();
  static const String _oldKey = 'saved_meals';

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
            batch.insert('meals', {
              'date': decoded['date'],
              'total_calories': (decoded['totalCalories'] as num).toDouble(),
              'json_items': jsonEncode(decoded['items']),
            });
          } catch (_) {}
        }
        await batch.commit(noResult: true);
      }
      await prefs.remove(_oldKey);
    }
  }

  Future<void> saveMeal(List<MealItem> items, {DateTime? date, bool replace = true}) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final saveDate = date ?? DateTime.now();
    final dateKey = AppDateUtils.dateToKey(saveDate);

    if (replace) {
      await db.delete('meals', 
        where: "strftime('%Y-%m-%d', date) = ?", 
        whereArgs: [dateKey]
      );
    }

    if (items.isNotEmpty) {
      final mealItems = items.map((item) => <String, dynamic>{
        'id': item.id,
        'name': item.name,
        'amount': item.amount,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'imageUrl': item.imageUrl,
      }).toList();

      await db.insert('meals', {
        'date': saveDate.toIso8601String(),
        'total_calories': items.fold<double>(0, (sum, item) => sum + item.calories),
        'json_items': jsonEncode(mealItems),
      });
    }
  }

  static const String _draftKey = 'current_meal_draft';

  Future<void> saveDraft(List<MealItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((item) => <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'amount': item.amount,
      'calories': item.calories,
      'protein': item.protein,
      'carbs': item.carbs,
      'fat': item.fat,
      'addedAt': item.addedAt.toIso8601String(),
      'imageUrl': item.imageUrl,
    }).toList();
    await prefs.setString(_draftKey, jsonEncode(data));
  }

  Future<List<MealItem>> getDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_draftKey);
    if (encoded == null) return [];

    try {
      final List<dynamic> data = jsonDecode(encoded);
      return data.map((item) => MealItem(
        id: item['id'] as String,
        name: item['name'] as String,
        amount: (item['amount'] as num).toDouble(),
        calories: (item['calories'] as num).toDouble(),
        protein: (item['protein'] as num).toDouble(),
        carbs: (item['carbs'] as num).toDouble(),
        fat: (item['fat'] as num).toDouble(),
        addedAt: DateTime.parse(item['addedAt'] as String),
        imageUrl: item['imageUrl'] as String?,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> saveToHistory(List<MealItem> items) async {
    await saveMeal(items, replace: false);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('meals', orderBy: 'date DESC');
    
    return maps.map((m) {
      return {
        'date': m['date'],
        'totalCalories': m['total_calories'],
        'items': jsonDecode(m['json_items']),
      };
    }).toList();
  }

  static const String _startKey = 'diet_start_date';
  static const String _goalKey = 'daily_calorie_goal';

  Future<void> saveDietStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startKey, date.toIso8601String());
  }

  Future<DateTime> getDietStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_startKey);
    if (stored == null) {
      final today = DateTime.now();
      await saveDietStartDate(today);
      return today;
    }
    return DateTime.parse(stored);
  }

  Future<void> deleteMealFromHistory(String dateTimeIso) async {
    final db = await _db.database;
    await db.delete('meals', where: 'date = ?', whereArgs: [dateTimeIso]);
  }

  Future<void> saveGoal(double goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_goalKey, goal);
  }

  Future<double> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_goalKey) ?? 2000.0;
  }
}
