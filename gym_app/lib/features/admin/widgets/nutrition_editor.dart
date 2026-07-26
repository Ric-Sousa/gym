import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../data/models/food_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

/// Editor do plano nutricional (admin) — GYMBT Lime+Dark.
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
    final planAsync = ref.watch(adminNutritionPlanProvider((widget.aluno.uid, diaSemana)));

    return Column(
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.adminSurface,
            boxShadow: [
              BoxShadow(
                color: AppColors.adminShadow,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: 7,
            itemBuilder: (context, index) {
              final selected = index == _selectedDayIndex;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(AppStrings.daysOfWeekShort[index],
                        style: GoogleFonts.dmSans(fontSize: 12, color: selected ? AppColors.adminBg : AppColors.adminMuted)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedDayIndex = index),
                    selectedColor: AppColors.adminLime,
                    backgroundColor: AppColors.adminSurface2,
                    side: BorderSide(color: selected ? AppColors.adminLime : AppColors.adminBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.adminBorder),
        Expanded(
          child: planAsync.when(
            data: (plan) => _buildEditor(plan),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.adminLime)),
            error: (_, __) => const EmptyState(icon: Icons.error, title: 'Erro'),
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
            const EmptyState(icon: Icons.restaurant_menu, title: AppStrings.noPlanAssigned),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createEmptyPlan,
              icon: const Icon(Icons.add, size: 16),
              label: Text('Criar plano', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminLime,
                foregroundColor: AppColors.adminBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Meta calórica:', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.adminText)),
              const SizedBox(width: 8),
              Text('${plan.metaCalorias} kcal', style: GoogleFonts.dmMono(fontSize: 14, color: AppColors.adminOrange)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editMetaCalorias(plan),
                icon: const Icon(Icons.edit, size: 14, color: AppColors.adminLime),
                label: Text('Editar meta', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminLime)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...plan.refeicoes.map((meal) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.adminSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.adminBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.adminShadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.adminLimeDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant, color: AppColors.adminLime, size: 16),
                  ),
                  title: Text(meal.tipo, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.adminText)),
                  subtitle: Text('${meal.totalCalorias.toStringAsFixed(0)} kcal',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                  children: [
                    ...meal.alimentos.map((a) => ListTile(
                          dense: true,
                          title: Text(a.nome, style: GoogleFonts.dmSans(color: AppColors.adminText, fontSize: 14)),
                          subtitle: Text(a.quantidade, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                          trailing: Text('${a.calorias.toStringAsFixed(0)} kcal',
                              style: GoogleFonts.dmMono(fontSize: 13, color: AppColors.adminMuted)),
                        )),
                    const Divider(color: AppColors.adminBorder, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextButton.icon(
                        onPressed: () => _addAlimentoToMeal(plan, meal.tipo),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.adminLime),
                        label: Text('Adicionar alimento', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminLime)),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addMeal(plan),
              icon: const Icon(Icons.add, size: 14),
              label: Text('Adicionar refeição', style: GoogleFonts.dmSans(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.adminLime,
                side: const BorderSide(color: AppColors.adminLime),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createEmptyPlan() async {
    final diaSemana = AppStrings.daysOfWeek[_selectedDayIndex];
    await ref.read(nutritionRepositoryProvider).savePlan(widget.aluno.uid, diaSemana, {'metaCalorias': 2000, 'refeicoes': []});
    ref.invalidate(adminNutritionPlanProvider((widget.aluno.uid, diaSemana)));
  }

  Future<void> _editMetaCalorias(NutritionPlanModel plan) async {
    final controller = TextEditingController(text: plan.metaCalorias.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adminSurface,
        title: Text('Meta calórica', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.adminText)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.dmSans(color: AppColors.adminText),
          decoration: const InputDecoration(labelText: 'Calorias', suffixText: 'kcal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel, style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.'))),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminLime, foregroundColor: AppColors.adminBg),
            child: Text(AppStrings.save, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await ref.read(nutritionRepositoryProvider).savePlan(widget.aluno.uid, plan.dia, {'metaCalorias': result});
      ref.invalidate(adminNutritionPlanProvider((widget.aluno.uid, plan.dia)));
    }
  }

  Future<void> _addAlimentoToMeal(NutritionPlanModel plan, String mealTipo) async {
    final nome = TextEditingController();
    final qtd = TextEditingController();
    final kcal = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adminSurface,
        title: Text('Adicionar alimento', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.adminText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nome, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Nome do alimento')),
            TextField(controller: qtd, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Quantidade')),
            TextField(controller: kcal, keyboardType: TextInputType.number, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Calorias')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel, style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {'nome': nome.text.trim(), 'quantidade': qtd.text.trim(), 'calorias': kcal.text.replaceAll(',', '.')}),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminLime, foregroundColor: AppColors.adminBg),
            child: Text(AppStrings.save, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result['nome']!.isNotEmpty) {
      final alimento = Alimento(nome: result['nome']!, quantidade: result['quantidade']!, calorias: double.tryParse(result['calorias']!) ?? 0.0);
      final updated = plan.refeicoes.map((m) => m.tipo == mealTipo ? PlannedMeal(tipo: m.tipo, alimentos: [...m.alimentos, alimento], instrucoes: m.instrucoes) : m).toList();
      await ref.read(nutritionRepositoryProvider).savePlan(widget.aluno.uid, plan.dia, {'refeicoes': updated.map((m) => m.toMap()).toList()});
      ref.invalidate(adminNutritionPlanProvider((widget.aluno.uid, plan.dia)));
    }
  }

  Future<void> _addMeal(NutritionPlanModel plan) async {
    final tipo = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adminSurface,
        title: Text('Nova refeição', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.adminText)),
        content: TextField(controller: tipo, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Tipo', hintText: 'Almoço')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel, style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, tipo.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminLime, foregroundColor: AppColors.adminBg),
            child: Text(AppStrings.save, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final updated = [...plan.refeicoes.map((m) => m.toMap()), PlannedMeal(tipo: result).toMap()];
      await ref.read(nutritionRepositoryProvider).savePlan(widget.aluno.uid, plan.dia, {'refeicoes': updated});
      ref.invalidate(adminNutritionPlanProvider((widget.aluno.uid, plan.dia)));
    }
  }
}
