import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/workout_plan_model.dart';
import '../models/workout_log_model.dart';

/// Dados de progressão entre dois treinos consecutivos.
class ProgressionData {
  final String exerciseName;
  final double? cargaAnterior;
  final double? cargaAtual;
  final int? repsAnteriores;
  final int? repsAtuais;
  final double? aumentoKg;
  final double? aumentoPercentual;

  const ProgressionData({
    required this.exerciseName,
    this.cargaAnterior,
    this.cargaAtual,
    this.repsAnteriores,
    this.repsAtuais,
    this.aumentoKg,
    this.aumentoPercentual,
  });

  bool get progrediu => aumentoKg != null && aumentoKg! > 0;
  bool get manteve => aumentoKg != null && aumentoKg == 0;
}

/// Repository para planos de treino.
class WorkoutRepository {
  final FirestoreDataSource _firestoreDataSource;

  WorkoutRepository({required FirestoreDataSource firestoreDataSource})
      : _firestoreDataSource = firestoreDataSource;

  /// Obtém um plano de treino específico.
  Future<WorkoutPlanModel?> getPlan(String userId, String nome) async {
    try {
      return await _firestoreDataSource.getWorkoutPlan(userId, nome);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Lista todos os planos de treino do aluno.
  Future<List<WorkoutPlanModel>> getAllPlans(String userId) async {
    try {
      return await _firestoreDataSource.getAllWorkoutPlans(userId);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Guarda/atualiza plano de treino.
  Future<void> savePlan(
      String userId, String nome, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.setWorkoutPlan(userId, nome, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Lista exercícios disponíveis.
  Future<List<Map<String, dynamic>>> getExercises({String? grupoMuscular}) async {
    try {
      return await _firestoreDataSource.getExercises(grupoMuscular: grupoMuscular);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Calcula progressão comparando os últimos 2 treinos concluídos.
  /// Retorna lista de [ProgressionData] por exercício.
  Future<List<ProgressionData>> getProgression(String userId) async {
    try {
      final history = await _firestoreDataSource.getWorkoutLogHistory(
        userId,
        limit: 2,
      );

      final completed = history.where((l) => l.concluido).toList();
      if (completed.length < 2) return [];

      final atual = completed[0]; // mais recente
      final anterior = completed[1];

      final progressions = <ProgressionData>[];

      for (final exAtual in atual.exercicios) {
        final exAnterior = anterior.exercicios
            .where((e) => e.nome == exAtual.nome)
            .toList();
        if (exAnterior.isEmpty) continue;

        final cargaAtual = exAtual.cargaMaxima;
        final cargaAnterior = exAnterior.first.cargaMaxima;
        final repsAtual = exAtual.series
            .where((s) => s.repeticoes != null)
            .fold<int>(0, (sum, s) => sum + (s.repeticoes ?? 0));
        final repsAnterior = exAnterior.first.series
            .where((s) => s.repeticoes != null)
            .fold<int>(0, (sum, s) => sum + (s.repeticoes ?? 0));

        double? aumentoKg;
        double? aumentoPercentual;
        if (cargaAtual != null && cargaAnterior != null) {
          aumentoKg = cargaAtual - cargaAnterior;
          aumentoPercentual = cargaAnterior > 0
              ? ((cargaAtual - cargaAnterior) / cargaAnterior) * 100
              : null;
        }

        progressions.add(ProgressionData(
          exerciseName: exAtual.nome,
          cargaAnterior: cargaAnterior,
          cargaAtual: cargaAtual,
          repsAnteriores: repsAnterior > 0 ? repsAnterior : null,
          repsAtuais: repsAtual > 0 ? repsAtual : null,
          aumentoKg: aumentoKg,
          aumentoPercentual: aumentoPercentual,
        ));
      }

      return progressions;
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
