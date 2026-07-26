import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../data/models/food_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

final nutritionPlanProvider =
    FutureProvider.family<NutritionPlanModel?, (String, String)>(
  (ref, params) {
    final (userId, diaSemana) = params;
    return ref.read(nutritionRepositoryProvider).getPlan(userId, diaSemana);
  },
);

final foodSearchProvider =
    FutureProvider.family<List<FoodModel>, String>((ref, query) {
  if (query.isEmpty) return ref.read(nutritionRepositoryProvider).getAllFoods();
  return ref.read(nutritionRepositoryProvider).searchFoods(query);
});

/// Ecrã de nutrição — Kinetic Dark.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  int _selectedDayIndex = DateTime.now().weekday - 1;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final diaSemana = AppStrings.daysOfWeek[_selectedDayIndex];
    final planAsync = ref.watch(nutritionPlanProvider((userId, diaSemana)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.nutritionPlan,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showFoodSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDaySelector(),
          const Divider(height: 1, color: AppColors.outline),
          Expanded(
            child: planAsync.when(
              data: (plan) {
                if (plan == null) {
                  return const EmptyState(
                    icon: Icons.restaurant_menu,
                    title: AppStrings.noPlanAssigned,
                  );
                }
                return _buildPlanView(plan);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) =>
                  const EmptyState(icon: Icons.error_outline, title: 'Erro'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 52,
      color: AppColors.surfaceLow,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppStrings.daysOfWeekShort[index],
                style: GoogleFonts.inter(
                  color: isSelected
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanView(NutritionPlanModel plan) {
    final consumedCalories = 0.0;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(nutritionPlanProvider(
          (plan.userId, AppStrings.daysOfWeek[_selectedDayIndex]))),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaloriesBar(plan, consumedCalories),
            const SizedBox(height: 24),
            Text(
              'Refeições do dia',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (plan.refeicoes.isEmpty)
              const EmptyState(
                icon: Icons.no_food,
                title: 'Nenhuma refeição planeada para este dia.',
              )
            else
              ...plan.refeicoes.map((meal) => _buildMealCard(plan, meal)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesBar(NutritionPlanModel plan, double consumed) {
    final progress =
        plan.metaCalorias > 0 ? consumed / plan.metaCalorias : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            AppStrings.caloriesConsumed,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${consumed.toStringAsFixed(0)} / ${plan.metaCalorias.toStringAsFixed(0)} kcal',
            style: GoogleFonts.montserrat(
              color: AppColors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.outline,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(NutritionPlanModel plan, PlannedMeal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.caloriesLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child:
              const Icon(Icons.restaurant, color: AppColors.calories, size: 18),
        ),
        title: Text(
          meal.tipo,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          '${meal.totalCalorias.toStringAsFixed(0)} kcal • ${meal.alimentos.length} alimentos',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${meal.totalCalorias.toStringAsFixed(0)} kcal',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.calories,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
        children: [
          if (meal.instrucoes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                meal.instrucoes!,
                style: GoogleFonts.inter(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ...meal.alimentos.map(
            (alimento) => ListTile(
              dense: true,
              title: Text(
                alimento.nome,
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              subtitle: Text(
                alimento.quantidade,
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              trailing: Text(
                '${alimento.calorias.toStringAsFixed(0)} kcal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markMealDone(plan.userId, meal),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Concluir refeição'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMealDone(String userId, PlannedMeal meal) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    final now = DateFormat('HH:mm').format(DateTime.now());
    try {
      await ref.read(diaryRepositoryProvider).addMeal(userId, today, {
        'tipo': meal.tipo,
        'descricao': meal.alimentos.map((a) => a.nome).join(', '),
        'calorias': meal.totalCalorias,
        'hora': now,
        'alimentos': meal.alimentos.map((a) => a.nome).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.mealCompleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.networkError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFoodSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) => _FoodSearchSheet(
          onFoodSelected: (food) {
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  final Function(FoodModel) onFoodSelected;
  const _FoodSearchSheet({required this.onFoodSelected});

  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppStrings.searchFood,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (q) => setState(() => _query = q.trim()),
            style: GoogleFonts.inter(color: AppColors.onSurface),
          ),
        ),
        Expanded(
          child: ref.watch(foodSearchProvider(_query)).when(
            data: (foods) => ListView.builder(
              itemCount: foods.length,
              itemBuilder: (_, i) {
                final food = foods[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.caloriesLight,
                    child: Text(
                      food.nome[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppColors.calories,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    food.nome,
                    style: GoogleFonts.inter(color: AppColors.onSurface),
                  ),
                  subtitle: Text(
                    '${food.caloriasPor100g.toStringAsFixed(0)} kcal/100g',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary),
                  onTap: () => widget.onFoodSelected(food),
                );
              },
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (_, __) => const Center(
              child: Text('Erro', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }
}
