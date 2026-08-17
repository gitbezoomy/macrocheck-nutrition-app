class FoodModel {
  final String id;
  final String name;
  final String? brand;
  final String description;
  final String? type;
  final String? imageUrl;
  final int? usageCount;

  FoodModel({
    required this.id,
    required this.name,
    this.brand,
    required this.description,
    this.type,
    this.imageUrl,
    this.usageCount = 0,
  });

  FoodModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? description,
    String? type,
    String? imageUrl,
    int? usageCount,
  }) {
    return FoodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    if (json['food_image'] is String) {
      imageUrl = json['food_image'];
    } else {
      final dynamic imagesRaw = json['food_images'];
      if (imagesRaw is Map<String, dynamic>) {
        final imagesData = imagesRaw['food_image'];
        if (imagesData is List && imagesData.isNotEmpty) {
          imageUrl = imagesData.first['image_url']?.toString();
        } else if (imagesData is Map) {
          imageUrl = imagesData['image_url']?.toString();
        }
      }
    }

    return FoodModel(
      id: (json['food_id'] ?? json['id'])?.toString() ?? '',
      name: json['food_name'] ?? json['name'] ?? 'Desconhecido',
      brand: json['brand_name'] ?? json['brand'],
      description: json['food_description'] ?? json['description'] ?? '',
      type: json['food_type'],
      imageUrl: imageUrl ?? json['image_url'],
      usageCount: json['usage_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_id': id,
      'food_name': name,
      'brand_name': brand,
      'food_description': description,
      'food_type': type,
      'food_image': imageUrl,
      'usage_count': usageCount,
    };
  }
}

class Serving {
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
  final String servingDescription;
  final double metricServingAmount;
  final String metricServingUnit;
  final double numberOfUnits;
  final String? measurementDescription;
  final String? servingUrl;
  final double? saturatedFat;
  final double? transFat;
  final double? cholesterol;
  final double? sodium;
  final double? potassium;
  final double? fiber;
  final double? sugar;
  final double? vitaminA;
  final double? vitaminC;
  final double? calcium;
  final double? iron;

  Serving({
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
    required this.servingDescription,
    required this.metricServingAmount,
    this.metricServingUnit = 'g',
    this.numberOfUnits = 1.0,
    this.measurementDescription,
    this.servingUrl,
    this.saturatedFat,
    this.transFat,
    this.cholesterol,
    this.sodium,
    this.potassium,
    this.fiber,
    this.sugar,
    this.vitaminA,
    this.vitaminC,
    this.calcium,
    this.iron,
  });

  factory Serving.fromJson(Map<String, dynamic> json) {
    return Serving(
      calories: double.tryParse(json['calories']?.toString() ?? '0') ?? 0,
      protein: double.tryParse(json['protein']?.toString() ?? '0') ?? 0,
      carbohydrate: double.tryParse(json['carbohydrate']?.toString() ?? '0') ?? 0,
      fat: double.tryParse(json['fat']?.toString() ?? '0') ?? 0,
      servingDescription: json['serving_description']?.toString() ?? '1 serving',
      metricServingAmount: double.tryParse(json['metric_serving_amount']?.toString() ?? '0') ?? 0,
      metricServingUnit: json['metric_serving_unit']?.toString() ?? 'g',
      numberOfUnits: double.tryParse(json['number_of_units']?.toString() ?? '1') ?? 1.0,
      measurementDescription: json['measurement_description']?.toString(),
      servingUrl: json['serving_url']?.toString(),
      saturatedFat: double.tryParse(json['saturated_fat']?.toString() ?? ''),
      transFat: double.tryParse(json['trans_fat']?.toString() ?? ''),
      cholesterol: double.tryParse(json['cholesterol']?.toString() ?? ''),
      sodium: double.tryParse(json['sodium']?.toString() ?? ''),
      potassium: double.tryParse(json['potassium']?.toString() ?? ''),
      fiber: double.tryParse(json['fiber']?.toString() ?? ''),
      sugar: double.tryParse(json['sugar']?.toString() ?? ''),
      vitaminA: double.tryParse(json['vitamin_a']?.toString() ?? ''),
      vitaminC: double.tryParse(json['vitamin_c']?.toString() ?? ''),
      calcium: double.tryParse(json['calcium']?.toString() ?? ''),
      iron: double.tryParse(json['iron']?.toString() ?? ''),
    );
  }

  bool get isUnit {
    if (measurementDescription != null && measurementDescription!.isNotEmpty) {
      final m = measurementDescription!.toLowerCase();
      if (m.contains('unidade') || m.contains('und') || m.contains('unid') || 
          m.contains('piece') || m.contains('unit') || m.contains('item') || m.contains('peça') ||
          m.contains('slice') || m.contains('fatia') || m.contains('pote') || m.contains('container') ||
          m.contains('pedaço') || m.contains('medium') || m.contains('small') || m.contains('large') ||
          m.contains('média') || m.contains('pequena') || m.contains('grande')) {
        return true;
      }
    }
    final desc = servingDescription.toLowerCase();
    if (desc.contains('unidade') || desc.contains('und') || desc.contains('unid') ||
        desc.contains('unit') || desc.contains('piece') || desc.contains('item') ||
        desc.contains('fatia') || desc.contains('pote') || desc.contains('péça') ||
        desc.contains('slice') || desc.contains('individual')) {
      return true;
    }
    return false;
  }
}

class FoodDetails {
  final String id;
  final String name;
  final String? brand;
  final String? description;
  final List<Serving> servings;
  final String? imageUrl;

  FoodDetails({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    required this.servings,
    this.imageUrl,
  });

  Serving get defaultServing {
    if (servings.isEmpty) {
      return Serving(
        calories: 0, protein: 0, carbohydrate: 0, fat: 0,
        servingDescription: 'Sem dados', metricServingAmount: 0,
      );
    }
    final unitServing = servings.where((s) => s.isUnit).toList();
    if (unitServing.isNotEmpty) return unitServing.first;
    final portionServing = servings.where((s) => s.metricServingAmount != 100.0).toList();
    if (portionServing.isNotEmpty) return portionServing.first;
    return servings.first;
  }

  factory FoodDetails.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    final dynamic imagesRaw = json['food_images'];
    if (imagesRaw is Map<String, dynamic>) {
      final imagesData = imagesRaw['food_image'];
      if (imagesData != null) {
        if (imagesData is List && imagesData.isNotEmpty) {
          final standard = imagesData.firstWhere(
            (img) => img is Map && img['image_type']?.toString().toLowerCase() == 'standard',
            orElse: () => imagesData.first,
          );
          if (standard is Map) {
            imageUrl = standard['image_url']?.toString();
          }
        } else if (imagesData is Map) {
          imageUrl = imagesData['image_url']?.toString();
        }
      }
    }

    final dynamic servingsRaw = json['servings'];
    if (servingsRaw is! Map<String, dynamic> || servingsRaw['serving'] == null) {
      return FoodDetails(
        id: json['food_id']?.toString() ?? '',
        name: json['food_name'] ?? 'Desconhecido',
        brand: json['brand_name'],
        description: json['food_description'],
        servings: [],
        imageUrl: imageUrl,
      );
    }

    final rawServings = servingsRaw['serving'];
    final List<Serving> parsedServings;
    if (rawServings is List) {
      parsedServings = rawServings.map((s) => Serving.fromJson(s)).toList();
    } else {
      parsedServings = [Serving.fromJson(rawServings)];
    }

    return FoodDetails(
      id: json['food_id']?.toString() ?? '',
      name: json['food_name'] ?? 'Desconhecido',
      brand: json['brand_name'],
      description: json['food_description'],
      servings: parsedServings,
      imageUrl: imageUrl,
    );
  }
}