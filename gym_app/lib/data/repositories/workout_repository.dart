import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/workout_plan_model.dart';

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
}
