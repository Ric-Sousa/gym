import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/admin_theme.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../data/models/food_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../../shared/widgets/admin_design_system.dart';
import '../../../../shared/widgets/app_design_system.dart';
import '../../../../shared/widgets/app_notification.dart';

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
          padding: const EdgeInsets.all(32),
          color: colors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.limeDim,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.spa_outlined, size: 30, color: colors.lime),
              ),
              const SizedBox(height: 18),
              Text(
                'Começa o plano nutricional',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Define as metas e cria uma rotina simples para este aluno.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _createEmptyPlan,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Criar plano'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.lime,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final plannedCalories = plan.totalCaloriasPlaneadas;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 20 : 26),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.limeDim,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.spa_outlined, color: colors.lime),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plano nutricional',
                                style: GoogleFonts.montserrat(
                                  fontSize: compact ? 19 : 23,
                                  fontWeight: FontWeight.w800,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rotina base · Segunda-feira',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!compact)
                          Icon(
                            Icons.auto_awesome_outlined,
                            color: colors.lime.withValues(alpha: 0.65),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _minimalMetric(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Meta diária',
                          value: '${plan.metaCalorias.toStringAsFixed(0)} kcal',
                          accent: colors.orange,
                          onTap: () => _editMetaCalorias(plan),
                        ),
                        _minimalMetric(
                          icon: Icons.water_drop_outlined,
                          label: 'Hidratação',
                          value:
                              '${(plan.metaAgua / 1000).toStringAsFixed(1)} L',
                          accent: colors.blue,
                          onTap: () => _editMetaAgua(plan),
                        ),
                        _minimalMetric(
                          icon: Icons.restaurant_outlined,
                          label: 'Planeado',
                          value: '${plannedCalories.toStringAsFixed(0)} kcal',
                          accent: colors.lime,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _minimalSectionHeader(
                title: 'Refeições',
                subtitle: plan.refeicoes.isEmpty
                    ? 'Adiciona os momentos principais do dia.'
                    : '${plan.refeicoes.length} ${plan.refeicoes.length == 1 ? 'refeição planeada' : 'refeições planeadas'}',
                action: _minimalAction(
                  label: 'Adicionar refeição',
                  icon: Icons.add_rounded,
                  onPressed: () => _addMeal(plan),
                ),
              ),
              const SizedBox(height: 12),
              if (plan.refeicoes.isEmpty)
                _minimalEmpty(
                  icon: Icons.restaurant_outlined,
                  text: 'Ainda não existem refeições neste plano.',
                )
              else
                ...plan.refeicoes.map((meal) => _minimalMeal(plan, meal)),
              const SizedBox(height: 24),
              _minimalSectionHeader(
                title: 'Suplementos',
                subtitle: plan.suplementos.isEmpty
                    ? 'Opcional'
                    : '${plan.suplementos.length} ${plan.suplementos.length == 1 ? 'item' : 'itens'}',
                action: _minimalAction(
                  label: 'Adicionar suplemento',
                  icon: Icons.add_rounded,
                  onPressed: () => _addSuplemento(plan),
                ),
              ),
              const SizedBox(height: 12),
              _minimalSupplements(plan),
            ],
          );
        },
      ),
    );
  }

  Widget _minimalMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final colors = AdminThemeColors.of(context);
    final content = Container(
      width: 178,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: accent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: colors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.edit_outlined, size: 14, color: colors.muted),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }

  Widget _minimalSectionHeader({
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    final colors = AdminThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
            ),
          ],
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 12), action],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            action,
          ],
        );
      },
    );
  }

  Widget _minimalAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final colors = AdminThemeColors.of(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: colors.limeDim,
        foregroundColor: colors.lime,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _minimalEmpty({required IconData icon, required String text}) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: colors.muted),
          const SizedBox(height: 9),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _minimalMeal(NutritionPlanModel plan, PlannedMeal meal) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.limeDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_outlined,
                size: 19,
                color: colors.lime,
              ),
            ),
            title: Text(
              meal.tipo,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            subtitle: Text(
              '${meal.alimentos.length} ${meal.alimentos.length == 1 ? 'alimento' : 'alimentos'} · ${meal.totalCalorias.toStringAsFixed(0)} kcal',
              style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                decoration: BoxDecoration(
                  color: colors.bg.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (meal.alimentos.isEmpty)
                      _minimalEmpty(
                        icon: Icons.inventory_2_outlined,
                        text: 'Adiciona o primeiro alimento.',
                      )
                    else
                      ...meal.alimentos.map(
                        (food) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: colors.lime,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      food.nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    food.quantidade,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: colors.lime,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    _macroBadge(
                                      'Proteína',
                                      food.proteinas,
                                      colors.blue,
                                    ),
                                    _macroBadge(
                                      'Carboidratos',
                                      food.hidratos,
                                      colors.orange,
                                    ),
                                    _macroBadge(
                                      'Gordura',
                                      food.gorduras,
                                      colors.purple,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addAlimentoToMeal(plan, meal.tipo),
                        icon: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: colors.lime,
                        ),
                        label: Text(
                          'Adicionar alimento da base de dados',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.lime,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroBadge(String label, double? value, Color color) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label ${value == null ? '—' : '${value.toStringAsFixed(1)}g'}',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: value == null ? colors.muted : color,
        ),
      ),
    );
  }

  Widget _minimalSupplements(NutritionPlanModel plan) {
    final colors = AdminThemeColors.of(context);
    if (plan.suplementos.isEmpty) {
      return _minimalEmpty(
        icon: Icons.medication_outlined,
        text: 'Nenhum suplemento adicionado.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: plan.suplementos.asMap().entries.map((entry) {
          final supplement = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Icon(Icons.medication_outlined, size: 19, color: colors.purple),
                const SizedBox(width: 11),
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
                        '${supplement.dosagem} · ${supplement.horario}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeSuplemento(plan, entry.key),
                  tooltip: 'Remover suplemento',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegacyEditor(NutritionPlanModel? plan) {
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
              AppMenuDropdown<String>(
                value: horario,
                options: const [
                  'pré-treino',
                  'pós-treino',
                  'manhã',
                  'noite',
                  'qualquer',
                ],
                labelBuilder: (h) => h,
                onChanged: (v) => setDialogState(() => horario = v),
                label: 'Horário',
                accentColor: AdminThemeColors.of(context).lime,
                fieldColor: AdminThemeColors.of(context).surface,
                menuColor: AdminThemeColors.of(context).surface2,
                textColor: AdminThemeColors.of(context).text,
                labelColor: AdminThemeColors.of(context).muted,
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
    final colors = AdminThemeColors.of(context);
    final controller = TextEditingController(
      text: plan.metaCalorias.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AdminResponsiveDialog(
        title: 'Meta diária',
        subtitle: 'Define o objetivo energético diário do aluno.',
        icon: Icons.local_fire_department_outlined,
        maxWidth: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDialogSection(
              title: 'Objetivo',
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: GoogleFonts.montserrat(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '2000',
                  suffixText: 'kcal',
                  suffixStyle: GoogleFonts.inter(
                    color: colors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                  prefixIcon: Icon(
                    Icons.local_fire_department_outlined,
                    color: colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'O valor será aplicado a todos os dias do plano.',
              style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: adminDialogCancelStyle(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Guardar meta'),
            style: adminDialogPrimaryStyle(ctx),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _saveToAllDays({'metaCalorias': result});
    }
  }

  Future<void> _editMetaAgua(NutritionPlanModel plan) async {
    final colors = AdminThemeColors.of(context);
    final controller = TextEditingController(
      text: plan.metaAgua.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AdminResponsiveDialog(
        title: 'Hidratação',
        subtitle: 'Define a quantidade de água recomendada por dia.',
        icon: Icons.water_drop_outlined,
        maxWidth: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDialogSection(
              title: 'Objetivo diário',
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: GoogleFonts.montserrat(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '2500',
                  suffixText: 'ml',
                  suffixStyle: GoogleFonts.inter(
                    color: colors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                  prefixIcon: Icon(
                    Icons.water_drop_outlined,
                    color: colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'O valor será convertido automaticamente para litros no plano.',
              style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: adminDialogCancelStyle(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Guardar meta'),
            style: adminDialogPrimaryStyle(ctx),
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
    List<FoodModel> foods;
    try {
      foods = await ref.read(nutritionRepositoryProvider).getAvailableFoods();
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível carregar os alimentos da base de dados.',
          type: NotificationType.error,
        );
      }
      return;
    }
    if (foods.isEmpty) {
      if (mounted) {
        showAppNotification(
          context,
          'Ainda não existem alimentos na base de dados. Adiciona-os primeiro na secção Alimentos.',
          type: NotificationType.info,
        );
      }
      return;
    }

    final gramsController = TextEditingController(text: '100');
    FoodModel? selectedFood;
    var visibleFoods = List<FoodModel>.from(foods);
    final result = await showDialog<(FoodModel, double)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget foodOption(FoodModel food) {
            final selected = selectedFood?.id == food.id;
            final colors = AdminThemeColors.of(ctx);
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: () => setDialogState(() => selectedFood = food),
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? colors.limeDim : colors.bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.restaurant_outlined,
                        size: 18,
                        color: selected ? colors.lime : colors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${food.caloriasPor100g.toStringAsFixed(0)} kcal · P ${food.proteinasPor100g?.toStringAsFixed(1) ?? '—'}g · C ${food.hidratosPor100g?.toStringAsFixed(1) ?? '—'}g · G ${food.gordurasPor100g?.toStringAsFixed(1) ?? '—'}g / 100g',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
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
            );
          }

          final filtered = visibleFoods;
          final colors = AdminThemeColors.of(ctx);
          return AdminResponsiveDialog(
            title: 'Adicionar alimento',
            subtitle:
                'Escolhe um alimento da base de dados e indica a quantidade.',
            icon: Icons.restaurant_menu_outlined,
            maxWidth: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminDialogSection(
                  title: 'Pesquisar na base de dados',
                  child: TextField(
                    onChanged: (value) async {
                      setDialogState(() {});
                      final trimmed = value.trim();
                      if (trimmed.isEmpty) {
                        setDialogState(
                          () => visibleFoods = List<FoodModel>.from(foods),
                        );
                        return;
                      }
                      final matches = await ref
                          .read(nutritionRepositoryProvider)
                          .searchFoods(trimmed);
                      if (ctx.mounted) {
                        setDialogState(() => visibleFoods = matches);
                      }
                    },
                    style: GoogleFonts.inter(color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Ex.: peito de frango, arroz...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Text(
                      'Nenhum alimento encontrado na base de dados.',
                      style: GoogleFonts.inter(
                        color: colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, index) => foodOption(filtered[index]),
                    ),
                  ),
                AdminDialogSection(
                  title: 'Quantidade',
                  child: TextField(
                    controller: gramsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.montserrat(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '100',
                      suffixText: 'g',
                      suffixStyle: GoogleFonts.inter(
                        color: colors.lime,
                        fontWeight: FontWeight.w800,
                      ),
                      prefixIcon: Icon(
                        Icons.scale_outlined,
                        color: colors.lime,
                      ),
                    ),
                  ),
                ),
                if (selectedFood != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Os valores nutricionais serão calculados para a quantidade indicada.',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: adminDialogCancelStyle(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: selectedFood == null
                    ? null
                    : () {
                        final grams = double.tryParse(
                          gramsController.text.replaceAll(',', '.'),
                        );
                        if (grams != null && grams > 0) {
                          Navigator.pop(ctx, (selectedFood!, grams));
                        }
                      },
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Adicionar'),
                style: adminDialogPrimaryStyle(ctx),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    final food = result.$1;
    final grams = result.$2;
    final factor = grams / 100;
    final alimento = Alimento(
      foodId: food.id,
      nome: food.nome,
      quantidade:
          '${grams.toStringAsFixed(grams == grams.roundToDouble() ? 0 : 1)}g',
      calorias: food.caloriasPor100g * factor,
      proteinas: food.proteinasPor100g == null
          ? null
          : food.proteinasPor100g! * factor,
      hidratos: food.hidratosPor100g == null
          ? null
          : food.hidratosPor100g! * factor,
      gorduras: food.gordurasPor100g == null
          ? null
          : food.gordurasPor100g! * factor,
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
    await _saveToAllDays({'refeicoes': updated.map((m) => m.toMap()).toList()});
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
