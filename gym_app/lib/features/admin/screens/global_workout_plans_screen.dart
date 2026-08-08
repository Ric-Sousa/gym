import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/admin_theme.dart';
import '../../../core/config/app_strings.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/workout_plan_model.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';

final globalWorkoutPlansProvider = FutureProvider<List<WorkoutPlanModel>>((
  ref,
) {
  return ref.read(workoutRepositoryProvider).getGlobalPlans();
});

class GlobalWorkoutPlansScreen extends ConsumerStatefulWidget {
  const GlobalWorkoutPlansScreen({super.key});

  @override
  ConsumerState<GlobalWorkoutPlansScreen> createState() =>
      _GlobalWorkoutPlansScreenState();
}

class _GlobalWorkoutPlansScreenState
    extends ConsumerState<GlobalWorkoutPlansScreen> {
  int _selectedPlanIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(globalWorkoutPlansProvider);
    final colors = AdminThemeColors.of(context);
    return plansAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.lime)),
      error: (error, _) => Center(
        child: Text(
          'Não foi possível carregar os planos: $error',
          style: GoogleFonts.inter(color: colors.muted),
        ),
      ),
      data: (plans) => plans.isEmpty ? _emptyState() : _plansView(plans),
    );
  }

  Widget _emptyState() {
    final colors = AdminThemeColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, size: 58, color: colors.muted),
          const SizedBox(height: 14),
          Text(
            'Ainda não existem planos',
            style: GoogleFonts.inter(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cria um plano e adiciona sub-planos dentro dele.',
            style: GoogleFonts.inter(color: colors.muted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _createPlan,
            icon: const Icon(Icons.add),
            label: const Text('Criar plano'),
          ),
        ],
      ),
    );
  }

  Widget _plansView(List<WorkoutPlanModel> plans) {
    final index = _selectedPlanIndex.clamp(0, plans.length - 1);
    final plan = plans[index];
    return Column(
      children: [
        _pageHeader(plans),
        _planTabs(plans, index),
        Expanded(child: _planContent(plan)),
      ],
    );
  }

  Widget _pageHeader(List<WorkoutPlanModel> plans) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLANOS DE TREINO',
                  style: GoogleFonts.barlowCondensed(
                    color: colors.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plans.length} plano(s)',
                  style: GoogleFonts.montserrat(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Plano → sub-planos → exercícios → atribuição.',
                  style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _createPlan,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Novo plano'),
          ),
        ],
      ),
    );
  }

  Widget _planTabs(List<WorkoutPlanModel> plans, int selectedIndex) {
    final colors = AdminThemeColors.of(context);
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(plans[index].nome),
            selected: selected,
            onSelected: (_) => setState(() => _selectedPlanIndex = index),
            selectedColor: colors.lime,
            backgroundColor: colors.surface2,
            labelStyle: GoogleFonts.inter(
              color: selected ? colors.bg : colors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  Widget _planContent(WorkoutPlanModel plan) {
    final colors = AdminThemeColors.of(context);
    final subPlans = plan.dias;
    final exerciseCount = subPlans.fold<int>(
      0,
      (sum, subPlan) => sum + subPlan.exercicios.length,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _assignPlan(plan),
                    icon: const Icon(Icons.person_add_alt_1, size: 17),
                    label: const Text('Atribuir a aluno'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _createSubPlan(plan),
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 17,
                    ),
                    label: const Text('Novo sub-plano'),
                  ),
                  IconButton(
                    tooltip: 'Eliminar plano',
                    onPressed: () => _deletePlan(plan),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              );
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.nome,
                    style: GoogleFonts.montserrat(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subPlans.length} sub-plano(s) · $exerciseCount exercício(s)',
                    style: GoogleFonts.inter(color: colors.muted),
                  ),
                ],
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [summary, const SizedBox(height: 14), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (subPlans.isEmpty)
            _emptySubPlans()
          else
            ...subPlans.map((subPlan) => _subPlanCard(plan, subPlan)),
        ],
      ),
    );
  }

  Widget _emptySubPlans() {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Text(
          'Cria o primeiro sub-plano para começar a adicionar exercícios.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: colors.muted),
        ),
      ),
    );
  }

  Widget _subPlanCard(WorkoutPlanModel plan, WorkoutDay subPlan) {
    final colors = AdminThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: colors.limeDim,
          child: Icon(Icons.layers_outlined, color: colors.lime, size: 17),
        ),
        title: Text(
          subPlan.displayName,
          style: GoogleFonts.inter(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${subPlan.diaSemana.isEmpty ? 'Sem dia definido' : subPlan.diaSemana} · ${subPlan.exercicios.length} exercício(s)',
          style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
        ),
        children: [
          ...subPlan.exercicios.map(
            (exercise) => ListTile(
              title: Text(
                exercise.nome,
                style: GoogleFonts.inter(color: colors.text),
              ),
              subtitle: Text(
                '${exercise.series} séries · ${exercise.repeticoes} reps · ${exercise.descanso}s descanso',
                style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (exercise.cargaSugerida != null)
                    Text(
                      '${exercise.cargaSugerida}kg',
                      style: GoogleFonts.inter(
                        color: colors.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Eliminar exercício',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _deleteExercise(plan, subPlan, exercise),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => _addExercise(plan, subPlan: subPlan),
                icon: Icon(Icons.add, size: 16, color: colors.lime),
                label: Text(
                  'Adicionar exercício',
                  style: TextStyle(color: colors.lime),
                ),
              ),
              TextButton.icon(
                onPressed: () => _deleteSubPlan(plan, subPlan),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 16,
                ),
                label: const Text(
                  'Eliminar sub-plano',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _savePlan(
    WorkoutPlanModel plan,
    List<WorkoutDay> subPlans,
  ) async {
    try {
      final planId = plan.id.isEmpty ? plan.nome : plan.id;
      final workoutRepository = ref.read(workoutRepositoryProvider);
      await workoutRepository.saveGlobalPlan(planId, {
        'nome': plan.nome,
        'dias': subPlans.map((subPlan) => subPlan.toMap()).toList(),
      });

      // Keep assigned copies synchronized with the complete global Plan.
      // An assignment is intentionally not a sub-plan selection: whenever the
      // plan changes, the assigned student receives every current sub-plan.
      final students = await ref.read(userRepositoryProvider).getAllAlunos();
      for (final student in students) {
        var assigned = await workoutRepository.getPlan(student.uid, planId);
        var legacyAssignmentFound = false;
        if (assigned == null && planId != plan.nome) {
          assigned = await workoutRepository.getPlan(student.uid, plan.nome);
          legacyAssignmentFound = assigned != null;
        }
        if (assigned == null) continue;

        await workoutRepository.savePlan(student.uid, planId, {
          'nome': plan.nome,
          'dias': subPlans.map((item) => item.toMap()).toList(),
          'assignedPlanId': planId,
          'subPlanIds': subPlans
              .map((item) => item.subPlanoId)
              .where((id) => id.isNotEmpty)
              .toList(),
        });
        if (legacyAssignmentFound) {
          await workoutRepository.deletePlan(student.uid, plan.nome);
        }
      }
      ref.invalidate(globalWorkoutPlansProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível guardar e sincronizar o plano.'),
          ),
        );
      }
    }
  }

  Future<void> _deletePlan(WorkoutPlanModel plan) async {
    if (!await _confirm(
      'Eliminar plano?',
      'Todos os sub-planos e exercícios deste plano serão removidos.',
    )) {
      return;
    }
    final planId = plan.id.isEmpty ? plan.nome : plan.id;
    final students = await ref.read(userRepositoryProvider).getAllAlunos();
    for (final student in students) {
      await ref.read(workoutRepositoryProvider).deletePlan(student.uid, planId);
      if (planId != plan.nome) {
        await ref
            .read(workoutRepositoryProvider)
            .deletePlan(student.uid, plan.nome);
      }
    }
    await ref.read(workoutRepositoryProvider).deleteGlobalPlan(planId);
    ref.invalidate(globalWorkoutPlansProvider);
    if (mounted) setState(() => _selectedPlanIndex = 0);
  }

  Future<void> _deleteSubPlan(WorkoutPlanModel plan, WorkoutDay subPlan) async {
    if (!await _confirm(
      'Eliminar sub-plano?',
      'Os exercícios deste sub-plano serão removidos do plano e das atribuições existentes.',
    )) {
      return;
    }
    await _savePlan(plan, plan.dias.where((item) => item != subPlan).toList());
  }

  Future<void> _deleteExercise(
    WorkoutPlanModel plan,
    WorkoutDay subPlan,
    Exercise exercise,
  ) async {
    if (!await _confirm(
      'Eliminar exercício?',
      'Este exercício será removido do sub-plano e das atribuições existentes.',
    )) {
      return;
    }
    final updated = plan.dias.map((item) {
      if (item != subPlan) return item;
      return WorkoutDay(
        diaSemana: item.diaSemana,
        foco: item.foco,
        subPlanoId: item.subPlanoId,
        subPlano: item.subPlano,
        exercicios: item.exercicios
            .where((entry) => entry != exercise)
            .toList(),
      );
    }).toList();
    await _savePlan(plan, updated);
  }

  Future<void> _createPlan() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Criar plano'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do plano',
            hintText: 'Ex.: Plano A',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    await ref.read(workoutRepositoryProvider).saveGlobalPlan(id, {
      'nome': name,
      'dias': <Map<String, dynamic>>[],
      'createdAt': DateTime.now(),
    });
    ref.invalidate(globalWorkoutPlansProvider);
  }

  Future<WorkoutDay?> _createSubPlan(WorkoutPlanModel plan) async {
    final name = TextEditingController();
    final focus = TextEditingController();
    String weekday = AppStrings.daysOfWeek.first;
    final result = await showDialog<WorkoutDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AdminResponsiveAlertDialog(
          title: const Text('Criar sub-plano'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome do sub-plano',
                  hintText: 'Ex.: Treino A',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Dia da semana'),
                items: AppStrings.daysOfWeek
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(
                  () => weekday = value ?? AppStrings.daysOfWeek.first,
                ),
              ),
              TextField(
                controller: focus,
                decoration: const InputDecoration(labelText: 'Foco (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  WorkoutDay(
                    diaSemana: weekday,
                    subPlanoId: '${DateTime.now().microsecondsSinceEpoch}',
                    subPlano: name.text.trim(),
                    foco: focus.text.trim(),
                  ),
                );
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return null;
    await _savePlan(plan, [...plan.dias, result]);
    return result;
  }

  Future<void> _addExercise(
    WorkoutPlanModel plan, {
    WorkoutDay? subPlan,
  }) async {
    WorkoutDay? target = subPlan;
    if (target == null) {
      if (plan.dias.isEmpty) {
        target = await _createSubPlan(plan);
        if (target == null) return;
      } else {
        target = plan.dias.first;
      }
    }
    final selectedTarget = target;
    final name = TextEditingController();
    final sets = TextEditingController(text: '3');
    final reps = TextEditingController(text: '10');
    final load = TextEditingController();
    final rest = TextEditingController(text: '60');
    final duration = TextEditingController();
    final rounds = TextEditingController();
    final observations = TextEditingController();
    final video = TextEditingController();
    String category = 'musculação';
    String equipment = 'outro';
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AdminResponsiveAlertDialog(
          title: Text('Adicionar exercício em ${selectedTarget.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Exercício'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: const [
                    DropdownMenuItem(
                      value: 'musculação',
                      child: Text('Musculação'),
                    ),
                    DropdownMenuItem(
                      value: 'funcional',
                      child: Text('Funcional'),
                    ),
                    DropdownMenuItem(
                      value: 'pesos_livres',
                      child: Text('Pesos livres'),
                    ),
                    DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? 'musculação'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: equipment,
                  decoration: const InputDecoration(labelText: 'Equipamento'),
                  items: const [
                    DropdownMenuItem(value: 'outro', child: Text('Outro')),
                    DropdownMenuItem(value: 'barra', child: Text('Barra')),
                    DropdownMenuItem(value: 'haltere', child: Text('Haltere')),
                    DropdownMenuItem(
                      value: 'kettlebell',
                      child: Text('Kettlebell'),
                    ),
                    DropdownMenuItem(value: 'corda', child: Text('Corda')),
                    DropdownMenuItem(
                      value: 'peso_corporal',
                      child: Text('Peso corporal'),
                    ),
                    DropdownMenuItem(
                      value: 'banda',
                      child: Text('Banda elástica'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => equipment = value ?? 'outro'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sets,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Séries'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: reps,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Repetições',
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: load,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Carga/peso (kg)',
                  ),
                ),
                TextField(
                  controller: rest,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Descanso (segundos)',
                  ),
                ),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duração (opcional)',
                  ),
                ),
                TextField(
                  controller: rounds,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rounds (opcional)',
                  ),
                ),
                TextField(
                  controller: observations,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
                TextField(
                  controller: video,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de vídeo (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  Exercise(
                    nome: name.text.trim(),
                    series: int.tryParse(sets.text) ?? 3,
                    repeticoes: int.tryParse(reps.text) ?? 10,
                    cargaSugerida: double.tryParse(
                      load.text.replaceAll(',', '.'),
                    ),
                    descanso: int.tryParse(rest.text) ?? 60,
                    categoria: category,
                    equipamento: equipment,
                    duracao: int.tryParse(duration.text),
                    rounds: int.tryParse(rounds.text),
                    observacoes: observations.text.trim().isEmpty
                        ? null
                        : observations.text.trim(),
                    videoURL: video.text.trim().isEmpty
                        ? null
                        : video.text.trim(),
                  ),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    if (exercise == null) return;
    final updated = plan.dias.map((item) {
      if (item != selectedTarget) return item;
      return WorkoutDay(
        diaSemana: item.diaSemana,
        foco: item.foco,
        subPlanoId: item.subPlanoId,
        subPlano: item.subPlano,
        exercicios: [...item.exercicios, exercise],
      );
    }).toList();
    if (!plan.dias.contains(selectedTarget)) {
      updated.add(
        WorkoutDay(
          diaSemana: selectedTarget.diaSemana,
          foco: selectedTarget.foco,
          subPlanoId: selectedTarget.subPlanoId,
          subPlano: selectedTarget.subPlano,
          exercicios: [...selectedTarget.exercicios, exercise],
        ),
      );
    }
    await _savePlan(plan, updated);
  }

  Future<void> _assignPlan(WorkoutPlanModel plan) async {
    final students = await ref.read(userRepositoryProvider).getAllAlunos();
    if (!mounted) return;
    final student = await showDialog<UserModel>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        return AdminResponsiveDialog(
          title: 'Escolher aluno',
          subtitle:
              'O plano completo será atribuído com todos os sub-planos e exercícios.',
          icon: Icons.person_add_alt_1_rounded,
          child: students.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'Não existem alunos disponíveis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted),
                  ),
                )
              : SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => Divider(color: colors.border),
                    itemBuilder: (_, index) {
                      final student = students[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.limeDim,
                          foregroundColor: colors.lime,
                          child: Text(
                            student.nome.isEmpty
                                ? '?'
                                : student.nome[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          student.nome,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          student.email,
                          style: TextStyle(color: colors.muted, fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.muted,
                        ),
                        onTap: () => Navigator.pop(dialogContext, student),
                      );
                    },
                  ),
                ),
        );
      },
    );
    if (student == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _AssignPlanDialog(plan: plan, student: student),
    );
  }
}

class _AssignPlanDialog extends ConsumerStatefulWidget {
  final WorkoutPlanModel plan;
  final UserModel student;

  const _AssignPlanDialog({required this.plan, required this.student});

  @override
  ConsumerState<_AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends ConsumerState<_AssignPlanDialog> {
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    final planId = widget.plan.id.isEmpty ? widget.plan.nome : widget.plan.id;
    try {
      await ref
          .read(workoutRepositoryProvider)
          .savePlan(widget.student.uid, planId, {
            'nome': widget.plan.nome,
            'dias': widget.plan.dias.map((item) => item.toMap()).toList(),
            'assignedPlanId': planId,
            'subPlanIds': widget.plan.dias
                .map((item) => item.subPlanoId)
                .where((id) => id.isNotEmpty)
                .toList(),
            'assignedAt': DateTime.now(),
          });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atribuir o plano.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final exerciseCount = widget.plan.dias.fold<int>(
      0,
      (sum, item) => sum + item.exercicios.length,
    );
    return AdminResponsiveDialog(
      title: 'Atribuir plano completo',
      subtitle:
          'Confirma a atribuição de todo o conteúdo a ${widget.student.nome}.',
      icon: Icons.assignment_turned_in_outlined,
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          style: adminDialogCancelStyle(context),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton.icon(
          onPressed: saving ? null : _save,
          style: adminDialogPrimaryStyle(context),
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(saving ? 'A atribuir...' : 'Atribuir plano'),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.limeDim,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.lime.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: colors.lime, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.nome,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.plan.dias.length} sub-planos · $exerciseCount exercícios',
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AdminDialogSection(
            title: 'Aluno selecionado',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colors.surface2,
                foregroundColor: colors.lime,
                child: Text(
                  widget.student.nome.isEmpty
                      ? '?'
                      : widget.student.nome[0].toUpperCase(),
                ),
              ),
              title: Text(
                widget.student.nome,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                widget.student.email,
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ),
          ),
          AdminDialogSection(
            title: 'Conteúdo incluído',
            child: Column(
              children: widget.plan.dias
                  .map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 17,
                            color: colors.lime,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.displayName,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${item.exercicios.length}',
                            style: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
