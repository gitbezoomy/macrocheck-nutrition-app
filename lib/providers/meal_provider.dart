import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_item.dart';
import '../services/meal_storage.dart';
import '../services/user_food_storage.dart';
import '../utils/app_date_utils.dart';
import 'history_provider.dart';
import 'food_provider.dart';

final mealStorageProvider = Provider<MealStorage>((ref) => MealStorage());

class MealNotifier extends StateNotifier<List<MealItem>> {
  final MealStorage _storage;
  final UserFoodStorage _userStorage;

  MealNotifier(this._storage, this._userStorage) : super([]);

  void loadTodayMeal() async {
    final items = await _storage.getDraft();
    state = items;
  }

  void addFood(MealItem item) async {
    state = [...state, item];
    await _storage.saveDraft(state);
    
    // Increment usage frequency for both custom and other foods
    await _userStorage.incrementUsage(item.id);
  }

  void removeFood(String id, DateTime addedAt) async {
    state = state.where((item) => !(item.id == id && item.addedAt == addedAt)).toList();
    await _storage.saveDraft(state);
  }

  Future<void> finalizeMeal(WidgetRef ref) async {
    if (state.isEmpty) return;
    await _storage.saveToHistory(state);
    await _storage.clearDraft();
    state = [];
    // Refresh history provider to ensure UI reactivity across tabs
    ref.read(historyProvider.notifier).refresh();
  }

  void clearMeal() async {
    state = [];
    await _storage.clearDraft();
  }

  double get totalCalories => state.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => state.fold(0, (sum, item) => sum + item.protein);
  double get totalCarbs => state.fold(0, (sum, item) => sum + item.carbs);
  double get totalFat => state.fold(0, (sum, item) => sum + item.fat);
}

final mealProvider = StateNotifierProvider<MealNotifier, List<MealItem>>((ref) {
  final storage = ref.watch(mealStorageProvider);
  final userStorage = ref.watch(userFoodStorageProvider);
  return MealNotifier(storage, userStorage);
});

final dailyStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  // Watch the active meal draft - this ensures the dashboard updates in real-time
  ref.watch(mealProvider);
  final notifier = ref.read(mealProvider.notifier);
  
  // Watch history for reactive updates when meals are finalized or deleted
  final historyAsync = ref.watch(historyProvider);
  final history = historyAsync.value ?? [];
  
  double calories = notifier.totalCalories;
  double protein = notifier.totalProtein;
  double carbs = notifier.totalCarbs;
  double fat = notifier.totalFat;
  
  final todayKey = AppDateUtils.todayKey();

  for (final meal in history) {
    final mealDate = DateTime.parse(meal['date']);
    final mealKey = AppDateUtils.dateToKey(mealDate);
    
    // Check if meal was recorded today
    if (mealKey == todayKey) {
      calories += (meal['totalCalories'] as num).toDouble();
      final items = meal['items'] as List;
      for (final item in items) {
        protein += (item['protein'] as num?)?.toDouble() ?? 0.0;
        carbs += (item['carbs'] as num?)?.toDouble() ?? 0.0;
        fat += (item['fat'] as num?)?.toDouble() ?? 0.0;
      }
    }
  }
  
  return {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
});

class CalorieGoalNotifier extends StateNotifier<double> {
  final MealStorage _storage;
  CalorieGoalNotifier(this._storage) : super(2000.0) {
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    state = await _storage.getGoal();
  }

  Future<void> setGoal(double goal) async {
    state = goal;
    await _storage.saveGoal(goal);
  }
}

final calorieGoalProvider = StateNotifierProvider<CalorieGoalNotifier, double>((ref) {
  return CalorieGoalNotifier(ref.watch(mealStorageProvider));
});

// --- Diet Progression Tracking ---

class DietStartDateNotifier extends StateNotifier<DateTime> {
  final MealStorage _storage;
  DietStartDateNotifier(this._storage) : super(DateTime.now()) {
    _loadDate();
  }

  Future<void> _loadDate() async {
    state = await _storage.getDietStartDate();
  }

  Future<void> setDate(DateTime date) async {
    state = date;
    await _storage.saveDietStartDate(date);
  }
}

final dietStartDateProvider = StateNotifierProvider<DietStartDateNotifier, DateTime>((ref) {
  return DietStartDateNotifier(ref.watch(mealStorageProvider));
});

final dayCountProvider = Provider<int>((ref) {
  final startDate = ref.watch(dietStartDateProvider);
  final now = DateTime.now();
  
  // Calculate difference in days (start date is Day 1)
  final diff = now.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
  return diff + 1;
});
