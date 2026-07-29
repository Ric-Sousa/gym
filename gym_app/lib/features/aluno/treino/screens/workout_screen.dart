import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../data/models/workout_log_model.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_notification.dart';

final workoutPlansProvider =
    FutureProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).getAllPlans(userId);
});

final todayWorkoutDiaryProvider =
    StreamProvider.family<DiaryModel?, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(diaryRepositoryProvider).diaryEntryStream(userId, today);
});

final todayWorkoutLogProvider =
    FutureProvider.family<WorkoutLogModel?, String>((ref, userId) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(workoutLogRepositoryProvider).getLog(userId, today);
});

/// Ecrã de treino — Execução interativa com registo de séries, timer e vídeos.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen>
    with TickerProviderStateMixin {
  int _selectedPlanIndex = 0;
  final Map<String, TextEditingController> _cargaControllers = {};
  final Map<String, TextEditingController> _repControllers = {};
  WorkoutLogModel? _activeLog;
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;
  String? _restingExercise;
  String _restMode = 'DESCANSO';
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _cargaControllers.values) {
      c.dispose();
    }
    for (final c in _repControllers.values) {
      c.dispose();
    }
    _restTimer?.cancel();
    super.dispose();
  }

  String _seriesKey(String exNome, int serieNum, String field) =>
      '${exNome}_s${serieNum}_$field';

  TextEditingController _getController(
      String exNome, int serieNum, String field, String? initialValue) {
    final key = _seriesKey(exNome, serieNum, field);
    final map = field == 'carga' ? _cargaControllers : _repControllers;
    if (!map.containsKey(key)) {
      map[key] = TextEditingController(text: initialValue ?? '');
    }
    return map[key]!;
  }

  void _initFromPlan(WorkoutDay todayWorkout, WorkoutPlanModel plan) {
    if (_initialized) return;
    _initialized = true;

    _activeLog = WorkoutLogModel(
      userId: ref.read(authProvider).user?.uid ?? '',
      data: DateTime.now(),
      planoSemana: plan.nome,
      diaSemana: todayWorkout.diaSemana,
      foco: todayWorkout.foco,
      exercicios: todayWorkout.exercicios.map((e) {
        return ExerciseLog.fromExercise(
          e.nome,
          e.series,
          e.grupoMuscular,
        );
      }).toList(),
    );
  }

  void _restoreFromLog(WorkoutLogModel log) {
    _initialized = true;
    _activeLog = log;
  }

  Future<void> _saveLog() async {
    if (_activeLog == null || _saving) return;
    _saving = true;
    final userId = ref.read(authProvider).user?.uid ?? '';
    final dateKey = DateFormat(AppConstants.workoutLogDateFormat)
        .format(_activeLog!.data);
    try {
      await ref
          .read(workoutLogRepositoryProvider)
          .saveLog(userId, dateKey, _activeLog!.toMap());
    } catch (_) {
      // Silently fail auto-save
    }
    _saving = false;
  }

  void _toggleSerie(ExerciseLog exercise, int serieIdx) {
    setState(() {
      final updatedSeries = exercise.series.toList();
      final s = updatedSeries[serieIdx];
      updatedSeries[serieIdx] = s.copyWith(concluida: !s.concluida);
      final updatedExercises = _activeLog!.exercicios.toList();
      final exIdx = updatedExercises.indexOf(exercise);
      updatedExercises[exIdx] = ExerciseLog(
        nome: exercise.nome,
        grupoMuscular: exercise.grupoMuscular,
        series: updatedSeries,
      );
      _activeLog = _activeLog!.copyWith(exercicios: updatedExercises);
    });
    _saveLog();
  }

  void _updateSerieData(
      ExerciseLog exercise, int serieIdx, String field, String value) {
    final numValue = double.tryParse(value.replaceAll(',', '.'));
    setState(() {
      final updatedSeries = exercise.series.toList();
      final s = updatedSeries[serieIdx];
      if (field == 'carga') {
        updatedSeries[serieIdx] =
            s.copyWith(carga: numValue, clearCarga: value.isEmpty);
      } else {
        final reps = int.tryParse(value);
        updatedSeries[serieIdx] = s.copyWith(
            repeticoes: reps, clearRepeticoes: value.isEmpty);
      }
      final updatedExercises = _activeLog!.exercicios.toList();
      final exIdx = updatedExercises.indexOf(exercise);
      updatedExercises[exIdx] = ExerciseLog(
        nome: exercise.nome,
        grupoMuscular: exercise.grupoMuscular,
        series: updatedSeries,
      );
      _activeLog = _activeLog!.copyWith(exercicios: updatedExercises);
    });
    _saveLog();
  }

  void _startRestTimer(int seconds, String exerciseName, {String mode = 'DESCANSO'}) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _isResting = true;
      _restingExercise = exerciseName;
      _restMode = mode;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isResting = false;
            _restSecondsRemaining = 0;
            _restingExercise = null;
          });
        }
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
      _restingExercise = null;
      _restMode = 'DESCANSO';
    });
  }

  Future<void> _completeWorkout() async {
    final userId = ref.read(authProvider).user?.uid ?? '';
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    final dateKey =
        DateFormat(AppConstants.workoutLogDateFormat).format(DateTime.now());

    try {
      // Guarda log final
      final finalLog = _activeLog!.copyWith(completedAt: DateTime.now());
      await ref
          .read(workoutLogRepositoryProvider)
          .saveLog(userId, dateKey, finalLog.toMap());

      // Marca diário
      await ref.read(diaryRepositoryProvider).markWorkoutDone(userId, today, {
        'completedAt': DateTime.now().toIso8601String(),
        'exercisesDone': true,
      });

      if (mounted) {
        showAppNotification(context, 'Treino concluído! 💪🔥',
            type: NotificationType.success);
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(context, AppStrings.networkError,
            type: NotificationType.error);
      }
    }
  }

  void _showVideoPlayer(String url, String exerciseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _VideoPlayerSheet(videoUrl: url, title: exerciseName),
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
          return FutureBuilder<List<WorkoutLogModel>>(
            future: ref
                .read(workoutLogRepositoryProvider)
                .getHistory(userId, limit: 30),
            builder: (context, snapshot) {
              final logs = (snapshot.data ?? [])
                ..sort((a, b) => b.data.compareTo(a.data));

              if (logs.isEmpty) {
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
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                        final log = logs[i];
                        final dateStr = DateFormat('dd/MM/yyyy')
                            .format(log.data);
                        final seriesDone = log.seriesConcluidas;
                        final seriesTotal = log.seriesTotais;
                        final duration = log.duracaoMinutos > 0
                            ? ' • ${log.duracaoMinutos}min'
                            : '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: log.concluido
                                ? AppColors.success
                                : AppColors.primary,
                            radius: 16,
                            child: Icon(
                              log.concluido
                                  ? Icons.check
                                  : Icons.fitness_center,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            '$dateStr — ${log.diaSemana}',
                            style:
                                GoogleFonts.inter(color: AppColors.onSurface),
                          ),
                          subtitle: Text(
                            '${log.planoSemana} • $seriesDone/$seriesTotal séries$duration',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: log.concluido
                              ? const Text('✅')
                              : Text(
                                  '${(log.progresso * 100).toInt()}%',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final plansAsync = ref.watch(workoutPlansProvider(userId));
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          return _buildWorkoutContent(plans, userId, isMobile);
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) =>
            const EmptyState(icon: Icons.error_outline, title: 'Erro'),
      ),
    );
  }

  Widget _buildWorkoutContent(
      List<WorkoutPlanModel> plans, String userId, bool isMobile) {
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
                      onSelected: (_) {
                        setState(() {
                          _selectedPlanIndex = entry.key;
                          _initialized = false;
                          // Limpa controllers antigos
                          for (final c in _cargaControllers.values) {
                            c.dispose();
                          }
                          for (final c in _repControllers.values) {
                            c.dispose();
                          }
                          _cargaControllers.clear();
                          _repControllers.clear();
                        });
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceHigh,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.outline,
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
              : _buildExecutionView(todayWorkout, plan, userId, isMobile),
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

  Widget _buildExecutionView(
      WorkoutDay todayWorkout, WorkoutPlanModel plan, String userId, bool isMobile) {
    // Check for existing log
    final logAsync = ref.watch(todayWorkoutLogProvider(userId));

    return logAsync.when(
      data: (existingLog) {
        if (existingLog != null && !_initialized) {
          _restoreFromLog(existingLog);
        } else if (!_initialized) {
          _initFromPlan(todayWorkout, plan);
        }

        if (_activeLog == null) {
          return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary));
        }

        final progress = _activeLog!.progresso;
        final seriesDone = _activeLog!.seriesConcluidas;
        final seriesTotal = _activeLog!.seriesTotais;

        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20,
                12,
                isMobile ? 12 : 20,
                isMobile ? 100 : 120,
              ),
              itemCount: _activeLog!.exercicios.length,
              itemBuilder: (context, index) {
                final exerciseLog = _activeLog!.exercicios[index];
                final plannedExercise = todayWorkout.exercicios[index];
                return _buildExerciseCard(
                  exerciseLog,
                  plannedExercise,
                  isMobile,
                );
              },
            ),
            // Rest timer overlay
            if (_isResting) _buildRestTimerOverlay(),
            // Bottom progress bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(progress, seriesDone, seriesTotal),
            ),
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(
          child: Text('Erro', style: TextStyle(color: AppColors.textSecondary))),
    );
  }

  Widget _buildExerciseCard(
      ExerciseLog exerciseLog, Exercise plannedExercise, bool isMobile) {
    final allDone = exerciseLog.todasConcluidas;
    final isFuncional = plannedExercise.categoria == 'funcional' ||
        plannedExercise.categoria == 'cardio' ||
        plannedExercise.duracao != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allDone ? AppColors.success : AppColors.outline,
          width: allDone ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: !allDone,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: allDone
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            allDone ? Icons.check_circle : _funcionalIcon(plannedExercise),
            color: allDone ? AppColors.success : AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          exerciseLog.nome,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          isFuncional
              ? _funcionalSubtitle(plannedExercise, exerciseLog)
              : '${exerciseLog.seriesConcluidas}/${exerciseLog.totalSeries} séries • '
                '${plannedExercise.series}x${plannedExercise.repeticoes}'
                '${plannedExercise.cargaSugerida != null ? ' • ${plannedExercise.cargaSugerida}kg' : ''}',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                Row(
                  children: [
                    if (plannedExercise.videoURL != null) ...[
                      _actionChip(
                        Icons.play_circle_outline,
                        'Vídeo',
                        AppColors.info,
                        () => _showVideoPlayer(
                          plannedExercise.videoURL!,
                          plannedExercise.nome,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _actionChip(
                      Icons.timer_outlined,
                      'Descanso ${plannedExercise.descanso}s',
                      AppColors.warning,
                      () => _startRestTimer(
                        plannedExercise.descanso,
                        plannedExercise.nome,
                      ),
                    ),
                    if (isFuncional && plannedExercise.duracao != null) ...[
                      const SizedBox(width: 8),
                      _actionChip(
                        Icons.play_arrow,
                        'Timer ${plannedExercise.duracao}s',
                        AppColors.success,
                        () => _startRestTimer(
                          plannedExercise.duracao!,
                          plannedExercise.nome,
                          mode: 'EXERCÍCIO',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                // Funcional — card simplificado com rounds + toggle
                if (isFuncional) ...[
                  _buildFuncionalCard(exerciseLog, plannedExercise),
                ] else ...[
                  // Series table header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: isMobile ? 36 : 44,
                          child: Text('Série',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              )),
                        ),
                        Expanded(
                          child: Text('Carga (kg)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              )),
                        ),
                        Expanded(
                          child: Text('Reps',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              )),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Series rows
                  ...exerciseLog.series.asMap().entries.map((entry) {
                    final s = entry.value;
                    final serieIdx = entry.key;
                    final cargaCtrl =
                        _getController(exerciseLog.nome, s.numero, 'carga',
                            s.carga?.toString());
                    final repCtrl = _getController(exerciseLog.nome, s.numero,
                        'rep', s.repeticoes?.toString());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: s.concluida
                            ? AppColors.success.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: isMobile ? 36 : 44,
                            child: Text(
                              '#${s.numero}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: s.concluida
                                    ? AppColors.success
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: cargaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.onSurface,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceHigh,
                                ),
                                onChanged: (v) => _updateSerieData(
                                    exerciseLog, serieIdx, 'carga', v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: repCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.onSurface,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceHigh,
                                ),
                                onChanged: (v) => _updateSerieData(
                                    exerciseLog, serieIdx, 'rep', v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                _toggleSerie(exerciseLog, serieIdx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.concluida
                                    ? AppColors.success
                                    : AppColors.surfaceHigh,
                                border: Border.all(
                                  color: s.concluida
                                      ? AppColors.success
                                      : AppColors.outline,
                                  width: 2,
                                ),
                              ),
                              child: s.concluida
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : const SizedBox(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (plannedExercise.observacoes != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plannedExercise.observacoes!,
                            style: GoogleFonts.inter(
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _funcionalIcon(Exercise ex) {
    if (ex.categoria == 'cardio') return Icons.directions_run;
    if (ex.equipamento == 'corda') return Icons.bolt;
    if (ex.equipamento == 'kettlebell') return Icons.fitness_center;
    return Icons.bolt;
  }

  String _funcionalSubtitle(Exercise ex, ExerciseLog log) {
    final parts = <String>[];
    if (ex.duracao != null) parts.add('${ex.duracao}s');
    if (ex.rounds != null) parts.add('${ex.rounds} rounds');
    parts.add(ex.equipamento == 'corda' ? '🪢 Corda' : ex.equipamento == 'kettlebell' ? '🔔 Kettlebell' : '⚡ Funcional');
    return parts.join(' • ');
  }

  Widget _buildFuncionalCard(ExerciseLog exerciseLog, Exercise exercise) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Info row
          Row(
            children: [
              _funcionalInfoChip(Icons.timer, '${exercise.duracao ?? exercise.descanso}s'),
              const SizedBox(width: 10),
              if (exercise.rounds != null) ...[
                _funcionalInfoChip(Icons.repeat, '${exercise.rounds} rounds'),
                const SizedBox(width: 10),
              ],
              _funcionalInfoChip(Icons.fitness_center, exercise.equipamento == 'corda' ? 'Corda' : exercise.equipamento == 'kettlebell' ? 'Kettlebell' : 'Funcional'),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle complete button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _toggleFuncionalComplete(exerciseLog),
              icon: Icon(
                exerciseLog.todasConcluidas ? Icons.check_circle : Icons.play_circle_outline,
                size: 20,
              ),
              label: Text(
                exerciseLog.todasConcluidas ? 'CONCLUÍDO ✅' : 'MARCAR COMO CONCLUÍDO',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: exerciseLog.todasConcluidas
                    ? AppColors.success
                    : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _funcionalInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  void _toggleFuncionalComplete(ExerciseLog exercise) {
    setState(() {
      final updatedExercises = _activeLog!.exercicios.toList();
      final exIdx = updatedExercises.indexOf(exercise);
      // Toggle todas as séries
      final allDone = exercise.todasConcluidas;
      final updatedSeries = exercise.series.map((s) => s.copyWith(concluida: !allDone)).toList();
      updatedExercises[exIdx] = ExerciseLog(
        nome: exercise.nome,
        grupoMuscular: exercise.grupoMuscular,
        series: updatedSeries,
      );
      _activeLog = _activeLog!.copyWith(exercicios: updatedExercises);
    });
    _saveLog();
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestTimerOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _stopRestTimer,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _restMode,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _restingExercise ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$_restSecondsRemaining',
                        style: GoogleFonts.montserrat(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'segundos',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _stopRestTimer,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Saltar descanso'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(double progress, int seriesDone, int seriesTotal) {
    final allDone = progress >= 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: const Border(
          top: BorderSide(color: AppColors.outline),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  '$seriesDone / $seriesTotal séries',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.outline,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Complete button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: allDone ? () => _completeWorkout() : null,
                icon: const Icon(Icons.emoji_events),
                label: Text(
                  allDone ? 'CONCLUIR TREINO! 💪' : 'Completa todas as séries',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allDone ? AppColors.primary : AppColors.outline,
                  foregroundColor: allDone
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet com player de vídeo.
class _VideoPlayerSheet extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _VideoPlayerSheet({required this.videoUrl, required this.title});

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (_error)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.videocam_off,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Não foi possível carregar o vídeo.\nAbre no browser:',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.videoUrl,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.info,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (!_initialized)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: AppColors.outlineVariant,
                      backgroundColor: AppColors.outline,
                    ),
                  ),
                  _VideoControls(controller: _controller),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, VideoPlayerValue value, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
              onPressed: () {
                final newPos =
                    value.position - const Duration(seconds: 10);
                controller
                    .seekTo(newPos < Duration.zero ? Duration.zero : newPos);
              },
            ),
            IconButton(
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                color: Colors.white,
                size: 44,
              ),
              onPressed: () {
                if (value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
              onPressed: () {
                final newPos =
                    value.position + const Duration(seconds: 10);
                controller.seekTo(newPos > value.duration
                    ? value.duration
                    : newPos);
              },
            ),
          ],
        );
      },
    );
  }
}
