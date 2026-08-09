import 'dart:async';
import 'package:flutter/foundation.dart';
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

final todayWorkoutDiaryProvider = StreamProvider.family<DiaryModel?, String>((
  ref,
  userId,
) {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(diaryRepositoryProvider).diaryEntryStream(userId, today);
});

final todayWorkoutLogProvider = FutureProvider.family<WorkoutLogModel?, String>(
  (ref, userId) {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    return ref.read(workoutLogRepositoryProvider).getLog(userId, today);
  },
);

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
  bool _saveQueued = false;
  Future<void>? _saveInFlight;
  bool _initialized = false;
  String? _selectedWorkoutDay;
  bool _showPlanDetails = false;
  int? _expandedPlanIndex;
  final Map<String, bool> _expandedExercises = {};

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
    String exNome,
    int serieNum,
    String field,
    String? initialValue,
  ) {
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
      subPlanoId: todayWorkout.subPlanoId,
      foco: todayWorkout.foco,
      exercicios: todayWorkout.exercicios.map((e) {
        return ExerciseLog.fromExercise(e.nome, e.series, e.grupoMuscular);
      }).toList(),
    );
  }

  void _restoreFromLog(WorkoutLogModel log) {
    _initialized = true;
    _activeLog = log;
  }

  Future<void> _saveLog({bool readOnly = false}) async {
    if (readOnly || _activeLog == null) return;

    // A escrita da primeira tecla pode ainda estar em curso quando o aluno
    // introduz a segunda. Em vez de ignorar essa alteração enquanto `_saving`
    // está true, agenda uma nova escrita com o estado mais recente.
    if (_saving) {
      _saveQueued = true;
      await _saveInFlight;
      return;
    }

    _saving = true;
    final saveCompleter = Completer<void>();
    _saveInFlight = saveCompleter.future;
    try {
      do {
        _saveQueued = false;
        final log = _activeLog;
        if (log == null) break;

        final userId = ref.read(authProvider).user?.uid ?? '';
        final dateKey = DateFormat(
          AppConstants.workoutLogDateFormat,
        ).format(log.data);
        try {
          await ref
              .read(workoutLogRepositoryProvider)
              .saveLog(userId, dateKey, log.toMap());
        } catch (_) {
          // Silently fail auto-save; the next edit will retry the latest state.
        }
      } while (_saveQueued && mounted);
    } finally {
      _saving = false;
      _saveInFlight = null;
      saveCompleter.complete();
    }
  }

  void _toggleSerie(
    ExerciseLog exercise,
    int serieIdx, {
    bool readOnly = false,
  }) {
    if (readOnly) return;
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
    _saveLog(readOnly: readOnly);
  }

  void _updateSerieData(
    ExerciseLog exercise,
    int serieIdx,
    String field,
    String value, {
    bool readOnly = false,
  }) {
    if (readOnly) return;
    final numValue = double.tryParse(value.replaceAll(',', '.'));
    setState(() {
      final updatedSeries = exercise.series.toList();
      final s = updatedSeries[serieIdx];
      if (field == 'carga') {
        updatedSeries[serieIdx] = s.copyWith(
          carga: numValue,
          clearCarga: value.isEmpty,
        );
      } else {
        final reps = int.tryParse(value);
        updatedSeries[serieIdx] = s.copyWith(
          repeticoes: reps,
          clearRepeticoes: value.isEmpty,
        );
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
    _saveLog(readOnly: readOnly);
  }

  void _startRestTimer(
    int seconds,
    String exerciseName, {
    String mode = 'DESCANSO',
  }) {
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

  Future<void> _completeWorkout({bool readOnly = false}) async {
    if (readOnly) return;
    final userId = ref.read(authProvider).user?.uid ?? '';
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    final dateKey = DateFormat(
      AppConstants.workoutLogDateFormat,
    ).format(DateTime.now());

    try {
      // Aguarda uma edição/remoção que ainda esteja a ser persistida para que
      // a escrita final não seja ultrapassada por um autosave antigo.
      await _saveLog();

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
        showAppNotification(
          context,
          'Treino concluído! 💪🔥',
          type: NotificationType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          AppStrings.networkError,
          type: NotificationType.error,
        );
      }
    }
  }

  void _showVideoPlayer(String url, String exerciseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        final dateStr = DateFormat(
                          'dd/MM/yyyy',
                        ).format(log.data);
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
                            style: GoogleFonts.inter(
                              color: AppColors.onSurface,
                            ),
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
      body: Column(
        children: [
          if (!(_showPlanDetails && _selectedWorkoutDay != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _showWorkoutHistory(userId),
                  icon: const Icon(Icons.history),
                  tooltip: AppStrings.workoutHistory,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fitness_center,
                    title: AppStrings.noWorkoutAssigned,
                  );
                }
                return _buildStudentPlansOverview(plans, userId, isMobile);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Não foi possível carregar o treino',
                subtitle: _friendlyWorkoutError(error),
                actionLabel: 'Tentar novamente',
                onAction: () => ref.invalidate(workoutPlansProvider(userId)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPlansOverview(
    List<WorkoutPlanModel> plans,
    String userId,
    bool isMobile,
  ) {
    final plan = plans[_selectedPlanIndex.clamp(0, plans.length - 1)];
    final assignedPlans = plans
        .where((item) => item.dias.any((day) => day.exercicios.isNotEmpty))
        .toList();

    if (_showPlanDetails) {
      return _buildStudentPlanDetails(plan, userId, isMobile);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 14 : 24,
        14,
        isMobile ? 14 : 24,
        28,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planos atribuídos',
                      style: GoogleFonts.inter(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignedPlans.isEmpty
                          ? 'Ainda não tens planos atribuídos'
                          : '${assignedPlans.length} plano(s) disponível(is) · seleciona um plano abaixo',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Os teus planos',
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (assignedPlans.isEmpty)
          _buildRestDay()
        else
          ...assignedPlans.asMap().entries.map((entry) {
            final item = entry.value;
            final totalExercises = item.dias.fold<int>(
              0,
              (sum, day) => sum + day.exercicios.length,
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() {
                        final planIndex = plans.indexOf(item);
                        _expandedPlanIndex = _expandedPlanIndex == planIndex
                            ? null
                            : planIndex;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.surfaceHigh,
                              child: Text(
                                String.fromCharCode(65 + entry.key),
                                style: GoogleFonts.inter(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nome,
                                    style: GoogleFonts.inter(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${item.dias.where((day) => day.exercicios.isNotEmpty).length} treinos · $totalExercises exercícios',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _expandedPlanIndex == plans.indexOf(item)
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expandedPlanIndex == plans.indexOf(item)
                      ? Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Sub-planos deste plano',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ...item.dias
                                  .where((day) => day.exercicios.isNotEmpty)
                                  .map(
                                    (day) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => setState(() {
                                            _selectedPlanIndex = plans.indexOf(
                                              item,
                                            );
                                            _selectedWorkoutDay =
                                                day.subPlanoId.isEmpty
                                                ? day.diaSemana
                                                : day.subPlanoId;
                                            _showPlanDetails = true;
                                            _expandedPlanIndex = null;
                                            _activeLog = null;
                                            _initialized = false;
                                            _expandedExercises.clear();
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 11,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.fitness_center,
                                                    color: AppColors.primary,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        day.displayName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.inter(
                                                              color: AppColors
                                                                  .onSurface,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '${day.diaSemana.isEmpty ? 'Sem dia definido' : day.diaSemana} · ${day.exercicios.length} exercícios',
                                                        style: GoogleFonts.inter(
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color:
                                                      AppColors.textSecondary,
                                                  size: 14,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }),
      ],
    );
  }

  String _weekdayKey(String value) {
    var key = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      key = key.replaceAll(entry.key, entry.value);
    }
    key = key.replaceAll(RegExp(r'[-_\\s]+'), '');
    if (key.endsWith('feira')) key = key.substring(0, key.length - 5);

    // Aceita também abreviaturas que podem existir em planos antigos.
    const aliases = {
      'seg': 'segunda',
      'ter': 'terca',
      'qua': 'quarta',
      'qui': 'quinta',
      'sex': 'sexta',
      'sab': 'sabado',
      'dom': 'domingo',
    };
    return aliases[key] ?? key;
  }

  Exercise? _plannedExerciseForLog(
    WorkoutDay workout,
    ExerciseLog exerciseLog,
  ) {
    for (final exercise in workout.exercicios) {
      if (exercise.nome == exerciseLog.nome) return exercise;
    }
    // Do not use the list index as identity: exercises can be removed or
    // reordered after an old log was created.
    return null;
  }

  Widget _buildStudentPlanDetails(
    WorkoutPlanModel plan,
    String userId,
    bool isMobile,
  ) {
    final today = AppStrings.daysOfWeek[DateTime.now().weekday - 1];
    final days = plan.dias.where((day) => day.exercicios.isNotEmpty).toList();
    WorkoutDay? selectedDay;
    for (final day in days) {
      final dayKey = day.subPlanoId.isEmpty ? day.diaSemana : day.subPlanoId;
      if (dayKey == _selectedWorkoutDay) {
        selectedDay = day;
        break;
      }
    }

    if (selectedDay != null) {
      final isToday = _weekdayKey(selectedDay.diaSemana) == _weekdayKey(today);
      final readOnly = !isToday;
      return Column(
        children: [
          Expanded(
            child: _buildExecutionView(
              selectedDay,
              plan,
              userId,
              isMobile,
              readOnly: readOnly,
              onBack: () {
                setState(() {
                  _selectedWorkoutDay = null;
                  _activeLog = null;
                  _initialized = false;
                  _expandedExercises.clear();
                });
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _studentSubHeader(
          plan.nome,
          'Escolhe um treino',
          onBack: () {
            setState(() => _showPlanDetails = false);
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              Text(
                'Treinos disponíveis',
                style: GoogleFonts.inter(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ...days.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        _selectedWorkoutDay = day.subPlanoId.isEmpty
                            ? day.diaSemana
                            : day.subPlanoId;
                        _activeLog = null;
                        _initialized = false;
                        _expandedExercises.clear();
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.14,
                              ),
                              child: const Icon(
                                Icons.fitness_center,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.displayName,
                                    style: GoogleFonts.inter(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${day.diaSemana.isEmpty ? 'Sem dia definido' : day.diaSemana} · ${day.exercicios.length} exercícios${day.foco.isEmpty ? '' : ' · ${day.foco}'}',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _studentSubHeader(
    String planName,
    String subtitle, {
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.onSurface,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  '00:00:00',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExecutionContext(
    WorkoutDay workout, {
    VoidCallback? onBack,
    bool readOnly = false,
  }) {
    final now = DateTime.now();
    final weekday = DateFormat('EEEE', 'pt').format(now);
    final date = DateFormat('d MMMM yyyy', 'pt').format(now);
    return [
      Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            ),
          Expanded(
            child: Text(
              workout.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  workout.foco.isEmpty ? 'TREINO' : workout.foco.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surface),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekday[0].toUpperCase() + weekday.substring(1),
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: GoogleFonts.montserrat(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    readOnly ? 'Dia alternativo' : 'Hoje',
                    style: GoogleFonts.inter(
                      color: readOnly
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'WORKOUT',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  String _friendlyWorkoutError(Object error) {
    if (kDebugMode) debugPrint('Workout loading error: $error');
    final message = error.toString().toLowerCase();
    if (message.contains('permission-denied') ||
        message.contains('permission denied')) {
      return 'Não tens permissão para consultar este plano. Confirma a conta do aluno.';
    }
    if (message.contains('network') || message.contains('unavailable')) {
      return 'Verifica a ligação à internet e tenta novamente.';
    }
    return 'Verifica a ligação à internet ou pede ao administrador para confirmar o plano.';
  }

  Widget _buildWorkoutPreview(WorkoutDay workout) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Consulta do treino',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${workout.displayName}${workout.diaSemana.isEmpty ? '' : ' · ${workout.diaSemana}'}${workout.foco.isEmpty ? '' : ' · ${workout.foco}'}',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            'Este é um dia alternativo do plano. A execução e o registo ficam disponíveis no dia agendado.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...workout.exercicios.asMap().entries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    '${entry.key + 1}',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.nome,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _previewMetric(
                            Icons.repeat,
                            '${entry.value.series} séries',
                          ),
                          _previewMetric(
                            Icons.format_list_numbered,
                            '${entry.value.repeticoes} repetições',
                          ),
                          _previewMetric(
                            Icons.timer_outlined,
                            '${entry.value.descanso}s descanso',
                          ),
                          if (entry.value.cargaSugerida != null)
                            _previewMetric(
                              Icons.fitness_center,
                              '${entry.value.cargaSugerida} kg',
                            ),
                          if (entry.value.duracao != null)
                            _previewMetric(
                              Icons.schedule,
                              '${entry.value.duracao}s',
                            ),
                          if (entry.value.rounds != null)
                            _previewMetric(
                              Icons.loop,
                              '${entry.value.rounds} rounds',
                            ),
                        ],
                      ),
                      if (entry.value.observacoes != null &&
                          entry.value.observacoes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          entry.value.observacoes!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternateDayNotice(WorkoutDay workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Este é um dia alternativo do plano. Podes consultar todos os exercícios, mas a execução e o registo ficam disponíveis no dia agendado.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewMetric(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    WorkoutDay todayWorkout,
    WorkoutPlanModel plan,
    String userId,
    bool isMobile, {
    VoidCallback? onBack,
    bool readOnly = false,
  }) {
    // Um dia alternativo é apenas consulta: não depende do registo de hoje
    // nem pode restaurar/sobrescrever o treino que está agendado para hoje.
    final AsyncValue<WorkoutLogModel?> logAsync = readOnly
        ? const AsyncData<WorkoutLogModel?>(null)
        : ref.watch(todayWorkoutLogProvider(userId));

    return logAsync.when(
      data: (existingLog) {
        final samePlan = existingLog?.planoSemana == plan.nome;
        final sameSubPlan = existingLog?.subPlanoId == todayWorkout.subPlanoId;
        final legacyLogIsUnambiguous =
            existingLog?.subPlanoId == null &&
            plan.dias
                    .where(
                      (day) =>
                          _weekdayKey(day.diaSemana) ==
                          _weekdayKey(todayWorkout.diaSemana),
                    )
                    .length ==
                1;
        if (!readOnly &&
            existingLog != null &&
            !_initialized &&
            samePlan &&
            (sameSubPlan || legacyLogIsUnambiguous)) {
          _restoreFromLog(existingLog);
        } else if (!_initialized) {
          _initFromPlan(todayWorkout, plan);
        }

        if (_activeLog == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final progress = _activeLog!.progresso;
        final seriesDone = _activeLog!.seriesConcluidas;
        final seriesTotal = _activeLog!.seriesTotais;

        return Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20,
                10,
                isMobile ? 12 : 20,
                isMobile ? 100 : 120,
              ),
              children: [
                ..._buildExecutionContext(
                  todayWorkout,
                  onBack: onBack,
                  readOnly: readOnly,
                ),
                if (readOnly) _buildAlternateDayNotice(todayWorkout),
                ..._activeLog!.exercicios.asMap().entries.map((entry) {
                  final exerciseLog = entry.value;
                  final plannedExercise = _plannedExerciseForLog(
                    todayWorkout,
                    exerciseLog,
                  );
                  return _buildReferenceExerciseCard(
                    exerciseLog,
                    plannedExercise ??
                        Exercise(
                          nome: exerciseLog.nome,
                          series: exerciseLog.totalSeries,
                          repeticoes: 0,
                        ),
                    isMobile,
                    readOnly: readOnly,
                    exerciseKey: '${entry.key}_${exerciseLog.nome}',
                  );
                }),
              ],
            ),
            // Rest timer overlay
            if (_isResting && !readOnly) _buildRestTimerOverlay(),
            // Mantém a mesma estrutura visual, mas sem qualquer ação de registo.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(
                progress,
                seriesDone,
                seriesTotal,
                readOnly: readOnly,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                'Não foi possível carregar o registo do treino',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _friendlyWorkoutError(error),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(todayWorkoutLogProvider(userId)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleExerciseExpanded(String exerciseKey) {
    setState(() {
      final current = _expandedExercises[exerciseKey] ?? true;
      _expandedExercises[exerciseKey] = !current;
    });
  }

  Future<bool> _confirmRemoveSerie(SerieLog serie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar série?'),
        content: Text(
          'A série S${serie.numero} adicionada manualmente será eliminada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _removeSerie(
    ExerciseLog exercise,
    int serieIdx, {
    bool readOnly = false,
    bool confirmed = false,
  }) async {
    if (readOnly || serieIdx < 0 || serieIdx >= exercise.series.length) return;
    final serie = exercise.series[serieIdx];
    if (!serie.adicionadaManualmente) return;
    if (!confirmed && !await _confirmRemoveSerie(serie)) return;
    if (!mounted) return;

    final activeLog = _activeLog;
    if (activeLog == null) return;
    final updatedExercises = activeLog.exercicios.toList();
    final exIdx = updatedExercises.indexOf(exercise);
    if (exIdx < 0) return;
    final updatedSeries = exercise.series.toList()..removeAt(serieIdx);
    updatedExercises[exIdx] = ExerciseLog(
      nome: exercise.nome,
      grupoMuscular: exercise.grupoMuscular,
      series: updatedSeries,
    );
    setState(() {
      _activeLog = activeLog.copyWith(exercicios: updatedExercises);
    });

    final cargaController = _cargaControllers.remove(
      _seriesKey(exercise.nome, serie.numero, 'carga'),
    );
    final repController = _repControllers.remove(
      _seriesKey(exercise.nome, serie.numero, 'rep'),
    );
    cargaController?.dispose();
    repController?.dispose();

    await _saveLog();
  }

  void _addSerie(ExerciseLog exercise, {bool readOnly = false}) {
    if (readOnly) return;
    final updatedExercises = _activeLog!.exercicios.toList();
    final exIdx = updatedExercises.indexOf(exercise);
    final nextNumber = exercise.series.isEmpty
        ? 1
        : exercise.series
                  .map((serie) => serie.numero)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    updatedExercises[exIdx] = ExerciseLog(
      nome: exercise.nome,
      grupoMuscular: exercise.grupoMuscular,
      series: [
        ...exercise.series,
        SerieLog(numero: nextNumber, adicionadaManualmente: true),
      ],
    );
    setState(() {
      _activeLog = _activeLog!.copyWith(exercicios: updatedExercises);
    });
    _saveLog();
  }

  Widget _buildReferenceExerciseCard(
    ExerciseLog exerciseLog,
    Exercise plannedExercise,
    bool isMobile, {
    required String exerciseKey,
    bool readOnly = false,
  }) {
    final allDone = exerciseLog.todasConcluidas;
    final isFuncional =
        plannedExercise.categoria == 'funcional' ||
        plannedExercise.categoria == 'cardio' ||
        plannedExercise.duracao != null;
    final expanded = _expandedExercises[exerciseKey] ?? !allDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.55)
              : AppColors.outline,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExerciseExpanded(exerciseKey),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      _buildExerciseMediaPreview(
                        plannedExercise,
                        completed: allDone,
                      ),
                      if (plannedExercise.videoURL?.trim().isNotEmpty == true)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest.withValues(
                                alpha: 0.82,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VIDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exerciseLog.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _referenceMetricBox(
                    '${exerciseLog.totalSeries}',
                    'séries',
                    AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _referenceMetricBox(
                    '${plannedExercise.descanso}s',
                    'descanso',
                    AppColors.info,
                    onTap: readOnly
                        ? null
                        : () => _startRestTimer(
                            plannedExercise.descanso,
                            plannedExercise.nome,
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFuncional
                      ? _funcionalSubtitle(plannedExercise, exerciseLog)
                      : '${plannedExercise.repeticoes}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (isFuncional && plannedExercise.duracao != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: readOnly
                        ? null
                        : () => _startRestTimer(
                            plannedExercise.duracao!,
                            plannedExercise.nome,
                            mode: 'EXERCÍCIO',
                          ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      'Iniciar ${plannedExercise.duracao}s',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.surfaceHighest.withValues(
                        alpha: 0.42,
                      ),
                      side: const BorderSide(color: Colors.transparent),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
            if (isFuncional)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildFuncionalCard(
                  exerciseLog,
                  plannedExercise,
                  readOnly: readOnly,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    _buildSeriesProgressSummary(exerciseLog),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: isMobile ? 36 : 42,
                            child: _referenceLabel('SÉRIE'),
                          ),
                          Expanded(child: _referenceLabel('REPS')),
                          const SizedBox(width: 8),
                          Expanded(child: _referenceLabel('CARGA (KG)')),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    ...exerciseLog.series.asMap().entries.map((entry) {
                      final serieIdx = entry.key;
                      final serie = entry.value;
                      final cargaCtrl = _getController(
                        exerciseLog.nome,
                        serie.numero,
                        'carga',
                        serie.carga?.toString(),
                      );
                      final repCtrl = _getController(
                        exerciseLog.nome,
                        serie.numero,
                        'rep',
                        serie.repeticoes?.toString(),
                      );
                      return Dismissible(
                        key: ValueKey(
                          '${exerciseKey}_serie_${serie.numero}',
                        ),
                        direction: serie.adicionadaManualmente && !readOnly
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.only(right: 18),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Eliminar',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        confirmDismiss: (_) async {
                          if (!serie.adicionadaManualmente || readOnly) {
                            return false;
                          }
                          return _confirmRemoveSerie(serie);
                        },
                        onDismissed: (_) => _removeSerie(
                          exerciseLog,
                          serieIdx,
                          readOnly: readOnly,
                          confirmed: true,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 36 : 42,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: serie.concluida
                                      ? AppColors.success.withValues(
                                          alpha: 0.16,
                                        )
                                      : AppColors.surfaceHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: serie.concluida
                                        ? AppColors.success
                                        : AppColors.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  'S${serie.numero}',
                                  style: GoogleFonts.inter(
                                    color: serie.concluida
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _referenceInput(
                                  controller: repCtrl,
                                  label: 'Repetições',
                                  keyboardType: TextInputType.number,
                                  readOnly: readOnly,
                                  onChanged: (value) => _updateSerieData(
                                    exerciseLog,
                                    serieIdx,
                                    'rep',
                                    value,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _referenceInput(
                                  controller: cargaCtrl,
                                  label: 'Carga',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  readOnly: readOnly,
                                  onChanged: (value) => _updateSerieData(
                                    exerciseLog,
                                    serieIdx,
                                    'carga',
                                    value,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: readOnly
                                    ? null
                                    : () => _toggleSerie(
                                        exerciseLog,
                                        serieIdx,
                                        readOnly: readOnly,
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: serie.concluida
                                        ? AppColors.success
                                        : AppColors.surfaceHigh,
                                    border: Border.all(
                                      color: serie.concluida
                                          ? AppColors.success
                                          : AppColors.outlineVariant,
                                      width: 1.5,
                                    ),
                                    boxShadow: serie.concluida
                                        ? [
                                            BoxShadow(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: serie.concluida
                                      ? const Icon(
                                          Icons.check,
                                          size: 15,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: readOnly
                            ? null
                            : () => _addSerie(exerciseLog, readOnly: readOnly),
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(
                          'Adicionar série',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppColors.surfaceHighest.withValues(
                            alpha: 0.42,
                          ),
                          side: const BorderSide(color: Colors.transparent),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    if (plannedExercise.observacoes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                plannedExercise.observacoes!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
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
        ],
      ),
    );
  }

  Widget _buildSeriesProgressSummary(ExerciseLog exercise) {
    final total = exercise.totalSeries;
    final completed = exercise.seriesConcluidas;
    final progress = total == 0 ? 0.0 : completed / total;
    final finished = total > 0 && completed == total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: finished
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: finished
              ? AppColors.success.withValues(alpha: 0.42)
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finished ? Icons.verified_rounded : Icons.track_changes_rounded,
                size: 17,
                color: finished ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finished ? 'Exercício concluído' : 'Registo das séries',
                  style: GoogleFonts.inter(
                    color: AppColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completed/$total',
                style: GoogleFonts.montserrat(
                  color: finished ? AppColors.success : AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'séries',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation(
                finished ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceMetricBox(
    String value,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final icon = label == 'séries'
        ? Icons.layers_outlined
        : Icons.timer_outlined;
    final child = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.montserrat(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return onTap == null
        ? child
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(5),
              child: child,
            ),
          );
  }

  Widget _referenceLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _referenceInput({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
    bool readOnly = false,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          color: AppColors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '—',
          hintStyle: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.fromLTRB(8, 10, 8, 5),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
        onChanged: onChanged,
        onEditingComplete: () {
          // Garante que o último valor introduzido é persistido mesmo quando
          // o aluno fecha o teclado sem alterar outra série.
          _saveLog(readOnly: readOnly);
          FocusManager.instance.primaryFocus?.unfocus();
        },
      ),
    );
  }

  Widget _buildExerciseMediaPreview(
    Exercise exercise, {
    required bool completed,
  }) {
    final videoUrl = exercise.videoURL?.trim();
    return _InlineExercisePreview(
      videoUrl: videoUrl?.isEmpty == true ? null : videoUrl,
      completed: completed,
      onTap: videoUrl?.isNotEmpty == true
          ? () => _showVideoPlayer(videoUrl!, exercise.nome)
          : null,
    );
  }

  String _funcionalSubtitle(Exercise ex, ExerciseLog log) {
    final parts = <String>[];
    if (ex.duracao != null) parts.add('${ex.duracao}s');
    if (ex.rounds != null) parts.add('${ex.rounds} rounds');
    parts.add(
      ex.equipamento == 'corda'
          ? '🪢 Corda'
          : ex.equipamento == 'kettlebell'
          ? '🔔 Kettlebell'
          : '⚡ Funcional',
    );
    return parts.join(' • ');
  }

  Widget _buildFuncionalCard(
    ExerciseLog exerciseLog,
    Exercise exercise, {
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Info row
          Row(
            children: [
              _funcionalInfoChip(
                Icons.timer,
                '${exercise.duracao ?? exercise.descanso}s',
              ),
              const SizedBox(width: 10),
              if (exercise.rounds != null) ...[
                _funcionalInfoChip(Icons.repeat, '${exercise.rounds} rounds'),
                const SizedBox(width: 10),
              ],
              _funcionalInfoChip(
                Icons.fitness_center,
                exercise.equipamento == 'corda'
                    ? 'Corda'
                    : exercise.equipamento == 'kettlebell'
                    ? 'Kettlebell'
                    : 'Funcional',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle complete button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: readOnly
                  ? null
                  : () => _toggleFuncionalComplete(exerciseLog),
              icon: Icon(
                exerciseLog.todasConcluidas
                    ? Icons.check_circle
                    : Icons.play_circle_outline,
                size: 20,
              ),
              label: Text(
                exerciseLog.todasConcluidas
                    ? 'CONCLUÍDO ✅'
                    : 'MARCAR COMO CONCLUÍDO',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: exerciseLog.todasConcluidas
                    ? AppColors.success
                    : AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
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
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _toggleFuncionalComplete(ExerciseLog exercise, {bool readOnly = false}) {
    if (readOnly) return;
    setState(() {
      final updatedExercises = _activeLog!.exercicios.toList();
      final exIdx = updatedExercises.indexOf(exercise);
      // Toggle todas as séries
      final allDone = exercise.todasConcluidas;
      final updatedSeries = exercise.series
          .map((s) => s.copyWith(concluida: !allDone))
          .toList();
      updatedExercises[exIdx] = ExerciseLog(
        nome: exercise.nome,
        grupoMuscular: exercise.grupoMuscular,
        series: updatedSeries,
      );
      _activeLog = _activeLog!.copyWith(exercicios: updatedExercises);
    });
    _saveLog(readOnly: readOnly);
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
                      border: Border.all(color: AppColors.primary, width: 4),
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

  Widget _buildBottomBar(
    double progress,
    int seriesDone,
    int seriesTotal, {
    bool readOnly = false,
  }) {
    final allDone = progress >= 1.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: const Border(top: BorderSide(color: AppColors.outline)),
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
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.outline,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
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
            const SizedBox(height: 8),
            // Complete button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: !readOnly && allDone
                    ? () => _completeWorkout(readOnly: readOnly)
                    : null,
                icon: const Icon(Icons.emoji_events),
                label: Text(
                  allDone ? 'CONCLUIR TREINO! 💪' : 'Completa todas as séries',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: allDone
                      ? AppColors.primary
                      : AppColors.outline,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
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

/// Pré-visualização quadrada do vídeo dentro do cartão do exercício.
/// Mostra o primeiro frame sem iniciar a reprodução automaticamente.
class _InlineExercisePreview extends StatefulWidget {
  final String? videoUrl;
  final bool completed;
  final VoidCallback? onTap;

  const _InlineExercisePreview({
    required this.videoUrl,
    required this.completed,
    required this.onTap,
  });

  @override
  State<_InlineExercisePreview> createState() => _InlineExercisePreviewState();
}

class _InlineExercisePreviewState extends State<_InlineExercisePreview> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _error = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final borderColor = widget.completed
        ? AppColors.success.withValues(alpha: 0.7)
        : AppColors.outlineVariant;
    final ready = controller?.value.isInitialized == true && !_error;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: borderColor),
                ),
                child: ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : Icon(
                        widget.videoUrl == null
                            ? Icons.image_outlined
                            : Icons.play_arrow_rounded,
                        color: widget.completed
                            ? AppColors.success
                            : AppColors.textSecondary,
                        size: widget.videoUrl == null ? 22 : 27,
                      ),
              ),
              if (widget.videoUrl != null)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              if (widget.completed)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
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
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.play();
            }
          })
          .catchError((_) {
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
                  const Icon(
                    Icons.videocam_off,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Não foi possível carregar o vídeo.\nAbre no browser:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
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
                final newPos = value.position - const Duration(seconds: 10);
                controller.seekTo(
                  newPos < Duration.zero ? Duration.zero : newPos,
                );
              },
            ),
            IconButton(
              icon: Icon(
                value.isPlaying ? Icons.pause_circle : Icons.play_circle,
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
                final newPos = value.position + const Duration(seconds: 10);
                controller.seekTo(
                  newPos > value.duration ? value.duration : newPos,
                );
              },
            ),
          ],
        );
      },
    );
  }
}
