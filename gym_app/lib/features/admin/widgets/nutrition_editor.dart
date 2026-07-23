import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../data/models/food_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

/// Ecrã de edição do plano nutricional (admin).
class NutritionEditor extends ConsumerStatefulWidget {
  final UserModel aluno;
  const NutritionEditor({super.key, required this.aluno});

  @override
  ConsumerState<NutritionEditor> createState() => _NutritionEditorState();
}

class _NutritionEditorState extends ConsumerState<NutritionEditor> {
  int _selectedDayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final diaSemana = AppStrings.daysOfWeek[_selectedDayIndex];
    final planAsync = ref.watch(
        adminNutritionPlanProvider((widget.aluno.uid, diaSemana)));

    return Column(
      children: [
        // Seletor de dia
        Container(
          height: 44,
          color: AppColors.primary.withValues(alpha: 0.05),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: 7,
            itemBuilder: (context, index) {
              final selected = index == _selectedDayIndex;
              return Center(
                child: ChoiceChip(
                  label: Text(AppStrings.daysOfWeekShort[index]),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDayIndex = index),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: planAsync.when(
            data: (plan) => _buildEditor(plan),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const EmptyState(icon: Icons.error, title: 'Erro'),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(NutritionPlanModel? plan) {
    if (plan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: Icons.restaurant_menu,
              title: AppStrings.noPlanAssigned,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _createEmptyPlan(),
              icon: const Icon(Icons.add),
              label: const Text('Criar plano'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(
        adminNutritionPlanProvider(
            (widget.aluno.uid, AppStrings.daysOfWeek[_selectedDayIndex])),
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Meta calórica:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  '${plan.metaCalorias} kcal',
                  style: const TextStyle(color: AppColors.calories),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editMetaCalorias(plan),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar meta'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...plan.refeicoes.map((meal) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(meal.tipo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${meal.totalCalorias.toStringAsFixed(0)} kcal'),
                    children: [
                      ...meal.alimentos.map((a) => ListTile(
                            dense: true,
                            title: Text(a.nome),
                            subtitle: Text(a.quantidade),
                            trailing: Text(
                                '${a.calorias.toStringAsFixed(0)} kcal'),
                          )),
                      TextButton.icon(
                        onPressed: () => _addAlimentoToMeal(plan, meal.tipo),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar alimento'),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addMeal(plan),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar refeição'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createEmptyPlan() async {
    final diaSemana = AppStrings.daysOfWeek[_selectedDayIndex];
    await ref.read(nutritionRepositoryProvider).savePlan(
          widget.aluno.uid,
          diaSemana,
          {'metaCalorias': 2000, 'refeicoes': []},
        );
    ref.invalidate(
      adminNutritionPlanProvider((widget.aluno.uid, diaSemana)),
    );
  }

  Future<void> _editMetaCalorias(NutritionPlanModel plan) async {
    final controller =
        TextEditingController(text: plan.metaCalorias.toString());

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meta calórica'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Calorias', suffixText: 'kcal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await ref.read(nutritionRepositoryProvider).savePlan(
            widget.aluno.uid,
            plan.dia,
            {'metaCalorias': result},
          );
      ref.invalidate(
        adminNutritionPlanProvider((widget.aluno.uid, plan.dia)),
      );
    }
  }

  Future<void> _addAlimentoToMeal(
      NutritionPlanModel plan, String mealTipo) async {
    final nomeController = TextEditingController();
    final qtdController = TextEditingController();
    final kcalController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar alimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration:
                  const InputDecoration(labelText: 'Nome do alimento'),
            ),
            TextField(
              controller: qtdController,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            TextField(
              controller: kcalController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Calorias'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'nome': nomeController.text.trim(),
              'quantidade': qtdController.text.trim(),
              'calorias': kcalController.text.replaceAll(',', '.'),
            }),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null && result['nome']!.isNotEmpty) {
      final alimento = Alimento(
        nome: result['nome']!,
        quantidade: result['quantidade']!,
        calorias: double.tryParse(result['calorias']!) ?? 0.0,
      );

      final updatedMeals = plan.refeicoes.map((m) {
        if (m.tipo == mealTipo) {
          return PlannedMeal(
            tipo: m.tipo,
            alimentos: [...m.alimentos, alimento],
            instrucoes: m.instrucoes,
          );
        }
        return m;
      }).toList();

      await ref.read(nutritionRepositoryProvider).savePlan(
            widget.aluno.uid,
            plan.dia,
            {'refeicoes': updatedMeals.map((m) => m.toMap()).toList()},
          );
      ref.invalidate(
        adminNutritionPlanProvider((widget.aluno.uid, plan.dia)),
      );
    }
  }

  Future<void> _addMeal(NutritionPlanModel plan) async {
    final tipoController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova refeição'),
        content: TextField(
          controller: tipoController,
          decoration:
              const InputDecoration(labelText: 'Tipo', hintText: 'Almoço'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, tipoController.text.trim()),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newMeal = PlannedMeal(tipo: result);
      final updatedMeals = [
        ...plan.refeicoes.map((m) => m.toMap()),
        newMeal.toMap(),
      ];

      await ref.read(nutritionRepositoryProvider).savePlan(
            widget.aluno.uid,
            plan.dia,
            {'refeicoes': updatedMeals},
          );
      ref.invalidate(
        adminNutritionPlanProvider((widget.aluno.uid, plan.dia)),
      );
    }
  }
}
