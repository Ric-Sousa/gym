import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

/// Provider de planos de treino do aluno.
final workoutPlansProvider =
    FutureProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).getAllPlans(userId);
});

/// Provider do diário de hoje para verificar treino concluído.
final todayWorkoutDiaryProvider =
    StreamProvider.family<DiaryModel?, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(diaryRepositoryProvider).diaryEntryStream(userId, today);
});

/// Ecrã de treino do aluno.
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
      appBar: AppBar(
        title: const Text(AppStrings.workoutPlan),
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
        // Seletor de plano
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
                      label: Text(entry.value.nome),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedPlanIndex = entry.key),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const Divider(height: 1),
        // Conteúdo do treino
        Expanded(
          child: todayWorkout == null || todayWorkout.exercicios.isEmpty
              ? _buildRestDay()
              : _buildExerciseList(todayWorkout, plan, userId),
        ),
      ],
    );
  }

  Widget _buildRestDay() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 80, color: AppColors.info),
          SizedBox(height: 16),
          Text(
            AppStrings.restDay,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppStrings.restDayMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
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
          onRefresh: () async => ref.invalidate(workoutPlansProvider(userId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todayWorkout.exercicios.length +
                (isCompleted ? 0 : 1), // Botão de concluir no final
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erro')),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
          child: const Icon(Icons.fitness_center, color: AppColors.primary),
        ),
        title: Text(
          exercise.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${exercise.series}x${exercise.repeticoes} • ${exercise.descanso}s descanso',
          style: const TextStyle(fontSize: 13),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                if (exercise.observacoes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise.observacoes!,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (exercise.videoURL != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text(AppStrings.watchVideo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                    ),
                  ),
                ],
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCheckInDialog(exercise),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(AppStrings.checkIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
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
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
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
          label: const Text(
            'Concluir Treino! 💪',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
        title: Text('Check-in: ${exercise.nome}'),
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.observations,
                hintText: 'Como te sentiste?',
              ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) {
          return FutureBuilder<List<DiaryModel>>(
            future:
                ref.read(diaryRepositoryProvider).getHistory(userId, limit: 30),
            builder: (context, snapshot) {
              final completedWorkouts = (snapshot.data ?? [])
                  .where((d) => d.treinoConcluido)
                  .toList()
                ..sort((a, b) => b.data.compareTo(a.data));

              if (completedWorkouts.isEmpty) {
                return const Center(
                  child: Text('Nenhum treino concluído ainda.'),
                );
              }

              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      AppStrings.workoutHistory,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                            child: Icon(Icons.check, color: Colors.white),
                          ),
                          title: Text(
                            DateFormat(AppConstants.displayDateFormat)
                                .format(DateTime.parse(workout.data)),
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
