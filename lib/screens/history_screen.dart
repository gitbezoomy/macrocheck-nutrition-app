import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/meal_provider.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Normalize day to local midnight for comparison with calendar days
  DateTime _normalizeDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<Map<String, dynamic>> _getMealsForDay(List<Map<String, dynamic>> allHistory, DateTime day) {
    final normalizedSearchDay = _normalizeDay(day);
    return allHistory.where((meal) {
      final mealDate = DateTime.parse(meal['date']);
      return isSameDay(mealDate, normalizedSearchDay);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).translate('nutritional_calendar'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, color: Color(0xFF2D3142)),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (allHistory) {
          final meals = _getMealsForDay(allHistory, _selectedDay!);
          final macros = _calculateDailyMacros(meals);
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildCalendar(allHistory),
              ),
              SliverToBoxAdapter(
                child: _buildMacrosSummary(macros),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 8),
              ),
              meals.isEmpty 
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final meal = meals[index];
                          return _buildMealCard(meal);
                        },
                        childCount: meals.length,
                      ),
                    ),
                  ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120), // Reduced from 100 to be safer and match MainScreen bottom nav padding plus extra
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  Map<String, double> _calculateDailyMacros(List<Map<String, dynamic>> meals) {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var meal in meals) {
      calories += (meal['totalCalories'] as num).toDouble();
      final items = meal['items'] as List;
      for (var item in items) {
        protein += (item['protein'] as num?)?.toDouble() ?? 0.0;
        carbs += (item['carbs'] as num?)?.toDouble() ?? 0.0;
        fat += (item['fat'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  Widget _buildCalendar(List<Map<String, dynamic>> allHistory) {
    final locale = ref.watch(localeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mês',
          CalendarFormat.week: 'Semana',
        },
        locale: locale.toString(),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A96B), fontSize: 12),
          weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE57373), fontSize: 12),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Color(0x3387A96B), shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Color(0xFF87A96B), shape: BoxShape.circle),
          markersMaxCount: 1,
          markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          cellMargin: EdgeInsets.all(4),
        ),
        eventLoader: (day) => _getMealsForDay(allHistory, day),
      ),
    );
  }

  Widget _buildMacrosSummary(Map<String, double> macros) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildMacroCard('Proteína', macros['protein']!, const Color(0xFF87A96B)),
          const SizedBox(width: 8),
          _buildMacroCard('Carbos', macros['carbs']!, const Color(0xFF4A90E2)),
          const SizedBox(width: 8),
          _buildMacroCard('Gordura', macros['fat']!, const Color(0xFFF5A623)),
          const SizedBox(width: 8),
          _buildMacroCard('Total', macros['calories']!, Colors.grey.shade700, unit: 'kcal'),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, double value, Color color, {String unit = 'g'}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toInt()}$unit',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF2D3142)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final locale = ref.watch(localeProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_meals_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '${AppLocalizations.of(context).translate('no_records_on')} ${DateFormat('dd/MM', locale.languageCode).format(_selectedDay!)}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final locale = ref.watch(localeProvider);
    final mealDate = DateTime.parse(meal['date']);
    final time = DateFormat('HH:mm', locale.languageCode).format(mealDate);
    final items = meal['items'] as List;
    final totalCals = (meal['totalCalories'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A96B))),
          ],
        ),
        title: Text('${totalCals.toInt()} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${items.length} ${AppLocalizations.of(context).translate('items_recorded')}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () => _confirmDelete(meal['date']),
        ),
        children: [
          ...items.map((item) {
            final imageUrl = item['imageUrl'] as String?;
            return ListTile(
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  color: Colors.grey.shade50,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('assets/')
                          ? Image.asset(imageUrl, fit: BoxFit.cover)
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.restaurant_rounded, size: 16, color: Colors.grey),
                            ))
                      : const Icon(Icons.restaurant_rounded, size: 16, color: Colors.grey),
                ),
              ),
              title: Text(item['name'] ?? 'Desconhecido'),
              trailing: Text(
                '${(item['amount'] as num).toInt()}g • ${(item['calories'] as num).toInt()} kcal',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _confirmDelete(String dateTimeIso) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: const Text('Deseja realmente excluir este registro de refeição?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(historyProvider.notifier).deleteMeal(dateTimeIso);
              if (context.mounted) Navigator.pop(context);
              // Invalidate dailyStats so the dashboard updates
              ref.invalidate(dailyStatsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
