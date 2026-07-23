import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/circular_progress_widget.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/offline_banner.dart';

/// Provider para a data de hoje formatada.
final todayDateProvider = Provider<String>((ref) {
  return DateFormat(AppConstants.dateFormat).format(DateTime.now());
});

/// Provider do diário do dia.
final todayDiaryProvider = StreamProvider.family<DiaryModel?, String>(
  (ref, userId) {
    final repo = ref.watch(diaryRepositoryProvider);
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    return repo.diaryEntryStream(userId, today);
  },
);

/// Provider que garante que o diário existe.
final ensureDiaryProvider = FutureProvider.family<void, String>(
  (ref, userId) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    return ref.read(diaryRepositoryProvider).ensureDiaryExists(userId, today);
  },
);

/// Ecrã principal do aluno (Dashboard).
class AlunoHomeScreen extends ConsumerStatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  ConsumerState<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends ConsumerState<AlunoHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Garantir que o diário existe após o build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.user?.uid ?? '';
      if (userId.isNotEmpty) {
        ref.read(ensureDiaryProvider(userId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(connectivityStreamProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(isOffline: isOffline),
          Expanded(
            child: _buildDiaryContent(isOffline),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryContent(bool isOffline) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final todayDiary = ref.watch(todayDiaryProvider(userId));

    return todayDiary.when(
      data: (diary) {
        if (diary == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildDashboard(userId, diary, isOffline);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Erro ao carregar dados'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(todayDiaryProvider(userId)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
      String userId, DiaryModel diary, bool isOffline) {
    final waterProgress = diary.agua / AppConstants.dailyWaterGoalMl;
    final stepsProgress = diary.passos / AppConstants.dailyStepsGoal;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayDiaryProvider(userId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saudação
            _buildGreeting(),
            const SizedBox(height: 20),

            // Água e Passos lado a lado
            Row(
              children: [
                Expanded(
                  child: CircularProgressWidget(
                    value: waterProgress.clamp(0.0, 1.0),
                    label: AppStrings.waterTitle,
                    currentValue: '${diary.agua}',
                    goalValue: 'Meta: ${AppConstants.dailyWaterGoalMl}',
                    unit: 'ml',
                    color: AppColors.water,
                    backgroundColor: AppColors.waterLight,
                    icon: Icons.water_drop,
                    onIncrement: isOffline
                        ? null
                        : () => _addWater(userId),
                    incrementLabel: AppStrings.addWater,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CircularProgressWidget(
                    value: stepsProgress.clamp(0.0, 1.0),
                    label: AppStrings.stepsTitle,
                    currentValue: '${diary.passos}',
                    goalValue: 'Meta: ${AppConstants.dailyStepsGoal}',
                    unit: '',
                    color: AppColors.steps,
                    backgroundColor: AppColors.stepsLight,
                    icon: Icons.directions_walk,
                    onIncrement: () =>
                        _addStepsManually(userId, diary.passos),
                    incrementLabel: 'Adicionar',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Refeições do dia
            _buildMealsSection(diary),
            const SizedBox(height: 24),

            // Avaliação do dia
            _buildRatingSection(userId, diary),
            const SizedBox(height: 24),

            // Botão para treino concluído
            if (diary.treinoConcluido)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 12),
                    Text(
                      'Treino de hoje concluído! 💪',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final authState = ref.watch(authProvider);
    final nome = authState.user?.nome ?? 'Aluno';
    return Text(
      'Olá, $nome! 👋',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
    );
  }

  Widget _buildMealsSection(DiaryModel diary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: AppColors.calories),
              const SizedBox(width: 8),
              Text(
                AppStrings.mealsTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${diary.totalCalorias.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.calories,
                ),
              ),
            ],
          ),
          if (diary.refeicoes.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nenhuma refeição registada hoje.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...diary.refeicoes.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.caloriesLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          meal.tipo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.calories,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meal.descricao,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${meal.calorias.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection(String userId, DiaryModel diary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            AppStrings.dayRating,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          StarRating(
            rating: diary.avaliacao,
            onChanged: (rating) => _setRating(userId, rating),
          ),
        ],
      ),
    );
  }

  Future<void> _addWater(String userId) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref
          .read(diaryRepositoryProvider)
          .addWater(userId, today, AppConstants.waterIncrementMl);
    } catch (e) {
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

  Future<void> _addStepsManually(String userId, int currentSteps) async {
    final controller = TextEditingController(text: '$currentSteps');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passos do dia'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Número de passos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(controller.text);
              Navigator.pop(ctx, steps);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result != null) {
      final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
      try {
        await ref
            .read(diaryRepositoryProvider)
            .setSteps(userId, today, result);
      } catch (_) {}
    }
  }

  Future<void> _setRating(String userId, int rating) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref
          .read(diaryRepositoryProvider)
          .setRating(userId, today, rating);
    } catch (_) {}
  }
}
