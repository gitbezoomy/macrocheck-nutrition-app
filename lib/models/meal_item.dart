class MealItem {
  final String id;
  final String name;
  final double amount; // quantity in grams or ml
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime addedAt;
  final String? imageUrl;

  MealItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.addedAt,
    this.imageUrl,
  });

  // Calculate values based on standard 100g if needed,
  // but usually FatSecret returns per serving.
  // We'll calculate proportional to the serving in the UI.
}
