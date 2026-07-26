import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/app_notification.dart';

/// Provider do plano de treino de hoje (se existir).
final todayWorkoutPlanProvider = FutureProvider.family<WorkoutDay?, String>(
  (ref, userId) async {
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    final plans = await workoutRepo.getAllPlans(userId);
    if (plans.isEmpty) return null;

    final weekday = DateTime.now().weekday - 1;
    final diaSemana = AppStrings.daysOfWeek[weekday];

    // Procura um treino para hoje em qualquer plano
    for (final plan in plans) {
      final workout = plan.getWorkoutForDay(diaSemana);
      if (workout != null && workout.exercicios.isNotEmpty) {
        return workout;
      }
    }
    return null;
  },
);

/// Provider do histórico semanal (últimos 7 dias).
final weeklyHistoryProvider = FutureProvider.family<List<DiaryModel>, String>(
  (ref, userId) async {
    final diaryRepo = ref.watch(diaryRepositoryProvider);
    final history = await diaryRepo.getHistory(userId, limit: 7);
    // Ordena mais antigo primeiro
    history.sort((a, b) => a.data.compareTo(b.data));
    return history;
  },
);

final todayDateProvider = Provider<String>((ref) {
  return DateFormat(AppConstants.dateFormat).format(DateTime.now());
});

final todayDiaryProvider = StreamProvider.family<DiaryModel?, String>(
  (ref, userId) {
    final repo = ref.watch(diaryRepositoryProvider);
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    return repo.diaryEntryStream(userId, today);
  },
);

final ensureDiaryProvider = FutureProvider.family<void, String>(
  (ref, userId) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    return ref.read(diaryRepositoryProvider).ensureDiaryExists(userId, today);
  },
);

/// Dashboard do aluno — Kinetic Dark + Glassmorphism (Stitch).
class AlunoHomeScreen extends ConsumerStatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  ConsumerState<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends ConsumerState<AlunoHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.user?.uid ?? '';
      if (userId.isNotEmpty) ref.read(ensureDiaryProvider(userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(connectivityStreamProvider).value ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          OfflineBanner(isOffline: isOffline),
          Expanded(child: _buildDiaryContent(isOffline)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final authState = ref.watch(authProvider);
    final nome = authState.user?.nome ?? 'Aluno';
    final foto = authState.user?.fotoPerfil;

    return AppBar(
      backgroundColor: AppColors.surfaceLow.withValues(alpha: 0.8),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryFixed.withValues(alpha: 0.3), width: 2),
                shape: BoxShape.circle,
              ),
              child: foto != null
                  ? Image.network(foto, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                        style: GoogleFonts.montserrat(
                          color: AppColors.primaryFixed,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bem-vindo de volta,',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              Text(
                'Olá, $nome!',
                style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onSurface, height: 1.2),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.primaryFixed, size: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDiaryContent(bool isOffline) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final todayDiary = ref.watch(todayDiaryProvider(userId));
    return todayDiary.when(
      data: (diary) => diary == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildDashboard(userId, diary, isOffline),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erro ao carregar dados', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ElevatedButton(
              onPressed: () => ref.invalidate(todayDiaryProvider(userId)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(String userId, DiaryModel diary, bool isOffline) {
    final waterPct = (diary.agua / AppConstants.dailyWaterGoalMl).clamp(0.0, 1.0);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayDiaryProvider(userId));
        ref.invalidate(weeklyHistoryProvider(userId));
        ref.invalidate(todayWorkoutPlanProvider(userId));
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // ── Hero Session Card ────────────────────────────
            _buildHeroCard(userId),
            const SizedBox(height: 16),

            // ── Bento Grid Stats ─────────────────────────────
            _buildBentoGrid(diary, waterPct, isOffline, userId),
            const SizedBox(height: 20),

            // ── Weekly Activity Bars ─────────────────────────
            _buildWeeklyActivity(userId),
            const SizedBox(height: 20),

            // ── Nutrition Brief ──────────────────────────────
            _buildNutritionBrief(diary),
            const SizedBox(height: 20),

            // ── Rating + Workout done ────────────────────────
            _buildBottomSection(userId, diary),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO SESSION CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroCard(String userId) {
    final workoutAsync = ref.watch(todayWorkoutPlanProvider(userId));

    return workoutAsync.when(
      data: (todayWorkout) {
        final hasWorkout = todayWorkout != null && todayWorkout.exercicios.isNotEmpty;
        final workoutName = hasWorkout
            ? todayWorkout!.foco.isNotEmpty
                ? todayWorkout.foco.toUpperCase()
                : 'TREINO DE HOJE'
            : null;
        final exerciseCount = hasWorkout ? todayWorkout!.exercicios.length : 0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: hasWorkout ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
                      width: 4,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (hasWorkout ? AppColors.primaryFixed : AppColors.onSurfaceVariant).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (hasWorkout ? AppColors.primaryFixed : AppColors.onSurfaceVariant).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'HOJE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: hasWorkout ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          hasWorkout ? Icons.fitness_center : Icons.self_improvement,
                          color: (hasWorkout ? AppColors.primaryFixed : AppColors.onSurfaceVariant).withValues(alpha: 0.3),
                          size: 60,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasWorkout ? workoutName! : 'DIA DE DESCANSO',
                      style: GoogleFonts.montserrat(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.02,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasWorkout
                          ? '$exerciseCount exercícios • Foco em ${todayWorkout!.foco.isNotEmpty ? todayWorkout.foco.toLowerCase() : 'força'}.'
                          : 'Aproveita para alongar e recuperar.',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (hasWorkout)
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(
                              'INICIAR TREINO',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.03),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryFixed,
                              foregroundColor: AppColors.onPrimaryContainer,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _muscleChip('${todayWorkout!.exercicios.length} ex.'),
                          const SizedBox(width: 6),
                          _muscleChip('${todayWorkout.diaSemana}'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _buildHeroCardSkeleton(),
      error: (_, __) => _buildHeroCardSkeleton(),
    );
  }

  Widget _buildHeroCardSkeleton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _muscleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondaryFixedDim)),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BENTO GRID
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBentoGrid(DiaryModel diary, double waterPct, bool isOffline, String userId) {
    return LayoutBuilder(builder: (_, constraints) {
      final halfW = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _glassStatCard(
            width: halfW,
            icon: Icons.local_fire_department,
            iconColor: AppColors.primaryFixed,
            label: 'CALORIAS',
            value: '${diary.totalCalorias.toStringAsFixed(0)}',
            unit: 'kcal',
            height: 140,
          ),
          _glassStatCard(
            width: halfW,
            icon: Icons.water_drop,
            iconColor: AppColors.primaryFixed,
            label: 'HIDRATAÇÃO',
            value: '${(diary.agua / 1000).toStringAsFixed(1)}',
            unit: '/ ${(AppConstants.dailyWaterGoalMl / 1000).toStringAsFixed(0)}L',
            progress: waterPct,
            height: 140,
            onTap: isOffline ? null : () => _addWater(userId),
          ),
          _glassStatCard(
            width: constraints.maxWidth,
            icon: Icons.timer,
            iconColor: AppColors.primaryFixed,
            label: 'TEMPO EM ATIVIDADE',
            value: '48',
            unit: 'minutos',
            subtitle: '+12% vs ontem',
            height: 100,
          ),
        ],
      );
    });
  }

  Widget _glassStatCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    double? progress,
    String? subtitle,
    double height = 140,
    VoidCallback? onTap,
  }) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const Spacer(),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: iconColor)),
                  ],
                )
              else
                Icon(icon, color: iconColor, size: 22),
              const Spacer(),
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 0.05)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit, style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondaryFixedDim)),
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primaryFixed),
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  // ═══════════════════════════════════════════════════════════════
  // WEEKLY ACTIVITY BARS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWeeklyActivity(String userId) {
    final historyAsync = ref.watch(weeklyHistoryProvider(userId));
    final labels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final today = DateTime.now().weekday - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Atividade Semanal',
                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.bar_chart, color: AppColors.onSurfaceVariant, size: 20),
                ],
              ),
              const SizedBox(height: 20),
              historyAsync.when(
                data: (history) {
                  // Map diary entries to day buckets (0=Mon..6=Sun)
                  final calPerDay = List.filled(7, 0.0);
                  final now = DateTime.now();
                  final weekStart = now.subtract(Duration(days: now.weekday - 1));

                  for (final entry in history) {
                    try {
                      final date = DateTime.parse(entry.data);
                      final diff = date.difference(weekStart).inDays;
                      if (diff >= 0 && diff < 7) {
                        calPerDay[diff] += entry.totalCalorias;
                      }
                    } catch (_) {}
                  }

                  final maxCal = calPerDay.isEmpty
                      ? 1.0
                      : calPerDay.reduce((a, b) => a > b ? a : b).clamp(1.0, 5000.0);

                  return SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final isToday = i == today;
                        final h = (calPerDay[i] / maxCal).clamp(0.04, 1.0);
                        final cals = calPerDay[i];
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (cals > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${cals.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                        color: isToday ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                FractionallySizedBox(
                                  heightFactor: h,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    decoration: BoxDecoration(
                                      color: isToday ? AppColors.primaryFixed : AppColors.surfaceHighest,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                      boxShadow: isToday
                                          ? [BoxShadow(color: AppColors.primaryFixed.withValues(alpha: 0.4), blurRadius: 12)]
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  labels[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                    color: isToday ? AppColors.primaryFixed : AppColors.secondaryFixedDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (_, __) => SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Sem dados da semana',
                      style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NUTRITION BRIEF
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNutritionBrief(DiaryModel diary) {
    final lastMeal = diary.refeicoes.isNotEmpty ? diary.refeicoes.last : null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _nutritionCard(
              icon: Icons.restaurant,
              title: lastMeal != null ? 'Última Refeição' : 'Sem refeições',
              subtitle: lastMeal?.descricao ?? 'Regista a tua primeira refeição',
            )),
            const SizedBox(width: 12),
            Expanded(child: _nutritionCard(
              icon: Icons.insights,
              title: 'Meta de Proteína',
              subtitle: '${diary.totalCalorias > 0 ? (diary.totalCalorias * 0.3 / 4).toStringAsFixed(0) : 0}g / 180g atingidos',
              progress: diary.totalCalorias > 0 ? ((diary.totalCalorias * 0.3 / 4) / 180).clamp(0.0, 1.0) : 0.0,
            )),
          ],
        ),
        const SizedBox(height: 12),
        _glassSection(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant, color: AppColors.calories, size: 18),
                  const SizedBox(width: 8),
                  Text(AppStrings.mealsTitle, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  const Spacer(),
                  Text('${diary.totalCalorias.toStringAsFixed(0)} kcal',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.calories, fontSize: 15)),
                ],
              ),
              if (diary.refeicoes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(color: AppColors.outline),
                const SizedBox(height: 8),
                ...diary.refeicoes.take(2).map((meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(4)),
                            child: Text(meal.tipo, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(meal.descricao, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                          Text('${meal.calorias.toStringAsFixed(0)} kcal', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _nutritionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    double? progress,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primaryFixed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              if (progress != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 40, height: 40,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: AppColors.surfaceHighest,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryFixed),
                        ),
                      ),
                      Text('${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primaryFixed)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM SECTION: Rating & Workout
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomSection(String userId, DiaryModel diary) {
    return _glassSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(AppStrings.dayRating, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 10),
          StarRating(rating: diary.avaliacao, onChanged: (rating) => _setRating(userId, rating)),
        ],
      ),
    );
  }

  Widget _glassSection({required EdgeInsets padding, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _addWater(String userId) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref.read(diaryRepositoryProvider).addWater(userId, today, AppConstants.waterIncrementMl);
    } catch (_) {
      if (mounted) showAppNotification(context, AppStrings.networkError, type: NotificationType.error);
    }
  }

  Future<void> _setRating(String userId, int rating) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref.read(diaryRepositoryProvider).setRating(userId, today, rating);
    } catch (_) {}
  }
}
