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
import '../../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../../shared/widgets/admin_design_system.dart';

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
    final colors = AdminThemeColors.of(context);

    if (plan == null) {
      return Center(
        child: AdminSurface(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 30,
                color: colors.lime,
              ),
              const SizedBox(height: 12),
              Text(
                'Ainda não existe um plano',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Cria um plano base para começar a configurar a rotina.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _createEmptyPlan,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Criar plano'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final metricWidth = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.limeDim,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_outlined,
                      color: colors.lime,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plano nutricional',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Configuração base aplicada a todos os dias da semana.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _dayBadge(colors),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: _buildGoalCard(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Meta calórica',
                      value: '${plan.metaCalorias.toStringAsFixed(0)} kcal',
                      accent: colors.orange,
                      onEdit: () => _editMetaCalorias(plan),
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _buildGoalCard(
                      icon: Icons.water_drop_outlined,
                      label: 'Meta de água',
                      value: '${(plan.metaAgua / 1000).toStringAsFixed(1)} L',
                      accent: colors.blue,
                      onEdit: () => _editMetaAgua(plan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              AdminSectionHeading(
                title: 'Refeições',
                subtitle: plan.refeicoes.isEmpty
                    ? 'Adiciona as refeições do dia.'
                    : '${plan.refeicoes.length} ${plan.refeicoes.length == 1 ? 'refeição planeada' : 'refeições planeadas'}',
                action: _sectionAction(
                  label: 'Adicionar',
                  icon: Icons.add,
                  onPressed: () => _addMeal(plan),
                ),
              ),
              const SizedBox(height: 10),
              if (plan.refeicoes.isEmpty)
                _buildInlineEmpty(
                  icon: Icons.restaurant_outlined,
                  text: 'Nenhuma refeição adicionada.',
                )
              else
                ...plan.refeicoes.map((meal) => _buildMealEditor(plan, meal)),
              const SizedBox(height: 22),
              _buildSuplementosEditor(plan),
            ],
          );
        },
      ),
    );
  }

  Widget _dayBadge(AdminThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Text(
        'BASE',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: colors.muted,
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    required VoidCallback onEdit,
  }) {
    final colors = AdminThemeColors.of(context);
    return AdminSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Editar $label',
            icon: Icon(Icons.edit_outlined, size: 17, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _sectionAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final colors = AdminThemeColors.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: colors.lime),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.lime,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: colors.limeDim,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _buildInlineEmpty({required IconData icon, required String text}) {
    final colors = AdminThemeColors.of(context);
    return AdminSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colors.muted),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMealEditor(NutritionPlanModel plan, PlannedMeal meal) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdminSurface(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(13),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            leading: Icon(
              Icons.restaurant_outlined,
              color: colors.lime,
              size: 20,
            ),
            title: Text(
              meal.tipo,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            subtitle: Text(
              '${meal.alimentos.length} ${meal.alimentos.length == 1 ? 'alimento' : 'alimentos'} • ${meal.totalCalorias.toStringAsFixed(0)} kcal',
              style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
            ),
            children: [
              if (meal.alimentos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sem alimentos adicionados.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ),
                )
              else
                ...meal.alimentos.map(
                  (food) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            food.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 78,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                food.quantidade,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: colors.muted,
                                ),
                              ),
                              Text(
                                '${food.calorias.toStringAsFixed(0)} kcal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addAlimentoToMeal(plan, meal.tipo),
                  icon: Icon(Icons.add, size: 14, color: colors.lime),
                  label: Text(
                    'Adicionar alimento',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.lime,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuplementosEditor(NutritionPlanModel plan) {
    final colors = AdminThemeColors.of(context);
    return AdminSurface(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      borderRadius: BorderRadius.circular(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeading(
            title: 'Suplementos',
            subtitle: plan.suplementos.isEmpty
                ? 'Opcional'
                : '${plan.suplementos.length} ${plan.suplementos.length == 1 ? 'item' : 'itens'}',
            action: _sectionAction(
              label: 'Adicionar',
              icon: Icons.add,
              onPressed: () => _addSuplemento(plan),
            ),
          ),
          if (plan.suplementos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14, left: 2),
              child: Text(
                'Nenhum suplemento adicionado.',
                style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
              ),
            )
          else
            ...plan.suplementos.asMap().entries.map((entry) {
              final supplement = entry.value;
              final index = entry.key;
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 17,
                      color: colors.purple,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplement.nome,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${supplement.dosagem} • ${supplement.horario}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeSuplemento(plan, index),
                      tooltip: 'Remover suplemento',
                      icon: Icon(Icons.close, size: 16, color: colors.muted),
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
      'metaAgua': 2500,
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
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
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
                foregroundColor: Colors.white,
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
      builder: (ctx) => AdminResponsiveAlertDialog(
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
              foregroundColor: Colors.white,
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

  Future<void> _editMetaAgua(NutritionPlanModel plan) async {
    final controller = TextEditingController(
      text: plan.metaAgua.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        title: Text(
          'Meta diária de água',
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
            labelText: 'Quantidade de água',
            suffixText: 'ml',
            hintText: 'Ex.: 2500',
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
              foregroundColor: Colors.white,
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
      await _saveToAllDays({'metaAgua': result});
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
      builder: (ctx) => AdminResponsiveAlertDialog(
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
              foregroundColor: Colors.white,
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
      builder: (ctx) => AdminResponsiveAlertDialog(
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
              foregroundColor: Colors.white,
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
