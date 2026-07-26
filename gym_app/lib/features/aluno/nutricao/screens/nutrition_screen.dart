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

/// Calorias totais já consumidas hoje (do diário).
final todayConsumedCaloriesProvider =
    StreamProvider.family<double, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref
      .read(diaryRepositoryProvider)
      .diaryEntryStream(userId, today)
      .map((diary) => diary?.totalCalorias ?? 0.0);
});

/// Tipos de refeição já registados no diário de hoje.
final todayCompletedMealTypesProvider =
    StreamProvider.family<Set<String>, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref
      .read(diaryRepositoryProvider)
      .diaryEntryStream(userId, today)
      .map((diary) => diary?.refeicoes.map((r) => r.tipo).toSet() ?? {});
});

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

  /// Gramas consumidas por alimento (chave: "${diaSemana}_${tipoRefeicao}_${nomeAlimento}").
  final Map<String, double> _consumoPorAlimento = {};
  /// Contador para forçar recriação dos TextFormField apenas
  /// quando o valor muda programaticamente (ex: "Porção completa").
  int _formRebuildCounter = 0;

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
                return _buildPlanView(plan, diaSemana);
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

  Widget _buildPlanView(NutritionPlanModel plan, String diaSemana) {
    final consumedAsync = ref.watch(todayConsumedCaloriesProvider(plan.userId));
    final consumedCalories = consumedAsync.value ?? 0.0;
    final completedMealsAsync =
        ref.watch(todayCompletedMealTypesProvider(plan.userId));
    final completedMeals = completedMealsAsync.value ?? const {};
    final isToday =
        diaSemana == AppStrings.daysOfWeek[DateTime.now().weekday - 1];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nutritionPlanProvider(
            (plan.userId, AppStrings.daysOfWeek[_selectedDayIndex])));
        ref.invalidate(todayConsumedCaloriesProvider(plan.userId));
        ref.invalidate(todayCompletedMealTypesProvider(plan.userId));
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaloriesBar(plan, consumedCalories),
            const SizedBox(height: 16),
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
              ...plan.refeicoes.map((meal) => _buildMealCard(
                    plan,
                    meal,
                    diaSemana,
                    isCompleted: isToday && completedMeals.contains(meal.tipo),
                  )),
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
        color: AppColors.surfaceLow,
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

  Widget _buildMealCard(NutritionPlanModel plan, PlannedMeal meal,
      String diaSemana, {bool isCompleted = false}) {
    double totalProteinas = 0;
    double totalHidratos = 0;
    double totalGorduras = 0;
    double totalKcalConsumidas = 0;

    for (final alimento in meal.alimentos) {
      final key = '${diaSemana}_${meal.tipo}_${alimento.nome}';
      final gramas = _consumoPorAlimento[key] ?? 0.0;
      if (gramas > 0) {
        totalProteinas += alimento.proteinasParaGramas(gramas);
        totalHidratos += alimento.hidratosParaGramas(gramas);
        totalGorduras += alimento.gordurasParaGramas(gramas);
        totalKcalConsumidas += alimento.caloriasParaGramas(gramas);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.caloriesLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.restaurant,
                    color: isCompleted ? AppColors.success : AppColors.calories,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meal.tipo,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${meal.totalCalorias.toStringAsFixed(0)} kcal',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outline),

          // ── Instruções ─────────────────────────────────────
          if (meal.instrucoes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
              child: Text(
                meal.instrucoes!,
                style: GoogleFonts.inter(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),

          // ── Alimentos ──────────────────────────────────────
          ...meal.alimentos.map(
            (alimento) => _buildAlimentoRow(diaSemana, meal.tipo, alimento),
          ),

          const SizedBox(height: 4),
          // ── Botão Adicionar alimento ───────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Adicionar alimento'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(
                      color: AppColors.outline.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Botão Registar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _markMealDone(plan.userId, meal, diaSemana),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Registar Refeição'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ),
          ),

          // ── Totais de macros ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  // Labels
                  Row(
                    children: [
                      _macroColHeader('Calorias'),
                      _macroColHeader('Proteínas'),
                      _macroColHeader('H. Carbonos'),
                      _macroColHeader('Gorduras'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Valores
                  Row(
                    children: [
                      _macroColValue(
                          totalKcalConsumidas > 0
                              ? '${totalKcalConsumidas.toStringAsFixed(0)}kcal'
                              : '0',
                          AppColors.textSecondary),
                      _macroColValue(
                          '${totalProteinas.toStringAsFixed(0)}g',
                          AppColors.protein),
                      _macroColValue(
                          '${totalHidratos.toStringAsFixed(0)}g',
                          AppColors.carbs),
                      _macroColValue(
                          '${totalGorduras.toStringAsFixed(0)}g',
                          AppColors.fat),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }      /// Cabeçalho de coluna nos totais de macros.
  Widget _macroColHeader(String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Valor de coluna nos totais de macros.
  Widget _macroColValue(String text, Color color) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }


  /// Linha de input para um alimento individual (compacta).
  /// Layout: Nome + gramas → kcal / macronutrientes por extenso
  Widget _buildAlimentoRow(
      String diaSemana, String mealTipo, Alimento alimento) {
    final key = '${diaSemana}_${mealTipo}_${alimento.nome}';
    final gramas = _consumoPorAlimento[key] ?? 0.0;

    final caloriasConsumidas = alimento.caloriasParaGramas(gramas);
    final prots = alimento.proteinasParaGramas(gramas);
    final carbs = alimento.hidratosParaGramas(gramas);
    final gords = alimento.gordurasParaGramas(gramas);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Nome + gramas
          Row(
            children: [
              Expanded(
                child: Text(
                  alimento.nome,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 56,
                child: TextFormField(
                  key: ValueKey('gramas_${key}_$_formRebuildCounter'),
                  initialValue:
                      gramas > 0 ? gramas.toStringAsFixed(0) : '',
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.montserrat(
                    color: AppColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0 g',
                    hintStyle: GoogleFonts.montserrat(
                      color: AppColors.outlineVariant,
                      fontSize: 11,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceLow),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.surfaceLow),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    final parsed =
                        double.tryParse(value.replaceAll(',', '.'));
                    setState(() {
                      if (parsed != null && parsed > 0) {
                        _consumoPorAlimento[key] = parsed;
                      } else {
                        _consumoPorAlimento.remove(key);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 75),
            ],
          ),
          // Linha 2: kcal + macronutrientes com cores
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'C: ',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '${caloriasConsumidas.toStringAsFixed(0)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'kcal  ',
                  style: GoogleFonts.montserrat(
                    fontSize: 7,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'H: ${carbs.toStringAsFixed(0)}g',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.carbs,
                  ),
                ),
                TextSpan(
                  text: '  •  ',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'P: ${prots.toStringAsFixed(0)}g',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.protein,
                  ),
                ),
                TextSpan(
                  text: '  •  ',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'G: ${gords.toStringAsFixed(0)}g',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMealDone(String userId, PlannedMeal meal, String diaSemana) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    final now = DateFormat('HH:mm').format(DateTime.now());

    // Constrói o mapa de consumo e calcula calorias reais
    final consumoPorAlimento = <String, double>{};
    double totalCaloriasConsumidas = 0.0;
    final alimentosConsumidos = <String>[];

    for (final alimento in meal.alimentos) {
      final key = '${diaSemana}_${meal.tipo}_${alimento.nome}';
      final gramas = _consumoPorAlimento[key];
      if (gramas != null && gramas > 0) {
        consumoPorAlimento[alimento.nome] = gramas;
        alimentosConsumidos.add(alimento.nome);

        totalCaloriasConsumidas += alimento.caloriasParaGramas(gramas);
      }
    }

    if (alimentosConsumidos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.noConsumptionIndicated),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await ref.read(diaryRepositoryProvider).addMeal(userId, today, {
        'tipo': meal.tipo,
        'descricao': alimentosConsumidos.join(', '),
        'calorias': totalCaloriasConsumidas,
        'hora': now,
        'alimentos': alimentosConsumidos,
        if (consumoPorAlimento.isNotEmpty)
          'consumoPorAlimento': consumoPorAlimento,
      });

      // Limpa o estado de consumo para esta refeição
      setState(() {
        for (final alimento in meal.alimentos) {
          final key = '${diaSemana}_${meal.tipo}_${alimento.nome}';
          _consumoPorAlimento.remove(key);
        }
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
      backgroundColor: AppColors.surfaceLowest,
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
