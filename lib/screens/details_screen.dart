import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/food_provider.dart';
import '../providers/meal_provider.dart';
import '../models/food_model.dart';
import '../models/meal_item.dart';
import '../l10n/app_localizations.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String foodId;
  final String foodName;

  const DetailsScreen(
      {super.key, required this.foodId, required this.foodName});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final TextEditingController _quantityController =
      TextEditingController(text: '100');
  Serving? _selectedServing;

  bool get _isUnitBased => _selectedServing?.isUnit ?? false;

  String _getUnitLabel() {
    if (_selectedServing == null) return 'g / ml';
    if (!_isUnitBased) return _selectedServing!.metricServingUnit;
    
    final unit = _selectedServing!.measurementDescription?.toLowerCase() ?? 'unid.';
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;
    
    if (quantity <= 1) return unit;

    // Robust pluralization for Portuguese
    if (unit == 'unid.' || unit == 'unidade') return unit;
    if (unit.endsWith('m')) return '${unit.substring(0, unit.length - 1)}ns'; // bombom -> bombons
    if (unit.endsWith('r') || unit.endsWith('z')) return '${unit}es'; // hambúrguer -> hambúrgueres
    if (unit.endsWith('s')) return unit; // stays same (simples, lápis)
    
    // Default Portuguese plural: ends with vowel/other -> add 's'
    return '${unit}s';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(foodDetailsProvider(widget.foodId));
    final quantity = double.tryParse(_quantityController.text) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFA),
      appBar: AppBar(
        title: Text(widget.foodName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: detailsAsync.when(
        data: (details) {
          _selectedServing ??= details.defaultServing;

          final double factor;
          if (_isUnitBased) {
            factor = quantity;
          } else {
            final baseAmount = _selectedServing!.metricServingAmount > 0 
                ? _selectedServing!.metricServingAmount 
                : 100.0;
            factor = quantity / baseAmount;
          }
          
          final cal = _selectedServing!.calories * factor;
          final prot = _selectedServing!.protein * factor;
          final carb = _selectedServing!.carbohydrate * factor;
          final fat = _selectedServing!.fat * factor;

          final fiber = (_selectedServing!.fiber ?? 0) * factor;
          final sugar = (_selectedServing!.sugar ?? 0) * factor;
          final sodium = (_selectedServing!.sodium ?? 0) * factor;
          final potas = (_selectedServing!.potassium ?? 0) * factor;
          final chol = (_selectedServing!.cholesterol ?? 0) * factor;
          final vitA = (_selectedServing!.vitaminA ?? 0) * factor;
          final vitC = (_selectedServing!.vitaminC ?? 0) * factor;
          final calc = (_selectedServing!.calcium ?? 0) * factor;
          final iron = (_selectedServing!.iron ?? 0) * factor;
          final satFat = (_selectedServing!.saturatedFat ?? 0) * factor;
          final trans = (_selectedServing!.transFat ?? 0) * factor;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.imageUrl != null && details.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Center(
                      child: Hero(
                        tag: 'food_image_${widget.foodId}',
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                details.imageUrl!.startsWith('assets/')
                                    ? Image.asset(details.imageUrl!, fit: BoxFit.cover)
                                    : Image.network(
                                        details.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Center(child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey)),
                                      ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ),
                ),

                _buildServingSelector(details),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Atalhos:',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ...details.servings.take(2).map((s) {
                      final label = s.measurementDescription != null 
                        ? _translateShorthand(s.measurementDescription!)
                        : '${s.metricServingAmount.toInt()}${s.metricServingUnit}';
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: _buildPresetChip(label, s),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                _buildQuantitySelector(details),
                const SizedBox(height: 24),

                _buildMainCaloriesCard(cal),
                const SizedBox(height: 32),

                Text(
                  AppLocalizations.of(context).translate('macronutrients'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildMacroCard(
                          AppLocalizations.of(context).translate('protein'),
                          '${prot.toStringAsFixed(1)}g',
                          const Color(0xFF87A96B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMacroCard(
                          AppLocalizations.of(context).translate('carbs'),
                          '${carb.toStringAsFixed(1)}g',
                          const Color(0xFF4A90E2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMacroCard(
                          AppLocalizations.of(context).translate('fat'),
                          '${fat.toStringAsFixed(1)}g',
                          const Color(0xFFF5A623)),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Text(
                  AppLocalizations.of(context).translate('caloric_distribution'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: _buildMacrosChart(prot, carb, fat),
                ),

                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Tabela Nutricional Completa',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142)),
                    ),
                    children: [
                      _buildNutrientGroup('Gorduras e Fibras', [
                        _nutrientRow('Fibras', fiber, 'g'),
                        _nutrientRow('Açúcares', sugar, 'g'),
                        _nutrientRow('Gordura Saturada', satFat, 'g'),
                        _nutrientRow('Gordura Trans', trans, 'g'),
                      ]),
                      _buildNutrientGroup('Minerais e Colesterol', [
                        _nutrientRow('Sódio', sodium, 'mg'),
                        _nutrientRow('Potássio', potas, 'mg'),
                        _nutrientRow('Colesterol', chol, 'mg'),
                      ]),
                      _buildNutrientGroup('Vitaminas e Minerais', [
                        _nutrientRow('Cálcio', calc, 'mg'),
                        _nutrientRow('Ferro', iron, 'mg'),
                        _nutrientRow('Vitamina A', vitA, 'mcg'),
                        _nutrientRow('Vitamina C', vitC, 'mg'),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(mealProvider.notifier).addFood(
                            MealItem(
                              id: details.id,
                              name: details.name,
                              amount: _isUnitBased 
                                  ? quantity * _selectedServing!.metricServingAmount 
                                  : quantity,
                              calories: cal,
                              protein: prot,
                              carbs: carb,
                              fat: fat,
                              addedAt: DateTime.now(),
                              imageUrl: details.imageUrl,
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${details.name} ${AppLocalizations.of(context).translate('added_success')}'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF87A96B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF87A96B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(AppLocalizations.of(context).translate('add_to_meal'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Info base: ${_selectedServing!.servingDescription} (${_selectedServing!.calories.toInt()} kcal)',
                          style:
                              TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar detalhes: $err')),
      ),
    );
  }

  Widget _buildServingSelector(FoodDetails details) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).translate('serving_base'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF2D3142))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBF9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Serving>(
                isExpanded: true,
                value: _selectedServing,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF87A96B)),
                items: details.servings.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.servingDescription,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedServing = val;
                    if (val != null) {
                      if (val.isUnit) {
                        _quantityController.text = '1';
                      } else if (val.metricServingAmount > 0) {
                        _quantityController.text =
                            val.metricServingAmount.toInt().toString();
                      }
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(FoodDetails details) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).translate('quantity'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF2D3142))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() {}),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: _getUnitLabel(),
                    hintText: _isUnitBased ? '1' : '100',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFFBFBF9),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ...details.servings.take(2).map((s) {
                final label = s.measurementDescription != null 
                  ? _translateShorthand(s.measurementDescription!)
                  : '${s.metricServingAmount.toInt()}${s.metricServingUnit}';
                return Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: _buildPresetChip(label, s),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _translateShorthand(String desc) {
    desc = desc.toLowerCase();
    if (desc.contains('unidade') || desc.contains('unit')) return 'Unid.';
    if (desc.contains('medium')) return 'Méd.';
    if (desc.contains('small')) return 'Peq.';
    if (desc.contains('large')) return 'Grd.';
    if (desc.contains('slice')) return 'Fat.';
    return desc;
  }

  Widget _buildPresetChip(String label, Serving serving) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: () {
        setState(() {
          _selectedServing = serving;
          if (_isUnitBased) {
            _quantityController.text = '1';
          } else {
            _quantityController.text = serving.metricServingAmount.toInt().toString();
          }
        });
      },
      backgroundColor: const Color(0xFF87A96B).withValues(alpha: 0.05),
      side: BorderSide(color: const Color(0xFF87A96B).withValues(alpha: 0.1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildMainCaloriesCard(double calories) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF87A96B), Color(0xFF9EAFC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF87A96B).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('total_energy'),
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            '${calories.toInt()} kcal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosChart(double prot, double carb, double fat) {
    final total = prot + carb + fat;
    if (total == 0) return const Center(child: Text('Sem dados nutricionais'));

    return PieChart(
      PieChartData(
        sectionsSpace: 6,
        centerSpaceRadius: 45,
        sections: [
          PieChartSectionData(
            value: prot,
            title: '${prot.toStringAsFixed(1)}g',
            color: const Color(0xFF87A96B),
            radius: 50,
            titleStyle: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: carb,
            title: '${carb.toStringAsFixed(1)}g',
            color: const Color(0xFF4A90E2),
            radius: 50,
            titleStyle: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: fat,
            title: '${fat.toStringAsFixed(1)}g',
            color: const Color(0xFFF5A623),
            radius: 50,
            titleStyle: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientGroup(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _nutrientRow(String label, double value, String unit) {
    if (value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            '${value >= 10 ? value.toInt() : value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142)),
          ),
        ],
      ),
    );
  }
}
