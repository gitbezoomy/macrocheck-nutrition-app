import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/meal_provider.dart';
import '../providers/navigation_provider.dart';
import '../l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';


class DailyDashboard extends ConsumerWidget {
  const DailyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dailyStatsProvider);
    final goal = ref.watch(calorieGoalProvider);
    final dayCount = ref.watch(dayCountProvider);

    return statsAsync.when(
      data: (stats) {
        final consumed = stats['calories']!;
        final progress = (consumed / goal).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 190, // Stable fixed height instead of IntrinsicHeight
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Calorie Bento
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => ref.read(navigationProvider.notifier).state = 1,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF87A96B),
                            const Color(0xFF87A96B).withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF87A96B).withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space instead of Spacer
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Dia $dayCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                                onPressed: () => _showEditGoalDialog(context, ref, goal),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).translate('calories'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${consumed.toInt()}',
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0),
                              ),
                              Text(
                                'de ${goal.toInt()} kcal',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Macros Bento Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildMacroBento(context, 'Prot', stats['protein']!, const Color(0xFF87A96B)),
                      const SizedBox(height: 6),
                      _buildMacroBento(context, 'Carb', stats['carbs']!, const Color(0xFF4A90E2)),
                      const SizedBox(height: 6),
                      _buildMacroBento(context, 'Gord', stats['fat']!, const Color(0xFFF5A623)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const _DashboardSkeleton(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  void _showEditGoalDialog(BuildContext context, WidgetRef ref, double currentGoal) {
    final controller = TextEditingController(text: currentGoal.toInt().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('edit_goal')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).translate('set_goal'),
            suffixText: 'kcal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('close')),
          ),
          ElevatedButton(
            onPressed: () {
              final newGoal = double.tryParse(controller.text);
              if (newGoal != null && newGoal > 0) {
                ref.read(calorieGoalProvider.notifier).setGoal(newGoal);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context).translate('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBento(BuildContext context, String label, double value, Color color) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${value.toInt()}g',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2D3142)),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.white,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}
