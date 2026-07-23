import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/nutrition_plan_model.dart';
import '../../../data/models/workout_plan_model.dart';
import '../../../data/models/progress_model.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../../data/repositories/progress_repository.dart';
import 'global_providers.dart';

/// Provider do plano nutricional do aluno (admin view).
final adminNutritionPlanProvider =
    FutureProvider.family<NutritionPlanModel?, (String, String)>(
  (ref, params) {
    final (userId, diaSemana) = params;
    return ref.read(nutritionRepositoryProvider).getPlan(userId, diaSemana);
  },
);

/// Provider do plano de treino do aluno (admin view).
final adminWorkoutPlansProvider =
    FutureProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).getAllPlans(userId);
});

/// Provider de progresso (admin view).
final adminProgressProvider =
    FutureProvider.family<List<ProgressModel>, String>((ref, userId) {
  return ref.read(progressRepositoryProvider).getHistory(userId);
});
