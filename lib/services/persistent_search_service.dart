import 'database_service.dart';
import '../models/food_model.dart';

class PersistentSearchService {
  final DatabaseService _db = DatabaseService();

  // Recent queries history
  Future<void> saveQuery(String query) async {
    if (query.trim().isEmpty) return;
    await _db.saveQuery(query.trim());
  }

  Future<List<String>> getHistory() async {
    return await _db.getHistory();
  }

  Future<void> clearHistory() async {
    await _db.clearHistory();
  }

  // Persistent result cache powered by SQLite
  Future<void> cacheResults(String query, List<FoodModel> results) async {
    if (results.isEmpty) return;
    await _db.cacheFoods(results);
    // Periodically clean old cache (once per app session is fine)
    _db.clearOldCache();
  }

  Future<List<FoodModel>?> getCachedResults(String query) async {
    if (query.trim().isEmpty) return null;
    final results = await _db.searchCache(query.trim());
    return results.isEmpty ? null : results;
  }
}
