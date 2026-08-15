import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/workout_log_model.dart';

/// Repository para registos de treino executados.
class WorkoutLogRepository {
  final FirestoreDataSource _firestoreDataSource;

  WorkoutLogRepository({required FirestoreDataSource firestoreDataSource})
    : _firestoreDataSource = firestoreDataSource;

  /// Obtém o registo de treino de um dia específico.
  Future<WorkoutLogModel?> getLog(String userId, String date) async {
    try {
      return await _firestoreDataSource.getWorkoutLog(userId, date);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream do registo de treino de hoje.
  Stream<WorkoutLogModel?> logStream(String userId, String date) {
    return _firestoreDataSource.workoutLogStream(userId, date);
  }

  /// Guarda/atualiza registo de treino.
  Future<void> saveLog(
    String userId,
    String date,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestoreDataSource.setWorkoutLog(userId, date, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream do histórico de treinos do aluno.
  Stream<List<WorkoutLogModel>> watchHistory(
    String userId, {
    int limit = 30,
  }) {
    return _firestoreDataSource.watchWorkoutLogHistory(userId, limit: limit);
  }

  /// Obtém histórico de treinos do aluno.
  Future<List<WorkoutLogModel>> getHistory(
    String userId, {
    int limit = 30,
  }) async {
    try {
      return await _firestoreDataSource.getWorkoutLogHistory(
        userId,
        limit: limit,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
