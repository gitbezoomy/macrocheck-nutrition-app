import 'package:dio/dio.dart';
import '../models/food_model.dart';
import 'dart:developer' as developer;

class OpenFoodFactsService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3), // Reduced for better UX
    receiveTimeout: const Duration(seconds: 3),
    headers: {
      'User-Agent': 'MeuAppDieta - Flutter - Mobile - Version 1.0',
    },
    validateStatus: (status) => status != null && status < 600,
  ));

  Future<List<FoodModel>> searchProducts(String query) async {
    try {
      final response = await _dio.get(
        'https://world.openfoodfacts.org/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'countries': 'brazil',
          'page_size': '20',
        },
      );

      if (response.statusCode == 503 || response.statusCode == 502 || response.statusCode == 500) {
        developer.log('OpenFoodFacts server error: ${response.statusCode}');
        return [];
      }

      if (response.statusCode != 200 || response.data == null) {
        developer.log('OpenFoodFacts unexpected response: ${response.statusCode}');
        return [];
      }

      final List products = response.data['products'] ?? [];
      return products.where((p) {
        return p['product_name'] != null;
      }).map((p) {
        final name = p['product_name'] ?? 'Desconhecido';
        final brand = p['brands'] ?? '';
        final barcode = p['code'] ?? p['_id'] ?? '';

        // Build description from nutriments if available
        final nutriments = p['nutriments'] ?? {};
        final kcal = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? '';
        final protein = nutriments['proteins_100g'] ?? nutriments['proteins'] ?? '';
        final carbs = nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates'] ?? '';
        final fat = nutriments['fat_100g'] ?? nutriments['fat'] ?? '';

        String description = brand;
        if (kcal.toString().isNotEmpty && kcal != 0 && kcal != '0') {
          description += ' • Por 100g';
          description += ' | Cals: ${kcal}kcal';
          if (protein != '' && protein != 0) description += ' | Prot: ${protein}g';
          if (carbs != '' && carbs != 0) description += ' | Carbs: ${carbs}g';
          if (fat != '' && fat != 0) description += ' | Fat: ${fat}g';
        } else {
          description += ' • Dados nutricionais indisponíveis';
        }

        final imageUrl = p['image_small_url'] ?? p['image_url'];

        return FoodModel(
          id: 'off_$barcode',
          name: name,
          brand: brand,
          description: description,
          type: 'OFF',
          imageUrl: imageUrl,
        );
      }).toList();
    } catch (e) {
      developer.log('Error searching OpenFoodFacts: $e');
      return [];
    }
  }

  Future<FoodDetails> getProductDetails(String barcode) async {
    final cleanBarcode = barcode.replaceFirst('off_', '');

    try {
      final response = await _dio.get(
        'https://world.openfoodfacts.org/api/v0/product/$cleanBarcode.json',
      );

      if (response.statusCode == 503 || response.statusCode == 502 || response.statusCode == 500) {
        throw Exception('Servidor do Open Food Facts indisponível no momento. Tente novamente.');
      }

      final product = response.data['product'];
      if (product == null) throw Exception('Produto não encontrado no OFF');

      final name = product['product_name'] ?? 'Desconhecido';
      final brand = product['brands'] ?? '';
      final nutriments = product['nutriments'] ?? {};

      final serving = Serving(
        calories: double.tryParse(nutriments['energy-kcal_100g']?.toString() ?? '0') ?? 0,
        protein: double.tryParse(nutriments['proteins_100g']?.toString() ?? '0') ?? 0,
        carbohydrate: double.tryParse(nutriments['carbohydrates_100g']?.toString() ?? '0') ?? 0,
        fat: double.tryParse(nutriments['fat_100g']?.toString() ?? '0') ?? 0,
        servingDescription: '100g (base industrial)',
        metricServingAmount: 100,
      );

      return FoodDetails(
        id: barcode,
        name: brand.isNotEmpty ? '$name ($brand)' : name,
        servings: [serving],
      );
    } catch (e) {
      developer.log('Error fetching OpenFoodFacts details for $barcode: $e');
      rethrow;
    }
  }
}
