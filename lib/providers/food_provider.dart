import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fatsecret_service.dart';
import '../services/open_food_facts_service.dart';
import '../services/local_food_db.dart';
import '../services/user_food_storage.dart';
import '../services/persistent_search_service.dart';
import '../models/food_model.dart';

final persistentSearchServiceProvider = Provider((ref) => PersistentSearchService());

final fatSecretServiceProvider = Provider((ref) {
  final service = FatSecretService();
  final persistent = ref.watch(persistentSearchServiceProvider);
  service.setPersistence(persistent);
  return service;
});

final openFoodFactsServiceProvider = Provider((ref) => OpenFoodFactsService());
final userFoodStorageProvider = Provider((ref) => UserFoodStorage());
final filterCompleteInfoProvider = StateProvider<bool>((ref) => false);
final regionProvider = StateProvider<String>((ref) => 'BR'); // Default to Brazil as requested

class FoodSearchState {
  final List<FoodModel> foods;
  final List<FoodModel> globalFoods;
  final bool isLoading;
  final bool isMoreLoading;
  final bool hasMore;
  final String query;
  final int currentPage;
  final String? error;
  final String currentRegion;
  final String currentLanguage;

  FoodSearchState({
    required this.foods,
    required this.globalFoods,
    required this.isLoading,
    required this.isMoreLoading,
    required this.hasMore,
    required this.query,
    required this.currentPage,
    required this.currentRegion,
    required this.currentLanguage,
    this.error,
  });

  factory FoodSearchState.initial() => FoodSearchState(
    foods: [],
    globalFoods: [],
    isLoading: false,
    isMoreLoading: false,
    hasMore: true,
    query: '',
    currentPage: 0,
    currentRegion: 'BR',
    currentLanguage: 'pt',
  );

  FoodSearchState copyWith({
    List<FoodModel>? foods,
    List<FoodModel>? globalFoods,
    bool? isLoading,
    bool? isMoreLoading,
    bool? hasMore,
    String? query,
    int? currentPage,
    String? currentRegion,
    String? currentLanguage,
    String? error,
  }) {
    return FoodSearchState(
      foods: foods ?? this.foods,
      globalFoods: globalFoods ?? this.globalFoods,
      isLoading: isLoading ?? this.isLoading,
      isMoreLoading: isMoreLoading ?? this.isMoreLoading,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      currentPage: currentPage ?? this.currentPage,
      currentRegion: currentRegion ?? this.currentRegion,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      error: error,
    );
  }
}

class FoodSearchNotifier extends StateNotifier<FoodSearchState> {
  final FatSecretService _fatSecret;
  final OpenFoodFactsService _off;
  final UserFoodStorage _userStorage;
  Timer? _debounceTimer;

  FoodSearchNotifier(this._fatSecret, this._off, this._userStorage) : super(FoodSearchState.initial());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void setPreloadedResults(
    List<FoodModel> foods,
    String query, {
    String region = 'BR',
    String language = 'pt',
  }) {
    state = state.copyWith(
      foods: foods,
      isLoading: false,
      isMoreLoading: false,
      query: query,
      currentPage: 0,
      currentRegion: region,
      currentLanguage: language,
      error: null,
    );
  }

  Future<void> search(String query, {String region = 'BR', String language = 'pt'}) async {
    if (query.isEmpty) {
      state = FoodSearchState.initial();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(query, region: region, language: language);
    });
  }

  Future<void> _performSearch(String query, {String region = 'BR', String language = 'pt'}) async {
    state = state.copyWith(
      isLoading: true,
      query: query,
      currentPage: 0,
      hasMore: true,
      currentRegion: region,
      currentLanguage: language,
      error: null,
    );

    try {
      // Phase 1: Instant local results (Progressive UI)
      final localResults = await LocalFoodDb.search(query);
      final userResults = await _userStorage.search(query);
      
      final instantMerged = [...userResults, ...localResults];
      instantMerged.sort((a, b) => _scoreRelevance(query, b).compareTo(_scoreRelevance(query, a)));
      
      state = state.copyWith(foods: instantMerged);

      // Phase 2: API results
      List<FoodModel> regionalFatSecret = [];
      List<FoodModel> offResults = [];
      List<FoodModel> globalFatSecret = [];

      if (region == 'BR') {
        final results = await Future.wait([
          _fatSecret.searchFoods(query, pageNumber: 0, region: 'BR', language: 'pt').catchError((e) {
            debugPrint('FATSECRET BR ERROR: $e');
            return <FoodModel>[];
          }),
          _off.searchProducts(query).catchError((e) {
            debugPrint('OFF ERROR: $e');
            return <FoodModel>[];
          }),
          _fatSecret.searchFoods(query, pageNumber: 0, region: 'US', language: 'en').catchError((e) {
            debugPrint('FATSECRET US ERROR: $e');
            return <FoodModel>[];
          }),
        ]);
        regionalFatSecret = results[0];
        offResults = results[1];
        globalFatSecret = results[2];
      } else {
        regionalFatSecret = await _fatSecret.searchFoods(query, pageNumber: 0, region: region, language: language);
      }

      // Merge and Rank everything
      final seenIds = <String>{};
      final allRegional = [...userResults, ...localResults, ...offResults, ...regionalFatSecret]
          .where((f) {
            // Only discard if truly empty/placeholder AND not a local/custom item
            final isLocal = f.id.startsWith('local_') || f.id.startsWith('custom_') || f.id.startsWith('taco_');
            final hasRealData = !f.description.contains('indisponíveis') && 
                               !f.description.contains('Cals: 0kcal');
            
            return seenIds.add(f.id) && (isLocal || hasRealData);
          }).toList();

      // Smart Ranking
      allRegional.sort((a, b) {
        final scoreA = _scoreRelevance(query, a);
        final scoreB = _scoreRelevance(query, b);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        
        // Tie-breaker: prefer local/user results
        final aIsLocal = a.id.startsWith('local_') || a.id.startsWith('custom_') || a.id.startsWith('taco_');
        final bIsLocal = b.id.startsWith('local_') || b.id.startsWith('custom_') || b.id.startsWith('taco_');
        if (aIsLocal && !bIsLocal) return -1;
        if (!aIsLocal && bIsLocal) return 1;
        
        return 0;
      });

      final mergedGlobal = globalFatSecret
          .where((f) => !seenIds.contains(f.id))
          .map((f) => f.copyWith(id: 'global_${f.id}'))
          .toList();

      // Always show global results if we found few regional ones (< 5)
      final showGlobal = allRegional.length < 5;

      state = state.copyWith(
        isLoading: false,
        foods: allRegional,
        globalFoods: showGlobal ? mergedGlobal : [],
      );
    } catch (e) {
      debugPrint('Search major failure: $e');
      // Preserve any local results we already found — only show error if truly empty
      if (state.foods.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Erro na busca: $e');
      } else {
        state = state.copyWith(isLoading: false, error: null);
      }
    }
  }

  int _scoreRelevance(String query, FoodModel food) {
    // Utility to strip accents for better matching
    String normalize(String text) {
      const withDia = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÑñÇç';
      const withoutDia = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuNnCc';
      String result = text;
      for (int i = 0; i < withDia.length; i++) {
        result = result.replaceAll(withDia[i], withoutDia[i]);
      }
      return result.toLowerCase();
    }

    final name = normalize(food.name);
    final q = normalize(query);
    final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();
    
    // Exact match
    if (name == q) return 100;
    // Starts with full query
    if (name.startsWith(q)) return 90;
    // Contains full query as substring
    if (name.contains(q)) return 80;
    
    // Multi-token: all tokens match in name
    if (tokens.length > 1) {
      final allMatch = tokens.every((t) => name.contains(t));
      if (allMatch) return 70;
    }
    
    // Brand match
    final brand = food.brand != null ? normalize(food.brand!) : '';
    if (brand.contains(q)) return 50;
    
    // Partial token match: count how many tokens appear
    final matchCount = tokens.where((t) => name.contains(t) || brand.contains(t)).length;
    if (matchCount > 0) {
      // Score 20-45 based on fraction of tokens matched
      return 20 + ((matchCount / tokens.length) * 25).round();
    }
    
    return 10;
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isMoreLoading || state.query.isEmpty || !state.hasMore) return;

    state = state.copyWith(isMoreLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final results = await _fatSecret.searchFoods(
        state.query, 
        pageNumber: nextPage,
        region: state.currentRegion,
        language: state.currentLanguage,
      );
      
      state = state.copyWith(
        isMoreLoading: false,
        foods: [...state.foods, ...results],
        currentPage: nextPage,
        hasMore: results.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isMoreLoading: false, hasMore: false, error: e.toString());
    }
  }
}

final foodSearchProvider = StateNotifierProvider<FoodSearchNotifier, FoodSearchState>((ref) {
  final fatSecret = ref.watch(fatSecretServiceProvider);
  final off = ref.watch(openFoodFactsServiceProvider);
  final userStorage = ref.watch(userFoodStorageProvider);
  return FoodSearchNotifier(fatSecret, off, userStorage);
});

final filteredFoodsProvider = Provider<List<FoodModel>>((ref) {
  final searchState = ref.watch(foodSearchProvider);
  final hideIncomplete = ref.watch(filterCompleteInfoProvider);
  
  if (!hideIncomplete) return searchState.foods;
  
  // Secondary strict filter if user enabled the 'Hide Incomplete' toggle
  return searchState.foods.where((food) {
    final hasAllMacros = food.description.contains('Cals:') && 
           food.description.contains('Fat:') && 
           food.description.contains('Carbs:') && 
           food.description.contains('Prot:');
    final isLocal = food.id.startsWith('local_') || food.id.startsWith('custom_');
    return hasAllMacros || isLocal;
  }).toList();
});

final foodDetailsProvider = FutureProvider.family<FoodDetails, String>((ref, foodId) async {
  if (foodId.startsWith('custom_')) {
    final storage = ref.watch(userFoodStorageProvider);
    final foods = await storage.getFoods();
    final food = foods.firstWhere((f) => f.id == foodId);
    
    // Parse description for macros if needed, or structured description
    // For custom foods, we store detailed macro info in description string
    // "Cals: 100kcal | Fat: 5g | Carbs: 10g | Prot: 8g"
    return FoodDetails(
      id: food.id,
      name: food.name,
      description: food.description,
      brand: food.brand,
      servings: [], // Custom foods currently store macros in description
    );
  } else if (foodId.startsWith('off_')) {
    final service = ref.watch(openFoodFactsServiceProvider);
    return service.getProductDetails(foodId);
  } else if (foodId.startsWith('global_')) {
    final cleanId = foodId.replaceFirst('global_', '');
    final fatSecret = ref.read(fatSecretServiceProvider);
    return fatSecret.getFoodDetails(cleanId, region: 'US', language: 'en');
  } else if (foodId.startsWith('local_') || foodId.startsWith('taco_')) {
    final details = await LocalFoodDb.getDetails(foodId);
    if (details != null) return details;
    throw Exception('Alimento não encontrado na base local.');
  } else {
    final service = ref.watch(fatSecretServiceProvider);
    return service.getFoodDetails(foodId);
  }
});
