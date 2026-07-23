import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../data/models/food_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

/// Provider do plano nutricional do dia.
final nutritionPlanProvider =
    FutureProvider.family<NutritionPlanModel?, (String, String)>(
  (ref, params) {
    final (userId, diaSemana) = params;
    return ref.read(nutritionRepositoryProvider).getPlan(userId, diaSemana);
  },
);

/// Provider de pesquisa de alimentos.
final foodSearchProvider =
    FutureProvider.family<List<FoodModel>, String>((ref, query) {
  if (query.isEmpty) {
    return ref.read(nutritionRepositoryProvider).getAllFoods();
  }
  return ref.read(nutritionRepositoryProvider).searchFoods(query);
});

/// Ecrã de nutrição do aluno.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  int _selectedDayIndex = DateTime.now().weekday - 1; // 0 = Segunda
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final diaSemana = AppStrings.daysOfWeek[_selectedDayIndex];
    final planAsync = ref.watch(nutritionPlanProvider((userId, diaSemana)));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.nutritionPlan),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showFoodSearch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de dia da semana
          _buildDaySelector(),
          const Divider(height: 1),
          // Conteúdo do plano
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
      height: 50,
      color: AppColors.primary.withValues(alpha: 0.05),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppStrings.daysOfWeekShort[index],
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanView(NutritionPlanModel plan) {
    final consumedCalories = 0.0; // Integrar com diário no futuro

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nutritionPlanProvider(
            (plan.userId, AppStrings.daysOfWeek[_selectedDayIndex])));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de calorias
            _buildCaloriesBar(plan, consumedCalories),
            const SizedBox(height: 24),

            // Lista de refeições
            Text(
              'Refeições do dia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.calories, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            AppStrings.caloriesConsumed,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${consumed.toStringAsFixed(0)} / ${plan.metaCalorias.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(NutritionPlanModel plan, PlannedMeal meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.caloriesLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.restaurant, color: AppColors.calories),
        ),
        title: Text(
          meal.tipo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${meal.totalCalorias.toStringAsFixed(0)} kcal • ${meal.alimentos.length} alimentos',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${meal.totalCalorias.toStringAsFixed(0)} kcal',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.calories,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (meal.instrucoes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                meal.instrucoes!,
                style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary),
              ),
            ),
          ...meal.alimentos.map(
            (alimento) => ListTile(
              dense: true,
              title: Text(alimento.nome),
              subtitle: Text(alimento.quantidade),
              trailing: Text(
                '${alimento.calorias.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const Divider(),
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
                  foregroundColor: Colors.white,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) => _FoodSearchSheet(
          onFoodSelected: (food) {
            Navigator.pop(ctx);
            // Adicionar alimento extra
          },
        ),
      ),
    );
  }
}

/// Sheet de pesquisa de alimentos.
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            onChanged: (q) => setState(() => _query = q.trim()),
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
                      style: const TextStyle(color: AppColors.calories),
                    ),
                  ),
                  title: Text(food.nome),
                  subtitle: Text(
                    '${food.caloriasPor100g.toStringAsFixed(0)} kcal/100g',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => widget.onFoodSelected(food),
                );
              },
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Erro')),
          ),
        ),
      ],
    );
  }
}
