import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../screens/student_detail_screen.dart';

/// Ecrã de edição do plano de treino (admin).
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
    final plansAsync =
        ref.watch(adminWorkoutPlansProvider(widget.aluno.uid));

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
                ElevatedButton.icon(
                  onPressed: () => _createEmptyPlan(),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar plano de treino'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }
        return _buildPlanEditor(plans);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erro ao carregar planos')),
    );
  }

  Widget _buildPlanEditor(List<WorkoutPlanModel> plans) {
    final plan = plans[_selectedPlanIndex.clamp(0, plans.length - 1)];

    return Column(
      children: [
        // Seletor de plano
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
                      label: Text(entry.value.nome),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedPlanIndex = entry.key),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const Divider(height: 1),
        // Lista de dias e exercícios
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plan.dias.length,
              itemBuilder: (_, index) {
                final day = plan.dias[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      day.diaSemana,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: day.foco.isNotEmpty
                        ? Text('Foco: ${day.foco}')
                        : null,
                    children: [
                      ...day.exercicios.map((ex) => ListTile(
                            dense: true,
                            title: Text(ex.nome),
                            subtitle: Text(
                              '${ex.series}x${ex.repeticoes} • ${ex.descanso}s descanso',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                      TextButton.icon(
                        onPressed: () =>
                            _addExercise(plan, day.diaSemana),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Adicionar exercício'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createEmptyPlan() async {
    final nameController = TextEditingController(text: 'Semana 1');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo plano de treino'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nome do plano'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final defaultDays = AppStrings.daysOfWeek
          .map((d) => WorkoutDay(diaSemana: d).toMap())
          .toList();

      await ref.read(workoutRepositoryProvider).savePlan(
            widget.aluno.uid,
            result,
            {'dias': defaultDays},
          );
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }

  Future<void> _addExercise(WorkoutPlanModel plan, String diaSemana) async {
    final nomeCtrl = TextEditingController();
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    final cargaCtrl = TextEditingController();
    final descansoCtrl = TextEditingController(text: '60');
    final obsCtrl = TextEditingController();

    final result = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar exercício'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: seriesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Séries'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reps'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: cargaCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Carga (kg)'),
              ),
              TextField(
                controller: descansoCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Descanso (s)'),
              ),
              TextField(
                controller: obsCtrl,
                decoration:
                    const InputDecoration(labelText: 'Observações'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final nome = nomeCtrl.text.trim();
              if (nome.isEmpty) return;
              Navigator.pop(
                ctx,
                Exercise(
                  nome: nome,
                  series: int.tryParse(seriesCtrl.text) ?? 3,
                  repeticoes: int.tryParse(repsCtrl.text) ?? 10,
                  cargaSugerida:
                      double.tryParse(cargaCtrl.text.replaceAll(',', '.')),
                  descanso: int.tryParse(descansoCtrl.text) ?? 60,
                  observacoes:
                      obsCtrl.text.isNotEmpty ? obsCtrl.text.trim() : null,
                ),
              );
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedDays = plan.dias.map((d) {
        if (d.diaSemana == diaSemana) {
          return WorkoutDay(
            diaSemana: d.diaSemana,
            foco: d.foco,
            exercicios: [...d.exercicios, result],
          );
        }
        return d;
      }).toList();

      await ref.read(workoutRepositoryProvider).savePlan(
            widget.aluno.uid,
            plan.nome,
            {'dias': updatedDays.map((d) => d.toMap()).toList()},
          );
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }
}
