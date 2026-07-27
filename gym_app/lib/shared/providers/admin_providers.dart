import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/nutrition_plan_model.dart';
import '../../data/models/workout_plan_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/progress_model.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/admin_theme.dart';
import 'global_providers.dart';

// ─── Admin Theme Toggle ─────────────────────────────────────────

/// Provider para o modo escuro/claro do painel admin.
final adminThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Provider que expõe a paleta admin atual (dark ou light).
final adminColorsProvider = Provider<AdminThemeColors>((ref) {
  final mode = ref.watch(adminThemeModeProvider);
  return mode == ThemeMode.dark ? AdminThemeColors.dark : AdminThemeColors.light;
});

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

// ─── Dashboard Analytics ──────────────────────────────────────────

/// Estatísticas agregadas para o dashboard do admin.
class AdminDashboardStats {
  final int totalAlunos;
  final int activeAlunos;
  final int sessoesMes;
  final int sessoesTotal;

  const AdminDashboardStats({
    required this.totalAlunos,
    required this.activeAlunos,
    required this.sessoesMes,
    required this.sessoesTotal,
  });
}

final adminDashboardStatsProvider =
    FutureProvider<AdminDashboardStats>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  // Todos os alunos
  final alunosSnap = await firestore
      .collection(AppConstants.usersCollection)
      .where('role', isEqualTo: AppConstants.roleAluno)
      .get();

  final totalAlunos = alunosSnap.docs.length;
  int activeAlunos = 0;
  int sessoesTotal = 0;
  int sessoesMes = 0;

  for (final doc in alunosSnap.docs) {
    final data = doc.data();
    final ultimaAtividade = data['ultimaAtividade'] as Timestamp?;
    if (ultimaAtividade != null &&
        now.difference(ultimaAtividade.toDate()).inDays < 30) {
      activeAlunos++;
    }

    // Contar sessões (treinos concluídos) do diário de cada aluno
    final diarySnap = await firestore
        .collection(AppConstants.usersCollection)
        .doc(doc.id)
        .collection(AppConstants.diarySubcollection)
        .where('treinoConcluido', isEqualTo: true)
        .get();

    for (final diary in diarySnap.docs) {
      final diaryData = diary.data();
      final completedAt = diaryData['treinoData'] != null
          ? diaryData['treinoData']['completedAt']
          : null;
      sessoesTotal++;

      if (completedAt != null) {
        final date = DateTime.tryParse(completedAt.toString());
        if (date != null && date.isAfter(startOfMonth)) {
          sessoesMes++;
        }
      }
    }
  }

  return AdminDashboardStats(
    totalAlunos: totalAlunos,
    activeAlunos: activeAlunos,
    sessoesMes: sessoesMes,
    sessoesTotal: sessoesTotal,
  );
});

// ─── Exercises ────────────────────────────────────────────────────

final adminExercisesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(workoutRepositoryProvider).getExercises();
});

// ─── Foods ────────────────────────────────────────────────────────

final adminFoodsProvider = FutureProvider<List<FoodModel>>((ref) {
  return ref.read(nutritionRepositoryProvider).getAllFoods();
});

final adminFoodsSearchProvider =
    FutureProvider.family<List<FoodModel>, String>((ref, query) {
  if (query.isEmpty) return ref.read(nutritionRepositoryProvider).getAllFoods();
  return ref.read(nutritionRepositoryProvider).searchFoods(query);
});
