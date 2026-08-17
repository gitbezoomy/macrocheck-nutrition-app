import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meal_storage.dart';

class HistoryNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final MealStorage _storage;

  HistoryNotifier(this._storage) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await _storage.getHistory();
      state = AsyncValue.data(history);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteMeal(String dateTimeIso) async {
    try {
      await _storage.deleteMealFromHistory(dateTimeIso);
      await loadHistory();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() => loadHistory();
}

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return HistoryNotifier(MealStorage());
});
