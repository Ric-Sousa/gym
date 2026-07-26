import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

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
                const EmptyState(icon: Icons.fitness_center, title: AppStrings.noWorkoutAssigned),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _createEmptyPlan,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Criar plano de treino', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminLime,
                    foregroundColor: AppColors.adminBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildPlanEditor(plans);
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.adminLime)),
      error: (_, __) => Center(child: Text('Erro ao carregar planos', style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
    );
  }

  Widget _buildPlanEditor(List<WorkoutPlanModel> plans) {
    final plan = plans[_selectedPlanIndex.clamp(0, plans.length - 1)];

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
                      label: Text(entry.value.nome, style: GoogleFonts.dmSans(fontSize: 13, color: selected ? AppColors.adminBg : AppColors.adminMuted)),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedPlanIndex = entry.key),
                      selectedColor: AppColors.adminLime,
                      backgroundColor: AppColors.adminSurface2,
                      side: BorderSide(color: selected ? AppColors.adminLime : AppColors.adminBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const Divider(height: 1, color: AppColors.adminBorder),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: plan.dias.length,
            itemBuilder: (_, index) {
              final day = plan.dias[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.adminSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.adminBorder),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.adminLimeDim,
                    child: const Icon(Icons.fitness_center, color: AppColors.adminLime, size: 16),
                  ),
                  title: Text(day.diaSemana, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.adminText)),
                  subtitle: day.foco.isNotEmpty
                      ? Text('Foco: ${day.foco}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted))
                      : null,
                  children: [
                    ...day.exercicios.map((ex) => ListTile(
                          dense: true,
                          title: Text(ex.nome, style: GoogleFonts.dmSans(color: AppColors.adminText, fontSize: 14)),
                          subtitle: Text('${ex.series}x${ex.repeticoes} • ${ex.descanso}s descanso',
                              style: GoogleFonts.dmMono(fontSize: 12, color: AppColors.adminMuted)),
                          trailing: ex.cargaSugerida != null
                              ? Text('${ex.cargaSugerida}kg', style: GoogleFonts.dmMono(fontSize: 13, color: AppColors.adminOrange))
                              : null,
                        )),
                    const Divider(color: AppColors.adminBorder, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextButton.icon(
                        onPressed: () => _addExercise(plan, day.diaSemana),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.adminLime),
                        label: Text('Adicionar exercício', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminLime)),
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

  Future<void> _createEmptyPlan() async {
    final nameCtrl = TextEditingController(text: 'Semana 1');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adminSurface,
        title: Text('Novo plano de treino', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.adminText)),
        content: TextField(controller: nameCtrl, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Nome do plano')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel, style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminLime, foregroundColor: AppColors.adminBg),
            child: Text(AppStrings.save, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final defaultDays = AppStrings.daysOfWeek.map((d) => WorkoutDay(diaSemana: d).toMap()).toList();
      await ref.read(workoutRepositoryProvider).savePlan(widget.aluno.uid, result, {'dias': defaultDays});
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }

  Future<void> _addExercise(WorkoutPlanModel plan, String diaSemana) async {
    final nome = TextEditingController();
    final series = TextEditingController(text: '3');
    final reps = TextEditingController(text: '10');
    final carga = TextEditingController();
    final descanso = TextEditingController(text: '60');
    final obs = TextEditingController();

    final result = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adminSurface,
        title: Text('Adicionar exercício', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.adminText)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nome, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Nome')),
              Row(children: [
                Expanded(child: TextField(controller: series, keyboardType: TextInputType.number, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Séries'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Reps'))),
              ]),
              TextField(controller: carga, keyboardType: TextInputType.number, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Carga (kg)')),
              TextField(controller: descanso, keyboardType: TextInputType.number, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Descanso (s)')),
              TextField(controller: obs, style: GoogleFonts.dmSans(color: AppColors.adminText), decoration: const InputDecoration(labelText: 'Observações')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel, style: GoogleFonts.dmSans(color: AppColors.adminMuted))),
          ElevatedButton(
            onPressed: () {
              if (nome.text.trim().isEmpty) return;
              Navigator.pop(ctx, Exercise(
                nome: nome.text.trim(),
                series: int.tryParse(series.text) ?? 3,
                repeticoes: int.tryParse(reps.text) ?? 10,
                cargaSugerida: double.tryParse(carga.text.replaceAll(',', '.')),
                descanso: int.tryParse(descanso.text) ?? 60,
                observacoes: obs.text.isNotEmpty ? obs.text.trim() : null,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminLime, foregroundColor: AppColors.adminBg),
            child: Text(AppStrings.save, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null) {
      final updated = plan.dias.map((d) {
        if (d.diaSemana == diaSemana) return WorkoutDay(diaSemana: d.diaSemana, foco: d.foco, exercicios: [...d.exercicios, result]);
        return d;
      }).toList();
      await ref.read(workoutRepositoryProvider).savePlan(widget.aluno.uid, plan.nome, {'dias': updated.map((d) => d.toMap()).toList()});
      ref.invalidate(adminWorkoutPlansProvider(widget.aluno.uid));
    }
  }
}
