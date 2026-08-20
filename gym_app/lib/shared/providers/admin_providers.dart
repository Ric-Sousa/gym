import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/firestore_datasource.dart';
import 'package:flutter/material.dart';
import '../../data/models/nutrition_plan_model.dart';
import '../../data/models/workout_plan_model.dart';
import '../../data/models/workout_log_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/progress_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/exercise_catalog_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/questionnaire_response_model.dart';
import '../../data/models/questionnaire_config_model.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/admin_theme.dart';
import '../../data/repositories/workout_repository.dart';
import 'global_providers.dart';

// ─── Cursor pagination ───────────────────────────────────────────

/// Estado comum das listagens administrativas paginadas.
class AdminPagedList<T> extends ChangeNotifier {
  final Future<FirestorePage<T>> Function(
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limit,
  )
  loadPage;
  final Comparator<T>? comparator;
  final int pageSize;

  final List<T> items = <T>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool hasMore = true;
  bool isLoading = false;
  Object? error;

  AdminPagedList({required this.loadPage, this.comparator, this.pageSize = 25});

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await loadPage(_cursor, pageSize);
      items.addAll(page.items);
      if (comparator != null) items.sort(comparator);
      _cursor = page.cursor;
      hasMore = page.hasMore && page.items.isNotEmpty;
    } catch (value) {
      error = value;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    items.clear();
    _cursor = null;
    hasMore = true;
    error = null;
    notifyListeners();
    await loadMore();
  }
}

final adminStudentsPagerProvider =
    ChangeNotifierProvider<AdminPagedList<UserModel>>((ref) {
      final source = ref.read(firestoreDataSourceProvider);
      final controller = AdminPagedList<UserModel>(
        pageSize: 25,
        loadPage: (cursor, limit) =>
            source.getAlunosPage(startAfter: cursor, limit: limit),
        comparator: (a, b) =>
            a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      );
      controller.loadMore();
      return controller;
    });

final adminFoodsPagerProvider =
    ChangeNotifierProvider<AdminPagedList<FoodModel>>((ref) {
      final source = ref.read(firestoreDataSourceProvider);
      final controller = AdminPagedList<FoodModel>(
        pageSize: 30,
        loadPage: (cursor, limit) =>
            source.getFoodsPage(startAfter: cursor, limit: limit),
      );
      controller.loadMore();
      return controller;
    });

final adminPaymentsPagerProvider =
    ChangeNotifierProvider<AdminPagedList<PaymentModel>>((ref) {
      final source = ref.read(firestoreDataSourceProvider);
      final controller = AdminPagedList<PaymentModel>(
        pageSize: 30,
        loadPage: (cursor, limit) =>
            source.getPaymentsPage(startAfter: cursor, limit: limit),
      );
      controller.loadMore();
      return controller;
    });

final adminGroupsPagerProvider =
    ChangeNotifierProvider<AdminPagedList<GroupModel>>((ref) {
      final source = ref.read(firestoreDataSourceProvider);
      final controller = AdminPagedList<GroupModel>(
        pageSize: 25,
        loadPage: (cursor, limit) =>
            source.getGroupsPage(startAfter: cursor, limit: limit),
      );
      controller.loadMore();
      return controller;
    });

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

/// Calcula as métricas sem depender do estado dos listeners do Firestore.
/// O agregado de sessões é opcional: enquanto ainda não existir ou não estiver
/// acessível, as métricas de clientes continuam válidas e estáveis.
AdminDashboardStats calculateAdminDashboardStats({
  required Iterable<Map<String, dynamic>> alunos,
  required Map<String, dynamic> aggregate,
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();

  DateTime? asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  final startOfMonth =
      '${referenceTime.year}-${referenceTime.month.toString().padLeft(2, '0')}';
  final alunoList = alunos.toList(growable: false);
  final active = alunoList.where((data) {
    final lastActivity = asDate(data['ultimaAtividade']);
    return lastActivity != null &&
        referenceTime.difference(lastActivity).inDays < 30;
  }).length;
  final sessionsByMonth = aggregate['sessionsByMonth'];
  final monthSessions =
      sessionsByMonth is Map && sessionsByMonth[startOfMonth] is num
      ? (sessionsByMonth[startOfMonth] as num).toInt()
      : 0;
  final totalSessions = aggregate['sessoesTotal'];

  return AdminDashboardStats(
    totalAlunos: alunoList.length,
    activeAlunos: active,
    sessoesMes: monthSessions,
    sessoesTotal: totalSessions is num ? totalSessions.toInt() : 0,
  );
}

final adminDashboardStatsProvider = StreamProvider<AdminDashboardStats>((ref) {
  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<AdminDashboardStats>();
  var alunos = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  var aggregate = <String, dynamic>{};
  var usersLoaded = false;
  var aggregateResolved = false;

  void emit() {
    // O listener do agregado pode responder antes da query de utilizadores.
    // Não emitir zeros transitórios evita que os cartões pisquem no arranque.
    if (!usersLoaded || !aggregateResolved || controller.isClosed) return;
    controller.add(
      calculateAdminDashboardStats(
        alunos: alunos.map((doc) => doc.data()),
        aggregate: aggregate,
      ),
    );
  }

  final usersSubscription = firestore
      .collection(AppConstants.usersCollection)
      .where('role', isEqualTo: AppConstants.roleAluno)
      .snapshots()
      .listen(
        (snapshot) {
          alunos = snapshot.docs;
          usersLoaded = true;
          emit();
        },
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
      );
  final aggregateSubscription = firestore
      .collection('adminAggregates')
      .doc('dashboard')
      .snapshots()
      .listen(
        (snapshot) {
          aggregate = snapshot.data() ?? <String, dynamic>{};
          aggregateResolved = true;
          emit();
        },
        onError: (Object error, StackTrace _) {
          // O agregado é uma otimização materializada e não pode invalidar as
          // métricas já carregadas. Mantemos o último valor conhecido (ou zero
          // para sessões) e deixamos o listener do Firestore recuperar.
          debugPrint('Falha ao atualizar o agregado do dashboard: $error');
          aggregateResolved = true;
          emit();
        },
      );

  ref.onDispose(() {
    usersSubscription.cancel();
    aggregateSubscription.cancel();
    controller.close();
  });
  return controller.stream;
});

// ─── Exercises ────────────────────────────────────────────────────

final adminExercisesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.read(workoutRepositoryProvider).watchExercises();
});

/// Biblioteca completa de exercícios, incluindo instruções e classificação.
final adminExerciseCatalogProvider = StreamProvider<List<ExerciseCatalogModel>>(
  (ref) {
    return ref.read(workoutRepositoryProvider).watchExerciseCatalog();
  },
);

// ─── Foods ────────────────────────────────────────────────────────

final adminFoodsProvider = StreamProvider<List<FoodModel>>((ref) {
  return ref.read(nutritionRepositoryProvider).watchAllFoods();
});

final adminFoodsSearchProvider = StreamProvider.family<List<FoodModel>, String>(
  (ref, query) {
    // Mantém este provider dependente do stream local para atualizar a lista
    // depois de um alimento ser criado no admin, mas não bloqueia o catálogo
    // inicial enquanto esse stream ainda está a carregar.
    ref.watch(adminFoodsProvider);
    final repository = ref.read(nutritionRepositoryProvider);
    final future = query.trim().isEmpty
        ? repository.getAvailableFoods()
        : repository.searchFoods(query);
    return Stream.fromFuture(future);
  },
);

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
      final uids = bookings
          .map((booking) => booking.studentId)
          .toSet()
          .toList();
      if (uids.isEmpty) return Stream.value({});
      return Stream.fromFuture(
        ref.read(userRepositoryProvider).getUserNames(uids),
      );
    });
