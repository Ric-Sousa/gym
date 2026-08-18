import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/admin_theme.dart';
import '../../../core/config/app_strings.dart';
import '../../../core/utils/storage_resource.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/workout_plan_model.dart';
import '../../../data/models/exercise_catalog_model.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/widgets/app_design_system.dart';
import '../../../shared/widgets/exercise_catalog_picker.dart';

final globalWorkoutPlansProvider = StreamProvider<List<WorkoutPlanModel>>((
  ref,
) {
  return ref.read(workoutRepositoryProvider).watchGlobalPlans();
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
  final Map<String, Future<List<UserModel>>> _assignedStudentsRequests = {};

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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 256, child: _planNavigation(plans, index)),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdminThemeColors.of(context).border,
                    ),
                    Expanded(child: _planContent(plan)),
                  ],
                );
              }
              return Column(
                children: [
                  _planMobileSelector(plans, index),
                  Expanded(child: _planContent(plan)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pageHeader(List<WorkoutPlanModel> plans) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: AdminPageHeader(
        title: 'Planos de treino',
        subtitle:
            '${plans.length} plano(s) · plano → sub-planos → exercícios → atribuição',
        icon: Icons.account_tree_outlined,
        action: ElevatedButton.icon(
          onPressed: _createPlan,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Novo plano'),
        ),
      ),
    );
  }

  Widget _planNavigation(List<WorkoutPlanModel> plans, int selectedIndex) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
      color: colors.surface.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 17, color: colors.lime),
              const SizedBox(width: 8),
              Text(
                'PLANOS',
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${plans.length}',
                style: GoogleFonts.montserrat(
                  color: colors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final plan = plans[index];
                final selected = index == selectedIndex;
                final exerciseCount = plan.dias.fold<int>(
                  0,
                  (total, day) => total + day.exercicios.length,
                );
                return Material(
                  color: selected ? colors.limeDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => setState(() => _selectedPlanIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected ? colors.lime : colors.surface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.folder_copy_outlined,
                              size: 16,
                              color: selected ? colors.bg : colors.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: colors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${plan.dias.length} sub-planos · $exerciseCount exercícios',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: colors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.chevron_right_rounded
                                : Icons.circle_outlined,
                            size: selected ? 19 : 7,
                            color: selected ? colors.lime : colors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Seleciona um plano para gerir os seus sub-planos e exercícios.',
            style: GoogleFonts.inter(
              color: colors.muted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planMobileSelector(List<WorkoutPlanModel> plans, int selectedIndex) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(15),
          border: null,
        ),
        child: Row(
          children: [
            Icon(Icons.folder_copy_outlined, size: 18, color: colors.lime),
            const SizedBox(width: 10),
            Expanded(
              child: AppMenuDropdown<int>(
                value: selectedIndex,
                options: List.generate(plans.length, (i) => i),
                labelBuilder: (index) => plans[index].nome,
                onChanged: (value) {
                  setState(() => _selectedPlanIndex = value);
                },
                accentColor: colors.lime,
                fieldColor: colors.surface2,
                menuColor: colors.surface2,
                textColor: colors.text,
                labelColor: colors.muted,
              ),
            ),
            Text(
              '${plans.length} planos',
              style: GoogleFonts.inter(color: colors.muted, fontSize: 10),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _planHierarchyBanner(plan, subPlans, exerciseCount),
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
          const SizedBox(height: 18),
          _assignedStudentsSection(plan),
          const SizedBox(height: 20),
          _subPlansSection(plan, subPlans),
        ],
      ),
    );
  }

  Widget _planHierarchyBanner(
    WorkoutPlanModel plan,
    List<WorkoutDay> subPlans,
    int exerciseCount,
  ) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final identity = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.lime,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.folder_copy_rounded,
                  color: colors.bg,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Este plano contém ${subPlans.length} sub-plano(s) e $exerciseCount exercício(s).',
                      style: GoogleFonts.inter(
                        color: colors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final count = subPlans.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${subPlans.length}',
                        style: GoogleFonts.montserrat(
                          color: colors.lime,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'SUB-PLANOS',
                        style: GoogleFonts.inter(
                          color: colors.muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    ...?(count == null
                        ? null
                        : <Widget>[const SizedBox(height: 12), count]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: identity),
                    ...?(count == null ? null : <Widget>[count]),
                  ],
                );
        },
      ),
    );
  }

  Widget _subPlansSection(WorkoutPlanModel plan, List<WorkoutDay> subPlans) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final heading = Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: colors.lime,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sub-planos deste plano',
                          style: GoogleFonts.inter(
                            color: colors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Cada sub-plano agrupa os seus próprios exercícios.',
                          style: GoogleFonts.inter(
                            color: colors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final addButton = TextButton.icon(
                onPressed: () => _createSubPlan(plan),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  'Adicionar sub-plano',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: colors.surface2.withValues(alpha: 0.18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  minimumSize: const Size(0, 46),
                ),
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 8), addButton],
                    )
                  : Row(
                      children: [
                        Expanded(child: heading),
                        addButton,
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          if (subPlans.isEmpty)
            _emptySubPlans()
          else
            ...subPlans.asMap().entries.map(
              (entry) => _subPlanCard(plan, entry.value, index: entry.key),
            ),
        ],
      ),
    );
  }

  Widget _assignedStudentsSection(WorkoutPlanModel plan) {
    final colors = AdminThemeColors.of(context);
    return FutureBuilder<List<UserModel>>(
      future: _assignedStudentsFuture(plan),
      builder: (context, snapshot) {
        final students = snapshot.data ?? const <UserModel>[];
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 500;
                  final identity = Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.limeDim,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.people_alt_outlined,
                          size: 18,
                          color: colors.lime,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alunos atribuídos',
                              style: GoogleFonts.inter(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? 'A verificar atribuições...'
                                  : '${students.length} aluno(s) com este plano',
                              style: GoogleFonts.inter(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 4,
                    children: [
                      if (snapshot.connectionState != ConnectionState.waiting)
                        TextButton.icon(
                          onPressed: () => _showAssignedStudentsDialog(plan),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Ver alunos (${students.length})',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: colors.surface2.withValues(
                              alpha: 0.18,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            minimumSize: const Size(0, 46),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Atribuir aluno',
                        onPressed: () => _assignPlan(plan),
                        icon: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: colors.lime,
                        ),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            identity,
                            const SizedBox(height: 8),
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: identity),
                            actions,
                          ],
                        );
                },
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: colors.lime,
                    backgroundColor: colors.surface2,
                  ),
                )
              else if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Nenhum aluno atribuído. Usa “Atribuir a aluno” para começar.',
                    style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: students.map((student) {
                      return Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: colors.limeDim,
                              foregroundColor: colors.lime,
                              child: Text(
                                student.nome.isEmpty
                                    ? '?'
                                    : student.nome[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                student.nome,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            IconButton(
                              tooltip: 'Remover deste plano',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () =>
                                  _removeStudentFromPlan(plan, student),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<UserModel>> _assignedStudentsFuture(WorkoutPlanModel plan) {
    final planId = plan.id.isEmpty ? plan.nome : plan.id;
    return _assignedStudentsRequests.putIfAbsent(
      planId,
      () => _getAssignedStudents(plan),
    );
  }

  Future<List<UserModel>> _getAssignedStudents(WorkoutPlanModel plan) async {
    final planId = plan.id.isEmpty ? plan.nome : plan.id;
    final students = await ref.read(userRepositoryProvider).getAllAlunos();
    final repository = ref.read(workoutRepositoryProvider);
    final assigned = <UserModel>[];
    for (final student in students) {
      var isAssigned = await repository.isGlobalPlanAssigned(
        student.uid,
        planId,
      );
      if (!isAssigned && planId != plan.nome) {
        isAssigned = await repository.isGlobalPlanAssigned(
          student.uid,
          plan.nome,
        );
      }
      if (isAssigned) assigned.add(student);
    }
    return assigned;
  }

  Future<DateTime?> _assignedAt(
    WorkoutPlanModel plan,
    UserModel student,
  ) async {
    final planId = plan.id.isEmpty ? plan.nome : plan.id;
    final repository = ref.read(workoutRepositoryProvider);
    var date = await repository.getPlanAssignedAt(student.uid, planId);
    if (date == null && planId != plan.nome) {
      date = await repository.getPlanAssignedAt(student.uid, plan.nome);
    }
    return date;
  }

  Future<void> _showAssignedStudentsDialog(WorkoutPlanModel plan) async {
    final students = await _assignedStudentsFuture(plan);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AssignedStudentsDialog(
        plan: plan,
        students: students,
        assignedAt: {
          for (final student in students)
            student.uid: _assignedAt(plan, student),
        },
        onRemove: (student) => _removeStudentFromPlan(plan, student),
      ),
    );
    if (mounted) {
      final planId = plan.id.isEmpty ? plan.nome : plan.id;
      _assignedStudentsRequests.remove(planId);
      setState(() {});
    }
  }

  Future<bool> _removeStudentFromPlan(
    WorkoutPlanModel plan,
    UserModel student,
  ) async {
    final confirmed = await _confirm(
      'Remover aluno do plano?',
      '${student.nome} deixará de receber este plano, mas a conta e os restantes dados serão mantidos.',
    );
    if (!confirmed) return false;

    final planId = plan.id.isEmpty ? plan.nome : plan.id;
    try {
      final repository = ref.read(workoutRepositoryProvider);
      await repository.deletePlan(student.uid, planId);
      if (planId != plan.nome) {
        await repository.deletePlan(student.uid, plan.nome);
      }
      if (mounted) {
        _assignedStudentsRequests.remove(planId);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.nome} foi removido do plano.')),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível remover o aluno do plano.'),
          ),
        );
      }
      return false;
    }
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

  Widget _subPlanCard(
    WorkoutPlanModel plan,
    WorkoutDay subPlan, {
    int index = 0,
  }) {
    final colors = AdminThemeColors.of(context);
    final hasExercises = subPlan.exercicios.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colors.lime),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.limeDim,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.montserrat(
                                  color: colors.lime,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subPlan.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: colors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    _workoutMetaPill(
                                      Icons.calendar_today_outlined,
                                      subPlan.diaSemana.isEmpty
                                          ? 'Sem dia definido'
                                          : subPlan.diaSemana,
                                      colors.lime,
                                    ),
                                    if (subPlan.foco.trim().isNotEmpty)
                                      _workoutMetaPill(
                                        Icons.track_changes_outlined,
                                        subPlan.foco,
                                        colors.muted,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar sub-plano',
                            onPressed: () => _deleteSubPlan(plan, subPlan),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: colors.danger,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: colors.bg.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.fitness_center_outlined,
                                  size: 15,
                                  color: colors.muted,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'EXERCÍCIOS',
                                  style: GoogleFonts.inter(
                                    color: colors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${subPlan.exercicios.length}',
                                  style: GoogleFonts.montserrat(
                                    color: colors.lime,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!hasExercises)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                child: Text(
                                  'Este sub-plano ainda não tem exercícios.',
                                  style: GoogleFonts.inter(
                                    color: colors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            else
                              ...subPlan.exercicios.asMap().entries.map(
                                (entry) => _exerciseRow(
                                  plan,
                                  subPlan,
                                  entry.value,
                                  isLast:
                                      entry.key ==
                                      subPlan.exercicios.length - 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _addExercise(plan, subPlan: subPlan),
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Adicionar exercício',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: colors.surface2.withValues(
                                alpha: 0.18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              minimumSize: const Size(0, 46),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Sub-plano ${index + 1}',
                            style: GoogleFonts.inter(
                              color: colors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseRow(
    WorkoutPlanModel plan,
    WorkoutDay subPlan,
    Exercise exercise, {
    required bool isLast,
  }) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.fitness_center, size: 14, color: colors.muted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _workoutMetaPill(
                      Icons.repeat_rounded,
                      '${exercise.series} x ${exercise.repeticoes}',
                      colors.lime,
                    ),
                    _workoutMetaPill(
                      Icons.timer_outlined,
                      '${exercise.descanso}s',
                      colors.muted,
                    ),
                    if (exercise.cargaSugerida != null)
                      _workoutMetaPill(
                        Icons.fitness_center_outlined,
                        '${exercise.cargaSugerida}kg',
                        colors.orange,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar exercício',
            onPressed: () => _deleteExercise(plan, subPlan, exercise),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: colors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workoutMetaPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
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
              const SizedBox(height: 10),
              AppMenuDropdown<String>(
                value: weekday,
                options: AppStrings.daysOfWeek,
                labelBuilder: (day) => day,
                onChanged: (value) => setDialogState(() => weekday = value),
                label: 'Dia da semana',
                accentColor: AdminThemeColors.of(context).lime,
                fieldColor: AdminThemeColors.of(context).surface,
                menuColor: AdminThemeColors.of(context).surface2,
                textColor: AdminThemeColors.of(context).text,
                labelColor: AdminThemeColors.of(context).muted,
              ),
              const SizedBox(height: 10),
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

  String _planCategory(String value) {
    switch (value) {
      case 'forca':
        return 'musculação';
      case 'alongamento':
        return 'funcional';
      case 'cardio':
        return 'cardio';
      default:
        return 'funcional';
    }
  }

  String _planEquipment(String value) {
    const supported = {
      'outro',
      'barra',
      'haltere',
      'kettlebell',
      'corda',
      'peso_corporal',
      'banda',
    };
    return supported.contains(value) ? value : 'outro';
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
    if (!mounted) return;
    final selectedTarget = target;
    final name = TextEditingController();
    ExerciseCatalogModel? selectedCatalogExercise;
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
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showExerciseCatalogPicker(
                      dialogContext,
                    );
                    if (selected == null) return;
                    setDialogState(() {
                      selectedCatalogExercise = selected;
                      name.text = selected.nome;
                      category = _planCategory(selected.categoria);
                      equipment = _planEquipment(selected.equipamento);
                    });
                  },
                  icon: const Icon(Icons.library_add_outlined, size: 17),
                  label: Text(
                    selectedCatalogExercise == null
                        ? 'Escolher da biblioteca'
                        : 'Trocar exercício da biblioteca',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Exercício'),
                ),
                const SizedBox(height: 10),
                AppMenuDropdown<String>(
                  value: category,
                  options: const [
                    'musculação',
                    'funcional',
                    'pesos_livres',
                    'cardio',
                  ],
                  labelBuilder: (v) => switch (v) {
                    'musculação' => 'Musculação',
                    'funcional' => 'Funcional',
                    'pesos_livres' => 'Pesos livres',
                    _ => 'Cardio',
                  },
                  onChanged: (value) => setDialogState(() => category = value),
                  label: 'Categoria',
                  accentColor: AdminThemeColors.of(context).lime,
                  fieldColor: AdminThemeColors.of(context).surface,
                  menuColor: AdminThemeColors.of(context).surface2,
                  textColor: AdminThemeColors.of(context).text,
                  labelColor: AdminThemeColors.of(context).muted,
                ),
                const SizedBox(height: 10),
                AppMenuDropdown<String>(
                  value: equipment,
                  options: const [
                    'outro',
                    'barra',
                    'haltere',
                    'kettlebell',
                    'corda',
                    'peso_corporal',
                    'banda',
                  ],
                  labelBuilder: (v) => switch (v) {
                    'outro' => 'Outro',
                    'barra' => 'Barra',
                    'haltere' => 'Haltere',
                    'kettlebell' => 'Kettlebell',
                    'corda' => 'Corda',
                    'peso_corporal' => 'Peso corporal',
                    _ => 'Banda elástica',
                  },
                  onChanged: (value) => setDialogState(() => equipment = value),
                  label: 'Equipamento',
                  accentColor: AdminThemeColors.of(context).lime,
                  fieldColor: AdminThemeColors.of(context).surface,
                  menuColor: AdminThemeColors.of(context).surface2,
                  textColor: AdminThemeColors.of(context).text,
                  labelColor: AdminThemeColors.of(context).muted,
                ),
                const SizedBox(height: 10),
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
                        ? selectedCatalogExercise?.videoUrl
                        : video.text.trim(),
                    catalogExerciseId: selectedCatalogExercise?.id,
                    instrucoes: selectedCatalogExercise?.instrucoes ?? const [],
                    nivel: selectedCatalogExercise?.nivel,
                    musculosPrimarios:
                        selectedCatalogExercise?.musculosPrimarios ?? const [],
                    musculosSecundarios:
                        selectedCatalogExercise?.musculosSecundarios ??
                        const [],
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

  Widget _studentAvatar(UserModel student) {
    final colors = AdminThemeColors.of(context);
    final photoUrl = student.fotoPerfil?.trim();
    final initial = student.nome.trim().isEmpty
        ? '?'
        : student.nome.trim()[0].toUpperCase();

    Widget fallback() {
      return Center(
        child: Text(
          initial,
          style: GoogleFonts.montserrat(
            color: colors.lime,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(color: colors.limeDim, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl.isEmpty
          ? fallback()
          : StorageImage(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.lime,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _assignPlan(WorkoutPlanModel plan) async {
    final students = await ref.read(userRepositoryProvider).getAllAlunos();
    if (!mounted) return;
    final student = await showDialog<UserModel>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        var searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchQuery.trim().toLowerCase();
            final filteredStudents = students.where((student) {
              if (query.isEmpty) return true;
              return student.nome.toLowerCase().contains(query) ||
                  student.email.toLowerCase().contains(query);
            }).toList();

            return AdminResponsiveDialog(
              title: 'Escolher aluno',
              subtitle: 'Seleciona quem vai receber este plano de treino.',
              icon: Icons.person_add_alt_1_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (value) =>
                        setModalState(() => searchQuery = value),
                    style: TextStyle(color: colors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por nome ou email',
                      hintStyle: TextStyle(color: colors.muted, fontSize: 12),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: colors.muted,
                      ),
                      filled: true,
                      fillColor: colors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: colors.lime),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    filteredStudents.length == 1
                        ? '1 aluno disponível'
                        : '${filteredStudents.length} alunos disponíveis',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (filteredStudents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 34),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 38,
                            color: colors.muted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            students.isEmpty
                                ? 'Não existem alunos disponíveis.'
                                : 'Nenhum aluno encontrado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.muted),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 360,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 2),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (_, index) {
                          final student = filteredStudents[index];
                          return Material(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.pop(dialogContext, student),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    _studentAvatar(student),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.nome,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            student.email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: colors.limeDim,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 17,
                                        color: colors.lime,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    if (student == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _AssignPlanDialog(plan: plan, student: student),
    );
    if (mounted) {
      final planId = plan.id.isEmpty ? plan.nome : plan.id;
      _assignedStudentsRequests.remove(planId);
      setState(() {});
    }
  }
}

class _AssignedStudentsDialog extends StatefulWidget {
  final WorkoutPlanModel plan;
  final List<UserModel> students;
  final Map<String, Future<DateTime?>> assignedAt;
  final Future<bool> Function(UserModel student) onRemove;

  const _AssignedStudentsDialog({
    required this.plan,
    required this.students,
    required this.assignedAt,
    required this.onRemove,
  });

  @override
  State<_AssignedStudentsDialog> createState() =>
      _AssignedStudentsDialogState();
}

class _AssignedStudentsDialogState extends State<_AssignedStudentsDialog> {
  late final List<UserModel> _students = [...widget.students];
  String? _removingUid;

  Future<void> _remove(UserModel student) async {
    setState(() => _removingUid = student.uid);
    final removed = await widget.onRemove(student);
    if (!mounted) return;
    setState(() {
      _removingUid = null;
      if (removed) _students.removeWhere((item) => item.uid == student.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return AdminResponsiveDialog(
      title: 'Alunos atribuídos',
      subtitle: '${widget.plan.nome} · ${_students.length} aluno(s)',
      icon: Icons.people_alt_outlined,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: adminDialogPrimaryStyle(context),
          child: const Text('Concluído'),
        ),
      ],
      child: _students.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 42,
                    color: colors.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum aluno atribuído a este plano.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: colors.muted),
                  ),
                ],
              ),
            )
          : Column(
              children: _students.map((student) {
                final removing = _removingUid == student.uid;
                final initials = student.nome.trim().isEmpty
                    ? '?'
                    : student.nome.trim()[0].toUpperCase();
                final registered = student.createdAt == null
                    ? 'Registo: —'
                    : 'Registo: ${DateFormat('dd/MM/yyyy').format(student.createdAt!)}';
                final assignmentFuture = widget.assignedAt[student.uid];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(15),
                    border: null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: colors.limeDim,
                        foregroundColor: colors.lime,
                        child: Text(
                          initials,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.nome.isEmpty
                                  ? 'Aluno sem nome'
                                  : student.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: colors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              student.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _StudentDetailPill(
                                  label: student.tipoClienteDisplay,
                                  color: colors.lime,
                                ),
                                _StudentAssignmentPill(
                                  future: assignmentFuture,
                                  registered: registered,
                                  color: colors.muted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remover deste plano',
                        onPressed: removing ? null : () => _remove(student),
                        icon: removing
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.lime,
                                ),
                              )
                            : Icon(
                                Icons.person_remove_outlined,
                                color: colors.danger,
                              ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _StudentDetailPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StudentDetailPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentAssignmentPill extends StatelessWidget {
  final Future<DateTime?>? future;
  final String registered;
  final Color color;

  const _StudentAssignmentPill({
    required this.future,
    required this.registered,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return _StudentDetailPill(label: registered, color: color);
    }
    return FutureBuilder<DateTime?>(
      future: future,
      builder: (context, snapshot) {
        final assigned = snapshot.data;
        final label = assigned == null
            ? registered
            : 'Atribuído: ${DateFormat('dd/MM/yyyy').format(assigned)}';
        return _StudentDetailPill(label: label, color: color);
      },
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
              border: null,
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
