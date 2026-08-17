import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/food_model.dart';
import '../screens/details_screen.dart';

class FoodCard extends StatelessWidget {
  final FoodModel food;
  final VoidCallback? onTap;

  const FoodCard({super.key, required this.food, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sourceIcon = _sourceIcon();
    final sourceColor = _sourceColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsScreen(foodId: food.id, foodName: food.name),
              ),
            );
          },
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildLeading(sourceColor, sourceIcon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                food.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2D3142),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSourceBadge(),
                          ],
                        ),
                      if (food.brand != null)
                        Text(
                          food.brand!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      _buildMacroRow(food.description),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon() {
    return Icons.local_dining_rounded; // Standardize on the Fork & Knife icon
  }

  Color _sourceColor() {
    return const Color(0xFF87A96B); // Standardize on the green aesthetic
  }

  Widget _buildLeading(Color sourceColor, IconData sourceIcon) {
    if (food.imageUrl != null && food.imageUrl!.isNotEmpty) {
      final isAsset = food.imageUrl!.startsWith('assets/');
      
      return Hero(
        tag: 'food_image_${food.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 60,
            height: 60,
            color: Colors.grey.shade50,
            child: isAsset
              ? Image.asset(food.imageUrl!, fit: BoxFit.cover)
              : CachedNetworkImage(
                  imageUrl: food.imageUrl!,
                  fit: BoxFit.cover,
                  width: 60,
                  height: 60,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: sourceColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(sourceColor, sourceIcon),
                ),
          ),
        ),
      );
    }
    return _buildPlaceholder(sourceColor, sourceIcon);
  }

  Widget _buildPlaceholder(Color sourceColor, IconData sourceIcon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: sourceColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(sourceIcon, color: sourceColor),
    );
  }

  Widget _buildSourceBadge() {
    String label = '';
    Color color = Colors.grey;
    if (food.id.startsWith('local_')) {
      label = 'TACO';
      color = const Color(0xFF87A96B);
    } else if (food.id.startsWith('custom_')) {
      label = 'MEU';
      color = Colors.blue;
    } else if (food.id.startsWith('off_')) {
      label = 'OFF';
      color = Colors.orange;
    } else if (food.id.startsWith('global_')) {
      label = 'US';
      color = Colors.red;
    } else {
      label = 'FS';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMacroRow(String description) {
    final macros = _parseMacros(description);
    if (macros == null) {
      return Text(
        description,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    String format(String? val) {
      if (val == null) return '0';
      final num = double.tryParse(val);
      if (num == null) return val;
      if (num == num.toInt()) return num.toInt().toString();
      return num.toStringAsFixed(1);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _macroBadge('🔥 ${format(macros['cals'])} kcal', Colors.orange),
        _macroBadge('💪 ${format(macros['prot'])}g P', const Color(0xFF87A96B)),
        _macroBadge('🍞 ${format(macros['carb'])}g C', Colors.blueAccent),
        _macroBadge('🥑 ${format(macros['fat'])}g G', Colors.redAccent),
      ],
    );
  }

  Widget _macroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Map<String, String>? _parseMacros(String desc) {
    try {
      // Support both "Calories:" (FatSecret) and "Cals:" (local/OFF)
      final calMatch = RegExp(r'(?:Calories|Cals): (\d+)').firstMatch(desc);
      final fatMatch = RegExp(r'Fat: ([\d.]+)').firstMatch(desc);
      final carbMatch = RegExp(r'Carbs: ([\d.]+)').firstMatch(desc);
      final protMatch = RegExp(r'(?:Protein|Prot): ([\d.]+)').firstMatch(desc);

      if (calMatch == null) return null;

      return {
        'cals': calMatch.group(1) ?? '0',
        'fat': fatMatch?.group(1) ?? '0',
        'carb': carbMatch?.group(1) ?? '0',
        'prot': protMatch?.group(1) ?? '0',
      };
    } catch (_) {
      return null;
    }
  }
}
