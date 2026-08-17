/// Centralized date key utilities to avoid duplicated formatting logic
/// across MealStorage, meal_provider, and history parsing.
class AppDateUtils {
  AppDateUtils._();

  /// Converts a [DateTime] to a stable YYYY-MM-DD string key (local time).
  static String dateToKey(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  /// Alias kept for backwards compat.
  static String toDateKey(DateTime date) => dateToKey(date);

  /// Returns the YYYY-MM-DD key for today in local time.
  static String todayKey() => dateToKey(DateTime.now());

  /// Checks whether [date] falls on today (local time).
  static bool isToday(DateTime date) => dateToKey(date) == todayKey();

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
