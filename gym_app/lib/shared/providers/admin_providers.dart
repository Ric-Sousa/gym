import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/nutrition_plan_model.dart';
import '../../data/models/workout_plan_model.dart';
import '../../data/models/workout_log_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/progress_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/questionnaire_response_model.dart';
import '../../data/models/questionnaire_config_model.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/admin_theme.dart';
import '../../data/repositories/workout_repository.dart';
import 'global_providers.dart';

// ─── Admin Theme Toggle ─────────────────────────────────────────

/// Provider para o modo escuro/claro do painel admin.
final adminThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.dark,
);

/// Provider que expõe a paleta admin atual (dark ou light).
final adminColorsProvider = Provider<AdminThemeColors>((ref) {
  final mode = ref.watch(adminThemeModeProvider);
  return mode == ThemeMode.dark
      ? AdminThemeColors.dark
      : AdminThemeColors.light;
});

/// Provider do plano nutricional do aluno (admin view).
final adminNutritionPlanProvider =
    StreamProvider.family<NutritionPlanModel?, (String, String)>((ref, params) {
      final (userId, diaSemana) = params;
      return ref.read(nutritionRepositoryProvider).watchPlan(userId, diaSemana);
    });

/// Provider do plano de treino do aluno (admin view).
final adminWorkoutPlansProvider =
    StreamProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
      return ref.read(workoutRepositoryProvider).watchAllPlans(userId);
    });

/// Configuração editável da ficha inicial, partilhada pelo admin e aluno.
final questionnaireConfigProvider = StreamProvider<QuestionnaireConfig>((ref) {
  return ref.read(userRepositoryProvider).questionnaireConfigStream();
});

/// Respostas da ficha inicial do aluno (admin view).
final adminQuestionnaireProvider =
    StreamProvider.family<QuestionnaireResponse?, String>((ref, userId) {
      return ref.read(userRepositoryProvider).questionnaireStream(userId);
    });

/// Provider de progresso (admin view).
final adminProgressProvider =
    StreamProvider.family<List<ProgressModel>, String>((ref, userId) {
      return ref.read(progressRepositoryProvider).watchHistory(userId);
    });

/// Provider de logs de treino para gráfico de progressão de cargas (admin).
final adminWorkoutLogsProvider =
    StreamProvider.family<List<WorkoutLogModel>, String>((ref, userId) {
      return ref
          .read(workoutLogRepositoryProvider)
          .watchHistory(userId, limit: 30);
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

final adminDashboardStatsProvider = StreamProvider<AdminDashboardStats>((ref) {
  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<AdminDashboardStats>();
  final diarySubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final diaryCounts = <String, (int total, int month)>{};
  var alunoSnapshot = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  DateTime? asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  void emit() {
    final now = DateTime.now();
    var active = 0;
    for (final doc in alunoSnapshot) {
      final lastActivity = asDate(doc.data()['ultimaAtividade']);
      if (lastActivity != null && now.difference(lastActivity).inDays < 30) {
        active++;
      }
    }
    final totalSessions = diaryCounts.values.fold<int>(
      0,
      (total, entry) => total + entry.$1,
    );
    final monthSessions = diaryCounts.values.fold<int>(
      0,
      (total, entry) => total + entry.$2,
    );
    if (!controller.isClosed) {
      controller.add(AdminDashboardStats(
        totalAlunos: alunoSnapshot.length,
        activeAlunos: active,
        sessoesMes: monthSessions,
        sessoesTotal: totalSessions,
      ));
    }
  }

  void watchDiary(String userId) {
    if (diarySubscriptions.containsKey(userId)) return;
    diarySubscriptions[userId] = firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.diarySubcollection)
        .snapshots()
        .listen((snapshot) {
          var total = 0;
          var month = 0;
          final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['treinoConcluido'] != true) continue;
            total++;
            final treinoData = data['treinoData'];
            final completedAt = treinoData is Map
                ? asDate(treinoData['completedAt'])
                : null;
            if (completedAt != null && completedAt.isAfter(startOfMonth)) {
              month++;
            }
          }
          diaryCounts[userId] = (total, month);
          emit();
        }, onError: (_) {
          diaryCounts[userId] = (0, 0);
          emit();
        });
  }

  final usersSubscription = firestore
      .collection(AppConstants.usersCollection)
      .where('role', isEqualTo: AppConstants.roleAluno)
      .snapshots()
      .listen((snapshot) {
        alunoSnapshot = snapshot.docs;
        final ids = alunoSnapshot.map((doc) => doc.id).toSet();
        for (final id in diarySubscriptions.keys.toList()) {
          if (!ids.contains(id)) {
            diarySubscriptions.remove(id)?.cancel();
            diaryCounts.remove(id);
          }
        }
        for (final id in ids) {
          watchDiary(id);
        }
        emit();
      });

  ref.onDispose(() {
    usersSubscription.cancel();
    for (final subscription in diarySubscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });
  return controller.stream;
});

// ─── Exercises ────────────────────────────────────────────────────

final adminExercisesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(workoutRepositoryProvider).watchExercises();
});

// ─── Foods ────────────────────────────────────────────────────────

final adminFoodsProvider = StreamProvider<List<FoodModel>>((ref) {
  return ref.read(nutritionRepositoryProvider).watchAllFoods();
});

final adminFoodsSearchProvider =
    StreamProvider.family<List<FoodModel>, String>((ref, query) {
  final foods = ref.watch(adminFoodsProvider);
  return foods.when(
    data: (items) {
      if (query.trim().isEmpty) return Stream.value(items);
      final lower = query.trim().toLowerCase();
      return Stream.value(
        items.where((food) => food.nome.toLowerCase().contains(lower)).toList(),
      );
    },
    loading: () => const Stream.empty(),
    error: (error, stack) => Stream.error(error, stack),
  );
});

// ─── Payments ─────────────────────────────────────────────────────

/// Provider de todos os pagamentos (admin).
final adminAllPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  return ref.read(paymentRepositoryProvider).watchAllPayments();
});

/// Provider de pagamentos de um aluno específico (admin).
final adminUserPaymentsProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, userId) {
      return ref.read(paymentRepositoryProvider).watchPayments(userId);
    });

/// Provider de agenda do trainer (admin) — Stream para atualizações em tempo real.
final adminTrainerBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, trainerId) {
      if (trainerId.isEmpty) return Stream.value([]);
      return ref
          .read(bookingRepositoryProvider)
          .watchTrainerBookings(trainerId);
    });

/// Provider de progressão de cargas para clientes online.
final onlineProgressionProvider =
    StreamProvider.family<List<ProgressionData>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).watchProgression(userId);
});

/// Provider de todos os grupos (admin).
final adminGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  return ref.read(groupRepositoryProvider).watchAllGroups();
});

/// Provider de nomes de alunos para a agenda (batch fetch).
final adminStudentNamesProvider =
    StreamProvider.family<Map<String, String>, String>((ref, trainerId) {
  if (trainerId.isEmpty) return Stream.value({});
  final bookingsAsync = ref.watch(adminTrainerBookingsProvider(trainerId));
  final bookings = bookingsAsync.asData?.value ?? const <BookingModel>[];
  final uids = bookings.map((booking) => booking.studentId).toSet().toList();
  if (uids.isEmpty) return Stream.value({});
  return Stream.fromFuture(ref.read(userRepositoryProvider).getUserNames(uids));
});
