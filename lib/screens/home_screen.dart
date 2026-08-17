import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/food_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/history_provider.dart';
import '../models/food_model.dart';
import '../widgets/food_card.dart';
import '../widgets/daily_dashboard.dart';
import '../l10n/app_localizations.dart';
import 'details_screen.dart';
import '../services/local_food_db.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final SearchController _searchController = SearchController();
  final Map<String, List<FoodModel>> _searchCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // Debounced search logic could go here if needed, 
      // but we handle it inside the suggestionsBuilder now.
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(foodSearchProvider);
    final foods = ref.watch(filteredFoodsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá!',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              AppLocalizations.of(context).translate('find_food'),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2D3142),
                                  letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                      _buildRegionSelector(),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SearchAnchor(
                    searchController: _searchController,
                    builder: (BuildContext context, SearchController controller) {
                      return SearchBar(
                        controller: controller,
                        padding: const WidgetStatePropertyAll<EdgeInsets>(
                            EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)),
                        onTap: () {
                          controller.openView();
                        },
                        onChanged: (_) {
                          controller.openView();
                        },
                        leading: const Icon(Icons.search_rounded, color: Color(0xFF87A96B)),
                        hintText: AppLocalizations.of(context).translate('search_hint'),
                        hintStyle: WidgetStatePropertyAll<TextStyle>(
                            TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                        elevation: const WidgetStatePropertyAll<double>(0),
                        backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
                        shape: WidgetStatePropertyAll<OutlinedBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      );
                    },
                    suggestionsBuilder: (BuildContext context, SearchController controller) {
                      final query = controller.text.trim();
                      
                      return [
                        Consumer(
                          builder: (context, ref, child) {
                            final searchState = ref.watch(foodSearchProvider);
                            final region = ref.watch(regionProvider);

                            // Trigger search if query changed
                            if (query.isNotEmpty && searchState.query != query && !searchState.isLoading) {
                              Future.microtask(() {
                                ref.read(foodSearchProvider.notifier).search(
                                  query, 
                                  region: region, 
                                  language: region == 'BR' ? 'pt' : 'en'
                                );
                              });
                            }

                            if (query.isEmpty) {
                              return _buildSearchPlaceholder(context, controller);
                            }

                            if (searchState.isLoading && searchState.foods.isEmpty) {
                              return _buildShimmerLoading();
                            }

                            final List<Widget> suggestionWidgets = [];
                            
                            if (searchState.foods.isNotEmpty) {
                              suggestionWidgets.add(
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                                  child: Text(region == 'BR' ? AppLocalizations.of(context).translate('results_in_brazil') : AppLocalizations.of(context).translate('common_foods'), 
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                )
                              );
                              suggestionWidgets.addAll(
                                searchState.foods.take(20).map((food) => _buildSearchSuggestion(food, controller, ref, searchState.foods))
                              );
                            }

                            if (region == 'BR' && searchState.globalFoods.isNotEmpty) {
                              suggestionWidgets.add(
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                                  child: Text(AppLocalizations.of(context).translate('global_results'), 
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                )
                              );
                              suggestionWidgets.addAll(
                                searchState.globalFoods.take(10).map((food) => _buildSearchSuggestion(food, controller, ref, searchState.globalFoods))
                              );
                            }

                            // Show error if search failed (with any partial results still visible)
                            if (searchState.error != null && suggestionWidgets.isEmpty) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 32),
                                  const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchState.error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      ref.read(foodSearchProvider.notifier).search(
                                        query,
                                        region: region,
                                        language: region == 'BR' ? 'pt' : 'en',
                                      );
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: Text(AppLocalizations.of(context).translate('try_again')),
                                  ),
                                ],
                              );
                            }

                            if (suggestionWidgets.isEmpty && !searchState.isLoading) {
                              return const ListTile(title: Text('Nenhum resultado encontrado'));
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: suggestionWidgets,
                            );
                          },
                        )
                      ];
                    },
                  ),
                ),
              ),

              // Daily Calorie Counter Dashboard
              const SliverToBoxAdapter(
                child: DailyDashboard(),
              ),

              // Status info
              if (searchState.foods.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      '${foods.length} ${AppLocalizations.of(context).translate('results_found')}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ),

              // Results List
              if (searchState.isLoading)
                SliverFillRemaining(
                  child: _buildShimmerLoading(),
                )
              else if (searchState.error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context).translate('error_occurred'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchState.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(foodSearchProvider.notifier)
                                .search(_searchController.text),
                            child: Text(AppLocalizations.of(context).translate('try_again')),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (foods.isEmpty && searchState.query.isNotEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(AppLocalizations.of(context).translate('no_food_found'))),
                )
              else if (foods.isEmpty && searchState.query.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).translate('no_meals'),
                          style: const TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (searchState.currentRegion == 'BR' && foods.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Text('🇧🇷 ', style: TextStyle(fontSize: 18)),
                          Text(AppLocalizations.of(context).translate('results_in_brazil'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 13,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < foods.length) {
                          return FoodCard(food: foods[index]);
                        } else if (searchState.isMoreLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (searchState.hasMore) {
                          // Trigger load more only if there are more pages
                          Future.microtask(() => ref.read(foodSearchProvider.notifier).loadMore());
                          return const SizedBox.shrink();
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: foods.length + ((searchState.isMoreLoading || searchState.hasMore) ? 1 : 0),
                    ),
                  ),
                ),
                if (searchState.globalFoods.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                      child: Row(
                        children: [
                          const Text('🌎 ', style: TextStyle(fontSize: 18)),
                          Text(AppLocalizations.of(context).translate('global_results'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 13,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => FoodCard(food: searchState.globalFoods[index]),
                        childCount: searchState.globalFoods.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionSelector() {
    final region = ref.watch(regionProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: PopupMenuButton<String>(
        initialValue: region,
        padding: EdgeInsets.zero,
        onSelected: (value) {
          ref.read(regionProvider.notifier).state = value;
          ref.read(localeProvider.notifier).state = Locale(value == 'BR' ? 'pt' : 'en');
          if (_searchController.text.isNotEmpty) {
            ref.read(foodSearchProvider.notifier).search(_searchController.text, 
              region: value, 
              language: value == 'BR' ? 'pt' : 'en');
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'BR', child: Text('🇧🇷 Brasil')),
          const PopupMenuItem(value: 'US', child: Text('🇺🇸 Global')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(region == 'BR' ? '🇧🇷' : '🇺🇸', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPlaceholder(BuildContext context, SearchController controller) {
    return FutureBuilder<List<Widget>>(
      future: () async {
        final history = await ref.read(persistentSearchServiceProvider).getHistory();
        final userFoods = await ref.read(userFoodStorageProvider).getFoods();
        final popular = await LocalFoodDb.getPopular();
        
        final List<Widget> items = [];
        
        if (history.isNotEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context).translate('recent_searches'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                GestureDetector(
                  onTap: () async {
                    await ref.read(persistentSearchServiceProvider).clearHistory();
                    (context as Element).markNeedsBuild();
                  },
                  child: Text(AppLocalizations.of(context).translate('clear'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ));
          items.addAll(history.take(5).map((q) => ListTile(
            leading: const Icon(Icons.history, size: 20, color: Colors.grey),
            title: Text(q),
            onTap: () {
              controller.text = q;
              controller.selection = TextSelection.collapsed(offset: q.length);
            },
          )));
        }

        if (userFoods.isNotEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(AppLocalizations.of(context).translate('my_records'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          ));
          items.addAll(userFoods.take(3).map((f) => _buildSearchSuggestion(f, controller, ref, userFoods)));
        }

        if (popular.isNotEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(AppLocalizations.of(context).translate('common_foods'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          ));
          items.addAll(popular.take(5).map((f) => _buildSearchSuggestion(f, controller, ref, popular)));
        }

        return items;
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Column(children: snapshot.data!);
      },
    );
  }

  Widget _buildSearchSuggestion(FoodModel food, SearchController controller, WidgetRef ref, List<FoodModel> allLoadedFoods) {
    final region = ref.read(regionProvider);
    final language = region == 'BR' ? 'pt' : 'en';
    final persistent = ref.read(persistentSearchServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FoodCard(
        food: food,
        onTap: () {
          final query = food.name;
          persistent.saveQuery(query);
          HapticFeedback.lightImpact();
          controller.closeView(query);
          
          ref.read(foodSearchProvider.notifier).setPreloadedResults(allLoadedFoods, query, region: region, language: language);

          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(foodId: food.id, foodName: query)));
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.white,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
        ),
      ),
    );
  }
}
