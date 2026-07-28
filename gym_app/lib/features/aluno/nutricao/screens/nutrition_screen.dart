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
import '../../../../shared/widgets/app_notification.dart';

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
  DateTime _selectedDate = DateTime.now();
  late DateTime _weekStart;
  double _slideDirection = 1.0;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOfWeek(DateTime.now());
  }

  /// Segunda-feira da semana que contém [date].
  DateTime _mondayOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  /// Dia da semana correspondente à data selecionada.
  String get _diaSemana => AppStrings.daysOfWeek[_selectedDate.weekday - 1];

  /// Gramas consumidas por alimento (chave: "${diaSemana}_${tipoRefeicao}_${nomeAlimento}").
  final Map<String, double> _consumoPorAlimento = {};
  /// Modo de medição por alimento: 'g' (gramas) ou 'un' (unidades).
  final Map<String, String> _modoPorAlimento = {};

  /// Controllers dos inputs de gramas (chave: "${diaSemana}_${tipoRefeicao}_${nomeAlimento}").
  final Map<String, TextEditingController> _gramasControllers = {};

  /// Refeições colapsadas (chave: "${diaSemana}_${tipoRefeicao}").
  final Set<String> _collapsedMeals = {};

  @override
  void dispose() {
    for (final c in _gramasControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final diaSemana = _diaSemana;
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
    final today = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy', 'pt').format(_weekStart);
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final canGoBack = _weekStart.isAfter(_mondayOfWeek(today).subtract(const Duration(days: 60)));
    final canGoForward = _weekStart.isBefore(_mondayOfWeek(today).add(const Duration(days: 60)));

    Future<void> _openMonthPicker() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: _weekStart,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        initialDatePickerMode: DatePickerMode.day,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
              surface: AppColors.surfaceLowest,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        _slideDirection = 1.0;
        setState(() {
          _weekStart = _mondayOfWeek(picked);
          _selectedDate = _weekStart;
        });
      }
    }

    void _navigateWeek(int offset) {
      _slideDirection = offset.toDouble();
      setState(() {
        _weekStart = _weekStart.add(Duration(days: offset * 7));
        _selectedDate = _weekStart;
      });
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        final velocity = details.primaryVelocity!;
        if (velocity < -400 && canGoForward) {
          _navigateWeek(1);
        } else if (velocity > 400 && canGoBack) {
          _navigateWeek(-1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        color: AppColors.surfaceLow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Mês Ano (tocável) ────────────────────────
            GestureDetector(
              onTap: _openMonthPicker,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthYear,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── Setas + dias (com AnimatedSwitcher) ───────
            Row(
              children: [
                // Seta esquerda
                GestureDetector(
                  onTap: canGoBack ? () => _navigateWeek(-1) : null,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2, right: 1),
                    child: Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: canGoBack
                          ? AppColors.onSurfaceVariant
                          : AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                // 7 dias (animados)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(_slideDirection * 0.3, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      key: ValueKey(_weekStart),
                      children: days.map((date) {
                        final isSelected = date.day == _selectedDate.day &&
                            date.month == _selectedDate.month &&
                            date.year == _selectedDate.year;
                        final isToday = date.day == today.day &&
                            date.month == today.month &&
                            date.year == today.year;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedDate = date),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isToday && !isSelected
                                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                                    : null,
                              ),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 150),
                                tween: Tween<double>(
                                  begin: 1.0,
                                  end: isSelected ? 1.1 : 1.0,
                                ),
                                builder: (_, scale, child) => Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textOnPrimary
                                        : isToday
                                            ? AppColors.onSurface
                                            : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Seta direita
                GestureDetector(
                  onTap: canGoForward ? () => _navigateWeek(1) : null,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2, left: 1),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: canGoForward
                          ? AppColors.onSurfaceVariant
                          : AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            (plan.userId, _diaSemana)));
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
            _buildCaloriesBar(plan, consumedCalories, diaSemana: diaSemana),
            const SizedBox(height: 16),
            Text(
              'Refeições do dia',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w400,
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

  /// Calcula os totais diários de macronutrientes a partir dos inputs.
  (double proteinas, double hidratos, double gorduras) _dailyMacroTotals(
      NutritionPlanModel plan, String diaSemana) {
    double prots = 0, carbs = 0, gords = 0;
    for (final meal in plan.refeicoes) {
      for (final alimento in meal.alimentos) {
        final key = '${diaSemana}_${meal.tipo}_${alimento.nome}';
        final gramas = _consumoPorAlimento[key] ?? 0.0;
        if (gramas > 0) {
          prots += alimento.proteinasParaGramas(gramas);
          carbs += alimento.hidratosParaGramas(gramas);
          gords += alimento.gordurasParaGramas(gramas);
        }
      }
    }
    return (prots, carbs, gords);
  }

  /// Barra de progresso individual para um macronutriente.
  Widget _macroProgressBar(
      String label, double consumed, double goal, Color color) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.outline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${consumed.toStringAsFixed(0)}g/${goal.toStringAsFixed(0)}g',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesBar(NutritionPlanModel plan, double consumed,
      {required String diaSemana}) {
    final progress =
        plan.metaCalorias > 0 ? consumed / plan.metaCalorias : 0.0;
    final restante = (plan.metaCalorias - consumed).clamp(0.0, plan.metaCalorias);
    final (dailyProts, dailyCarbs, dailyGords) =
        _dailyMacroTotals(plan, diaSemana);

    // Metas de macronutrientes calculadas a partir das calorias
    final metaProteina = (plan.metaCalorias * 0.30) / 4;
    final metaHidratos = (plan.metaCalorias * 0.40) / 4;
    final metaGorduras = (plan.metaCalorias * 0.30) / 9;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ── Linha superior: Calorias | Restante ──────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calorias (esquerda)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calorias',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${consumed.toStringAsFixed(0)}',
                          style: GoogleFonts.montserrat(
                            color: AppColors.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' / ${plan.metaCalorias.toStringAsFixed(0)} kcal',
                          style: GoogleFonts.montserrat(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Restante (direita)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Restante',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${restante.toStringAsFixed(0)} kcal',
                    style: GoogleFonts.montserrat(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Barra de progresso (8px) ──────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.outline,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          // ── Totais diários de macronutrientes ───────────────
          const SizedBox(height: 14),
          const Divider(color: AppColors.outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _macroProgressBar(
                    'Proteína', dailyProts, metaProteina, AppColors.protein),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _macroProgressBar('Gordura', dailyGords, metaGorduras,
                    AppColors.fat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _macroProgressBar('H. Carbonos', dailyCarbs,
                    metaHidratos, AppColors.carbs),
              ),
            ],
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

    final collapseKey = '${diaSemana}_${meal.tipo}';
    final isCollapsed = _collapsedMeals.contains(collapseKey);

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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                if (isCollapsed) {
                  _collapsedMeals.remove(collapseKey);
                } else {
                  _collapsedMeals.add(collapseKey);
                }
              }),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
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
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: isCollapsed ? 0.0 : 0.5,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),

          // ── Conteúdo colapsável ───────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: child,
            ),
            child: isCollapsed
                ? const SizedBox.shrink(key: ValueKey('collapsed'))
                : Column(
                    key: const ValueKey('expanded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, color: AppColors.outline),
                      // ── Instruções ─────────────────────────
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
                      // ── Alimentos ──────────────────────────
                      ...meal.alimentos.map(
                        (alimento) => _buildAlimentoRow(diaSemana, meal.tipo, alimento),
                      ),
                      const SizedBox(height: 4),
                      // ── Botão Adicionar alimento ───────────
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
                      // ── Botão Registar ─────────────────────
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
                      // ── Totais de macros ───────────────────
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
                              Row(
                                children: [
                                  _macroColHeader('Calorias'),
                                  _macroColHeader('Proteínas'),
                                  _macroColHeader('H. Carbonos'),
                                  _macroColHeader('Gorduras'),
                                ],
                              ),
                              const SizedBox(height: 4),
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

    // Obtém ou cria o controller para este alimento
    final controller = _gramasControllers.putIfAbsent(key, () {
      return TextEditingController(
        text: gramas > 0 ? gramas.toStringAsFixed(0) : '',
      );
    });

    final caloriasConsumidas = alimento.caloriasParaGramas(gramas);
    final prots = alimento.proteinasParaGramas(gramas);
    final carbs = alimento.hidratosParaGramas(gramas);
    final gords = alimento.gordurasParaGramas(gramas);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
            // Nome + macronutrientes à esquerda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alimento.nome,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'C: ',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: '${caloriasConsumidas.toStringAsFixed(0)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: 'kcal  ',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: 'H: ${carbs.toStringAsFixed(0)}g',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.carbs,
                          ),
                        ),
                        TextSpan(
                          text: '  •  ',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: 'P: ${prots.toStringAsFixed(0)}g',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.protein,
                          ),
                        ),
                        TextSpan(
                          text: '  •  ',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: 'G: ${gords.toStringAsFixed(0)}g',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.fat,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Input de gramas / unidades
            SizedBox(
              width: 62,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: GoogleFonts.montserrat(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.montserrat(
                    color: AppColors.outlineVariant,
                    fontSize: 11,
                  ),
                  suffix: GestureDetector(
                    onTap: () {
                      final current = _modoPorAlimento[key] ?? 'g';
                      setState(() {
                        _modoPorAlimento[key] =
                            current == 'g' ? 'un' : 'g';
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _modoPorAlimento[key] ?? 'g',
                        style: GoogleFonts.montserrat(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  contentPadding: const EdgeInsets.only(
                      left: 4, right: 2, top: 7, bottom: 7),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
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
            const SizedBox(width: 6),
            // Botão de substituir alimento
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: Icon(Icons.swap_horiz,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                onPressed: () => _showFoodSearch(
                  diaSemana: diaSemana,
                  mealTipo: mealTipo,
                  alimentoToReplace: alimento,
                ),
              ),
            ),
            const SizedBox(width: 35),
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
        showAppNotification(context, AppStrings.noConsumptionIndicated, type: NotificationType.error);
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

      // Limpa o estado de consumo e os inputs para esta refeição
      setState(() {
        for (final alimento in meal.alimentos) {
          final key = '${diaSemana}_${meal.tipo}_${alimento.nome}';
          _consumoPorAlimento.remove(key);
          _gramasControllers[key]?.clear();
        }
      });

      if (mounted) {
        showAppNotification(context, AppStrings.mealCompleted, type: NotificationType.success);
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(context, AppStrings.networkError, type: NotificationType.error);
      }
    }
  }

  void _showFoodSearch({
    String? diaSemana,
    String? mealTipo,
    Alimento? alimentoToReplace,
  }) {
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
            if (alimentoToReplace != null &&
                diaSemana != null &&
                mealTipo != null) {
              final oldKey =
                  '${diaSemana}_${mealTipo}_${alimentoToReplace.nome}';
              final gramas = _consumoPorAlimento[oldKey] ?? 0.0;
              setState(() {
                _consumoPorAlimento.remove(oldKey);
                final newKey = '${diaSemana}_${mealTipo}_${food.nome}';
                if (gramas > 0) {
                  _consumoPorAlimento[newKey] = gramas;
                }
              });
            }
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
