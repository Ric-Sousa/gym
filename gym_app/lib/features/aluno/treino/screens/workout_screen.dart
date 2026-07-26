import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

final workoutPlansProvider =
    FutureProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).getAllPlans(userId);
});

final todayWorkoutDiaryProvider =
    StreamProvider.family<DiaryModel?, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(diaryRepositoryProvider).diaryEntryStream(userId, today);
});

/// Ecrã de treino — Kinetic Dark.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int _selectedPlanIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final plansAsync = ref.watch(workoutPlansProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.workoutPlan,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showWorkoutHistory(userId),
            tooltip: AppStrings.workoutHistory,
          ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyState(
              icon: Icons.fitness_center,
              title: AppStrings.noWorkoutAssigned,
            );
          }
          return _buildWorkoutContent(plans, userId);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) =>
            const EmptyState(icon: Icons.error_outline, title: 'Erro'),
      ),
    );
  }

  Widget _buildWorkoutContent(List<WorkoutPlanModel> plans, String userId) {
    final todayWeekday = AppStrings.daysOfWeek[DateTime.now().weekday - 1];
    final plan = plans[_selectedPlanIndex.clamp(0, plans.length - 1)];
    final todayWorkout = plan.getWorkoutForDay(todayWeekday);

    return Column(
      children: [
        if (plans.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: plans.asMap().entries.map((entry) {
                  final isSelected = entry.key == _selectedPlanIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        entry.value.nome,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedPlanIndex = entry.key),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceHigh,
                      side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.outline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const Divider(height: 1, color: AppColors.outline),
        Expanded(
          child: todayWorkout == null || todayWorkout.exercicios.isEmpty
              ? _buildRestDay()
              : _buildExerciseList(todayWorkout, plan, userId),
        ),
      ],
    );
  }

  Widget _buildRestDay() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.self_improvement, size: 80, color: AppColors.info),
          const SizedBox(height: 16),
          Text(
            AppStrings.restDay,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.restDayMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(
      WorkoutDay todayWorkout, WorkoutPlanModel plan, String userId) {
    final diaryStream = ref.watch(todayWorkoutDiaryProvider(userId));

    return diaryStream.when(
      data: (diary) {
        final isCompleted = diary?.treinoConcluido ?? false;
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(workoutPlansProvider(userId)),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: todayWorkout.exercicios.length +
                (isCompleted ? 0 : 1),
            itemBuilder: (context, index) {
              if (index == todayWorkout.exercicios.length) {
                return _buildCompleteButton(userId);
              }
              return _buildExerciseCard(
                  todayWorkout.exercicios[index], isCompleted);
            },
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(
        child: Text('Erro', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? AppColors.primary : AppColors.outline,
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.fitness_center,
              color: AppColors.primary, size: 18),
        ),
        title: Text(
          exercise.nome,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          '${exercise.series}x${exercise.repeticoes} • ${exercise.descanso}s descanso',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _infoChip(
                        Icons.repeat, '${exercise.series} ${AppStrings.sets}'),
                    const SizedBox(width: 8),
                    _infoChip(Icons.fitness_center,
                        '${exercise.repeticoes} ${AppStrings.reps}'),
                    const SizedBox(width: 8),
                    _infoChip(Icons.timer,
                        '${exercise.descanso}${AppStrings.seconds} ${AppStrings.rest}'),
                  ],
                ),
                if (exercise.cargaSugerida != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.suggestedLoad}: ${exercise.cargaSugerida} kg',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (exercise.observacoes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise.observacoes!,
                    style: GoogleFonts.inter(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (exercise.videoURL != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: const Text(AppStrings.watchVideo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                    ),
                  ),
                ],
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCheckInDialog(exercise),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(AppStrings.checkIn),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _completeWorkout(userId),
          icon: const Icon(Icons.emoji_events),
          label: Text(
            'Concluir Treino! 💪',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeWorkout(String userId) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref.read(diaryRepositoryProvider).markWorkoutDone(userId, today, {
        'completedAt': DateTime.now().toIso8601String(),
        'exercisesDone': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.workoutCompleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.networkError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showCheckInDialog(Exercise exercise) async {
    final loadController = TextEditingController(
      text: exercise.cargaSugerida?.toString() ?? '',
    );
    final obsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Check-in: ${exercise.nome}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loadController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.actualLoad,
                suffixText: 'kg',
              ),
              style: GoogleFonts.inter(color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.observations,
                hintText: 'Como te sentiste?',
              ),
              style: GoogleFonts.inter(color: AppColors.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  void _showWorkoutHistory(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) {
          return FutureBuilder<List<DiaryModel>>(
            future: ref
                .read(diaryRepositoryProvider)
                .getHistory(userId, limit: 30),
            builder: (context, snapshot) {
              final completedWorkouts = (snapshot.data ?? [])
                  .where((d) => d.treinoConcluido)
                  .toList()
                ..sort((a, b) => b.data.compareTo(a.data));

              if (completedWorkouts.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhum treino concluído ainda.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppStrings.workoutHistory,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: completedWorkouts.length,
                      itemBuilder: (_, i) {
                        final workout = completedWorkouts[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.success,
                            child: Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                          title: Text(
                            DateFormat(AppConstants.displayDateFormat)
                                .format(DateTime.parse(workout.data)),
                            style: GoogleFonts.inter(color: AppColors.onSurface),
                          ),
                          trailing: const Text('✅'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
