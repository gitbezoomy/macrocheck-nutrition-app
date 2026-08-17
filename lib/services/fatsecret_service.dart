import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/food_model.dart';
import '../config/env.dart';
import '../services/persistent_search_service.dart';

class FatSecretService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  
  final String _clientId = EnvConfig.fatSecretClientId;
  final String _clientSecret = EnvConfig.fatSecretClientSecret;
  
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Caches de tempo de execução
  final Map<String, List<FoodModel>> _searchCache = {};
  final Map<String, FoodDetails> _detailsCache = {};
  final Map<String, List<String>> _autocompleteCache = {};

  PersistentSearchService? _persistent;
  
  void setPersistence(PersistentSearchService service) {
    _persistent = service;
  }

  Future<void> _authenticate() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}';

    final response = await _dio.post(
      'https://oauth.fatsecret.com/connect/token',
      data: {
        'grant_type': 'client_credentials',
        'scope': 'basic',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Authorization': basicAuth},
      ),
    );

    _accessToken = response.data['access_token'];
    final expiresIn = response.data['expires_in'] as int;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  Future<List<FoodModel>> searchFoods(String query,
      {int pageNumber = 0, String region = 'BR', String language = 'pt'}) async {
    
    final cacheKey = '$query-$pageNumber-$region-$language';
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    if (pageNumber == 0 && _persistent != null) {
      final diskCached = await _persistent!.getCachedResults(query);
      if (diskCached != null) {
        _searchCache[cacheKey] = diskCached;
        return diskCached;
      }
    }

    await _authenticate();
    if (_accessToken == null) return [];

    try {
      // Prioridade 1: Busca na região Brasil em Português
      var results = await _executeSearch(query, pageNumber, region, language);
      
      // Prioridade 2: Se não houver nada, busca Global (sem região)
      if (results.isEmpty && region != 'US') {
        results = await _executeSearch(query, pageNumber, null, 'en');
      }

      if (results.isNotEmpty) {
        _searchCache[cacheKey] = results;
        if (pageNumber == 0 && _persistent != null) {
          _persistent!.cacheResults(query, results);
        }
        return results;
      }
    } catch (e) {
      debugPrint('Error searching foods: $e');
      rethrow;
    }

    return [];
  }

  Future<List<FoodModel>> _executeSearch(String query, int pageNumber, String? region, String? language) async {
    final Map<String, dynamic> params = {
      'method': 'foods.search',
      'search_expression': query,
      'format': 'json',
      'page_number': pageNumber,
      'max_results': 40,
      if (region != null) 'region': region,
      if (language != null) 'language': language,
      'include_food_images': 'true',
    };

    final response = await _dio.get(
      'https://platform.fatsecret.com/rest/server.api',
      queryParameters: params,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      ),
    );

    return _parseFoodList(response.data);
  }

  List<FoodModel> _parseFoodList(dynamic data) {
    if (data['foods'] == null || data['foods']['food'] == null) {
      return [];
    }

    final foodData = data['foods']['food'];
    final List<FoodModel> results = [];
    
    if (foodData is List) {
      for (var f in foodData) {
        results.add(_normalizeFood(f));
      }
    } else {
      results.add(_normalizeFood(foodData));
    }
    return results;
  }

  FoodModel _normalizeFood(Map<String, dynamic> json) {
    String description = json['food_description'] ?? '';
    
    // Normalize FatSecret English description to our PT format
    // Format: "Per 100g - Calories: 130kcal | Fat: 1.00g | Carbs: 28.00g | Protein: 2.00g"
    if (description.contains('Per ')) {
      description = description
          .replaceAll('Per ', 'Por ')
          .replaceAll(' - Calories: ', ' | Cals: ')
          .replaceAll('kcal', 'kcal')
          .replaceAll('Fat: ', 'Fat: ')
          .replaceAll('Carbs: ', 'Carbs: ')
          .replaceAll('Protein: ', 'Prot: ');
      
      // Reorder for consistent UI: Cals | Prot | Carbs | Fat
      // Original: Por ... | Cals: ... | Fat: ... | Carbs: ... | Prot: ...
      final parts = description.split(' | ');
      if (parts.length >= 5) {
        final por = parts[0];
        final cals = parts[1];
        final fat = parts[2];
        final carbs = parts[3];
        final prot = parts[4];
        description = '$por | $cals | $prot | $carbs | $fat';
      }
    }

    return FoodModel.fromJson({
      ...json,
      'food_description': description,
    });
  }

  Future<List<String>> autocompleteFoods(String query,
      {String region = 'BR', String language = 'pt'}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];
    
    final cacheKey = '$trimmedQuery-$region-$language';
    if (_autocompleteCache.containsKey(cacheKey)) return _autocompleteCache[cacheKey]!;

    await _authenticate();
    if (_accessToken == null) return [];

    try {
      final response = await _dio.get(
        'https://platform.fatsecret.com/rest/server.api',
        queryParameters: {
          'method': 'foods.autocomplete',
          'expression': trimmedQuery,
          'format': 'json',
          'language': language,
          if (region != 'US') 'region': region,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      final data = response.data;
      if (data['suggestions'] == null || data['suggestions']['suggestion'] == null) {
        _autocompleteCache[cacheKey] = [];
        return [];
      }

      final suggestionsData = data['suggestions']['suggestion'];
      List<String> results = [];
      if (suggestionsData is List) {
        results = suggestionsData.map((s) => s.toString()).toList();
      } else {
        results = [suggestionsData.toString()];
      }
      
      _autocompleteCache[cacheKey] = results;
      return results;
    } catch (e) {
      debugPrint('Error autocomplete foods: $e');
      rethrow;
    }
  }

  Future<FoodDetails> getFoodDetails(String foodId,
      {String? region, String? language}) async {
    final cacheKey = '$foodId-$region-$language';
    if (_detailsCache.containsKey(cacheKey)) return _detailsCache[cacheKey]!;
    await _authenticate();

    try {
      final response = await _dio.get(
        'https://platform.fatsecret.com/rest/server.api',
        queryParameters: {
          'method': 'food.get.v2',
          'food_id': foodId,
          'format': 'json',
          'include_food_images': 'true',
          if (region != null) 'region': region,
          if (language != null) 'language': language,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.data['food'] == null) throw Exception('Alimento não encontrado.');
      final details = FoodDetails.fromJson(response.data['food']);
      _detailsCache[cacheKey] = details;
      return details;
    } catch (e) {
      debugPrint('Error getting food details: $e');
      rethrow;
    }
  }
}
