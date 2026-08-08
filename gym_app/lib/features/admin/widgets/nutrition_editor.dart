import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/admin_theme.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/nutrition_plan_model.dart';
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
  static const _readDay = 'Segunda-feira';

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(
      adminNutritionPlanProvider((widget.aluno.uid, _readDay)),
    );

    return Column(
      children: [
        Expanded(
          child: planAsync.when(
            data: (plan) => _buildEditor(plan),
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
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
              onPressed: _createEmptyPlan,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Criar plano',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
              Text(
                'Meta calórica:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${plan.metaCalorias} kcal',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: AdminThemeColors.of(context).orange,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editMetaCalorias(plan),
                icon: Icon(
                  Icons.edit,
                  size: 14,
                  color: AdminThemeColors.of(context).lime,
                ),
                label: Text(
                  'Editar meta',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminThemeColors.of(context).lime,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Suplementos ───────────────────────────────
          _buildSuplementosEditor(plan),
          const SizedBox(height: 16),
          ...plan.refeicoes.map(
            (meal) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AdminThemeColors.of(context).surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminThemeColors.of(context).border),
                boxShadow: [
                  BoxShadow(
                    color: AdminThemeColors.of(context).shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminThemeColors.of(context).limeDim,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: AdminThemeColors.of(context).lime,
                    size: 16,
                  ),
                ),
                title: Text(
                  meal.tipo,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
                subtitle: Text(
                  '${meal.totalCalorias.toStringAsFixed(0)} kcal',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
                children: [
                  ...meal.alimentos.map(
                    (a) => ListTile(
                      dense: true,
                      title: Text(
                        a.nome,
                        style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).text,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        a.quantidade,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                      trailing: Text(
                        '${a.calorias.toStringAsFixed(0)} kcal',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    color: AdminThemeColors.of(context).border,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton.icon(
                      onPressed: () => _addAlimentoToMeal(plan, meal.tipo),
                      icon: Icon(
                        Icons.add,
                        size: 14,
                        color: AdminThemeColors.of(context).lime,
                      ),
                      label: Text(
                        'Adicionar alimento',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).lime,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addMeal(plan),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                'Adicionar refeição',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminThemeColors.of(context).lime,
                side: BorderSide(color: AdminThemeColors.of(context).lime),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuplementosEditor(NutritionPlanModel plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).limeDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medication,
                  color: AdminThemeColors.of(context).purple,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SUPLEMENTOS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addSuplemento(plan),
                icon: Icon(
                  Icons.add,
                  size: 14,
                  color: AdminThemeColors.of(context).lime,
                ),
                label: Text(
                  'Adicionar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminThemeColors.of(context).lime,
                  ),
                ),
              ),
            ],
          ),
          if (plan.suplementos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum suplemento adicionado.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            )
          else
            ...plan.suplementos.asMap().entries.map((entry) {
              final s = entry.value;
              final idx = entry.key;
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nome,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AdminThemeColors.of(context).text,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${s.dosagem} • ${s.horario}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminThemeColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AdminThemeColors.of(context).muted,
                      ),
                      onPressed: () => _removeSuplemento(plan, idx),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Guarda os mesmos dados em todos os 7 dias da semana.
  Future<void> _saveToAllDays(Map<String, dynamic> data) async {
    for (final dia in AppStrings.daysOfWeek) {
      await ref
          .read(nutritionRepositoryProvider)
          .savePlan(widget.aluno.uid, dia, data);
      ref.invalidate(adminNutritionPlanProvider((widget.aluno.uid, dia)));
    }
  }

  Future<void> _createEmptyPlan() async {
    await _saveToAllDays({
      'metaCalorias': 2000,
      'refeicoes': [],
      'suplementos': [],
    });
  }

  Future<void> _addSuplemento(NutritionPlanModel plan) async {
    final nome = TextEditingController();
    final dosagem = TextEditingController();
    String horario = 'qualquer';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          title: Text(
            'Adicionar suplemento',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).text,
                ),
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dosagem,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).text,
                ),
                decoration: const InputDecoration(
                  labelText: 'Dosagem',
                  hintText: '1 scoop (30g)',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: horario,
                decoration: const InputDecoration(labelText: 'Horário'),
                items:
                    ['pré-treino', 'pós-treino', 'manhã', 'noite', 'qualquer']
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                onChanged: (v) => setDialogState(() => horario = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppStrings.cancel,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'nome': nome.text.trim(),
                'dosagem': dosagem.text.trim(),
                'horario': horario,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
              ),
              child: Text(
                AppStrings.save,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && result['nome']!.isNotEmpty) {
      final suplementos = plan.suplementos.map((s) => s.toMap()).toList();
      suplementos.add({
        'nome': result['nome'],
        'dosagem': result['dosagem'],
        'horario': result['horario'],
      });
      await _saveToAllDays({'suplementos': suplementos});
    }
  }

  Future<void> _removeSuplemento(NutritionPlanModel plan, int index) async {
    final suplementos = plan.suplementos.map((s) => s.toMap()).toList();
    suplementos.removeAt(index);
    await _saveToAllDays({'suplementos': suplementos});
  }

  Future<void> _editMetaCalorias(NutritionPlanModel plan) async {
    final controller = TextEditingController(
      text: plan.metaCalorias.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        title: Text(
          'Meta calórica',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
          decoration: const InputDecoration(
            labelText: 'Calorias',
            suffixText: 'kcal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.cancel,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: AdminThemeColors.of(context).bg,
            ),
            child: Text(
              AppStrings.save,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _saveToAllDays({'metaCalorias': result});
    }
  }

  Future<void> _addAlimentoToMeal(
    NutritionPlanModel plan,
    String mealTipo,
  ) async {
    final nome = TextEditingController();
    final qtd = TextEditingController();
    final kcal = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        title: Text(
          'Adicionar alimento',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).text,
              ),
              decoration: const InputDecoration(labelText: 'Nome do alimento'),
            ),
            TextField(
              controller: qtd,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).text,
              ),
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            TextField(
              controller: kcal,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).text,
              ),
              decoration: const InputDecoration(labelText: 'Calorias'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.cancel,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'nome': nome.text.trim(),
              'quantidade': qtd.text.trim(),
              'calorias': kcal.text.replaceAll(',', '.'),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: AdminThemeColors.of(context).bg,
            ),
            child: Text(
              AppStrings.save,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
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
      final updated = plan.refeicoes
          .map(
            (m) => m.tipo == mealTipo
                ? PlannedMeal(
                    tipo: m.tipo,
                    alimentos: [...m.alimentos, alimento],
                    instrucoes: m.instrucoes,
                  )
                : m,
          )
          .toList();
      await _saveToAllDays({
        'refeicoes': updated.map((m) => m.toMap()).toList(),
      });
    }
  }

  Future<void> _addMeal(NutritionPlanModel plan) async {
    final tipo = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        title: Text(
          'Nova refeição',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: TextField(
          controller: tipo,
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
          decoration: const InputDecoration(
            labelText: 'Tipo',
            hintText: 'Almoço',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.cancel,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, tipo.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: AdminThemeColors.of(context).bg,
            ),
            child: Text(
              AppStrings.save,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final updated = [
        ...plan.refeicoes.map((m) => m.toMap()),
        PlannedMeal(tipo: result).toMap(),
      ];
      await _saveToAllDays({'refeicoes': updated});
    }
  }
}
