import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/admin_theme.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/admin_responsive_dialog.dart';

/// Editor do plano de treino (admin) — GYMBT Lime+Dark.
class WorkoutEditor extends ConsumerStatefulWidget {
  final UserModel aluno;
  const WorkoutEditor({super.key, required this.aluno});

  @override
  ConsumerState<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends ConsumerState<WorkoutEditor> {
  int _selectedPlanIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminWorkoutPlansProvider(widget.aluno.uid));

    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyState(
                  icon: Icons.fitness_center,
                  title: AppStrings.noWorkoutAssigned,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _createEmptyPlan,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Criar plano de treino',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildPlanEditor(plans);
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: AdminThemeColors.of(context).lime,
        ),
      ),
      error: (_, __) => Center(
        child: Text(
          'Erro ao carregar planos',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
      ),
    );
  }

  Widget _buildPlanEditor(List<WorkoutPlanModel> plans) {
    final plan = plans[_selectedPlanIndex.clamp(0, plans.length - 1)];
    final activeDays = plan.dias
        .where((day) => day.exercicios.isNotEmpty)
        .toList();
    final colors = AdminThemeColors.of(context);

    return Column(
      children: [
        if (plans.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: plans.asMap().entries.map((entry) {
                  final selected = entry.key == _selectedPlanIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        entry.value.nome,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: selected ? colors.bg : colors.muted,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedPlanIndex = entry.key),
                      selectedColor: colors.lime,
                      backgroundColor: colors.surface2,
                      side: BorderSide(
                        color: selected ? colors.lime : colors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.nome,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeDays.isEmpty
                          ? 'Ainda sem exercícios associados'
                          : '${activeDays.length} dia(s) com treino',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addExercise(plan),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar treino'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.lime,
                  foregroundColor: colors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activeDays.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          size: 56,
                          color: colors.muted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Plano criado com sucesso',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Agora escolha o dia da semana e adicione o primeiro exercício.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _addExercise(plan),
                          icon: const Icon(Icons.add),
                          label: const Text('Escolher dia e exercício'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: activeDays.length,
                  itemBuilder: (_, index) {
                    final day = activeDays[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.limeDim,
                          child: Icon(
                            Icons.fitness_center,
                            color: colors.lime,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          day.diaSemana,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        subtitle: Text(
                          '${day.exercicios.length} exercício(s)${day.foco.isEmpty ? '' : ' · ${day.foco}'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                        children: [
                          ...day.exercicios.map(
                            (ex) => ListTile(
                              dense: true,
                              title: Text(
                                ex.nome,
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: _buildExerciseSubtitle(ex),
                              trailing: ex.cargaSugerida != null
                                  ? Text(
                                      '${ex.cargaSugerida}kg',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        color: colors.orange,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            child: TextButton.icon(
                              onPressed: () => _addExercise(plan),
                              icon: Icon(
                                Icons.add,
                                size: 14,
                                color: colors.lime,
                              ),
                              label: Text(
                                'Adicionar exercício neste plano',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.lime,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseSubtitle(Exercise ex) {
    final parts = <String>[];
    if (ex.categoria == 'musculação' || ex.categoria == 'pesos_livres') {
      parts.add('${ex.series}x${ex.repeticoes}');
    }
    if (ex.duracao != null) parts.add('${ex.duracao}s');
    if (ex.rounds != null) parts.add('${ex.rounds} rounds');
    parts.add('${ex.descanso}s descanso');
    parts.add(_equipamentoEmoji(ex.equipamento));
    return Text(
      parts.join(' • '),
      style: GoogleFonts.montserrat(
        fontSize: 12,
        color: AdminThemeColors.of(context).muted,
      ),
    );
  }

  String _equipamentoEmoji(String equip) {
    switch (equip) {
      case 'barra':
        return '🏋️';
      case 'haltere':
        return '💪';
      case 'kettlebell':
        return '🔔';
      case 'corda':
        return '🪢';
      case 'peso_corporal':
        return '🧘';
      case 'banda':
        return '🎗️';
      default:
        return '🔧';
    }
  }

  Future<void> _createEmptyPlan() async {
    final nameCtrl = TextEditingController(text: 'Semana 1');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        title: Text(
          'Novo plano de treino',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
          decoration: const InputDecoration(labelText: 'Nome do plano'),
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
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
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
      await ref.read(workoutRepositoryProvider).savePlan(
        widget.aluno.uid,
        result,
        {'dias': <Map<String, dynamic>>[]},
      );
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }

  Future<void> _addExercise(WorkoutPlanModel plan) async {
    final nome = TextEditingController();
    final dayOptions = <String>{
      ...AppStrings.daysOfWeek,
      ...plan.dias.map((day) => day.diaSemana),
    }.toList();
    String selectedDay = dayOptions.first;
    final series = TextEditingController(text: '3');
    final reps = TextEditingController(text: '10');
    final carga = TextEditingController();
    final descanso = TextEditingController(text: '60');
    final obs = TextEditingController();
    final duracao = TextEditingController();
    final rounds = TextEditingController();
    String selectedCategoria = 'musculação';
    String selectedEquipamento = 'outro';

    final result = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          title: Text(
            'Adicionar exercício',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDay,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Dia da semana',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                  ),
                  items: dayOptions
                      .map(
                        (day) => DropdownMenuItem(value: day, child: Text(day)),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(
                    () => selectedDay = value ?? dayOptions.first,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nome,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                // Categoria com ícones
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoria,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'musculação',
                      child: Text('🏋️ Musculação'),
                    ),
                    DropdownMenuItem(
                      value: 'funcional',
                      child: Text('⚡ Funcional'),
                    ),
                    DropdownMenuItem(
                      value: 'pesos_livres',
                      child: Text('🪨 Pesos Livres'),
                    ),
                    DropdownMenuItem(value: 'cardio', child: Text('🏃 Cardio')),
                  ],
                  onChanged: (v) => setDialogState(
                    () => selectedCategoria = v ?? 'musculação',
                  ),
                ),
                const SizedBox(height: 12),
                // Equipamento
                DropdownButtonFormField<String>(
                  initialValue: selectedEquipamento,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Equipamento',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'outro', child: Text('🔧 Outro')),
                    DropdownMenuItem(value: 'barra', child: Text('🏋️ Barra')),
                    DropdownMenuItem(
                      value: 'haltere',
                      child: Text('💪 Haltere'),
                    ),
                    DropdownMenuItem(
                      value: 'kettlebell',
                      child: Text('🔔 Kettlebell'),
                    ),
                    DropdownMenuItem(value: 'corda', child: Text('🪢 Corda')),
                    DropdownMenuItem(
                      value: 'peso_corporal',
                      child: Text('🧘 Peso Corporal'),
                    ),
                    DropdownMenuItem(
                      value: 'banda',
                      child: Text('🎗️ Banda Elástica'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedEquipamento = v ?? 'outro'),
                ),
                const SizedBox(height: 12),
                // Campos específicos para funcional/pesos_livres
                if (selectedCategoria == 'funcional' ||
                    selectedCategoria == 'pesos_livres' ||
                    selectedCategoria == 'cardio') ...[
                  TextField(
                    controller: duracao,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).text,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Duração (segundos)',
                      hintText: 'Ex: 60 para corda',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rounds,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).text,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Rounds',
                      hintText: 'Ex: 3 rounds',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Campos específicos para musculação/pesos_livres
                if (selectedCategoria == 'musculação' ||
                    selectedCategoria == 'pesos_livres') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: series,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).text,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Séries',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: reps,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).text,
                          ),
                          decoration: const InputDecoration(labelText: 'Reps'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: carga,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).text,
                    ),
                    decoration: const InputDecoration(labelText: 'Carga (kg)'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: descanso,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: const InputDecoration(labelText: 'Descanso (s)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obs,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
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
              onPressed: () {
                if (nome.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  Exercise(
                    nome: nome.text.trim(),
                    series: int.tryParse(series.text) ?? 3,
                    repeticoes: int.tryParse(reps.text) ?? 10,
                    cargaSugerida: double.tryParse(
                      carga.text.replaceAll(',', '.'),
                    ),
                    descanso: int.tryParse(descanso.text) ?? 60,
                    observacoes: obs.text.isNotEmpty ? obs.text.trim() : null,
                    categoria: selectedCategoria,
                    equipamento: selectedEquipamento,
                    duracao: int.tryParse(duracao.text),
                    rounds: int.tryParse(rounds.text),
                  ),
                );
              },
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
    if (result != null) {
      var foundDay = false;
      final updated = plan.dias.map((day) {
        if (day.diaSemana != selectedDay) return day;
        foundDay = true;
        return WorkoutDay(
          diaSemana: day.diaSemana,
          foco: day.foco,
          exercicios: [...day.exercicios, result],
        );
      }).toList();
      if (!foundDay) {
        updated.add(WorkoutDay(diaSemana: selectedDay, exercicios: [result]));
      }
      await ref.read(workoutRepositoryProvider).savePlan(
        widget.aluno.uid,
        plan.nome,
        {'dias': updated.map((day) => day.toMap()).toList()},
      );
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }
}
