import 'dart:async';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/connectivity_service.dart';
import '../datasources/firestore_datasource.dart';
import '../models/diary_model.dart';

/// Repository para operações do diário do aluno.
class DiaryRepository {
  final FirestoreDataSource _firestoreDataSource;
  final ConnectivityService _connectivityService;

  DiaryRepository({
    required FirestoreDataSource firestoreDataSource,
    required ConnectivityService connectivityService,
  })  : _firestoreDataSource = firestoreDataSource,
        _connectivityService = connectivityService;

  /// Obtém a entrada do diário para uma data.
  Future<DiaryModel?> getDiaryEntry(String userId, String date) async {
    try {
      return await _firestoreDataSource.getDiaryEntry(userId, date);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream do diário do dia.
  Stream<DiaryModel?> diaryEntryStream(String userId, String date) {
    return _firestoreDataSource.diaryEntryStream(userId, date).handleError((e) {
      if (e is ServerException) throw ServerFailure(message: e.message);
      throw const ServerFailure(message: 'Erro ao carregar diário');
    });
  }

  /// Cria documento diário padrão se não existir.
  Future<void> ensureDiaryExists(String userId, String date) async {
    final exists = await getDiaryEntry(userId, date);
    if (exists == null) {
      await _firestoreDataSource.setDiaryEntry(userId, date, {
        'agua': 0,
        'passos': 0,
        'avaliacao': 0,
        'treinoConcluido': false,
        'refeicoes': [],
      });
    }
  }

  /// Incrementa a água do dia.
  Future<void> addWater(String userId, String date, int ml) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.incrementDiaryField(userId, date, 'agua', ml);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Define os passos do dia.
  Future<void> setSteps(String userId, String date, int steps) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.setDiaryEntry(userId, date, {'passos': steps});
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Define a avaliação do dia.
  Future<void> setRating(String userId, String date, int rating) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.setDiaryEntry(
          userId, date, {'avaliacao': rating});
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Marca treino como concluído.
  Future<void> markWorkoutDone(
      String userId, String date, Map<String, dynamic> treinoData) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.setDiaryEntry(userId, date, {
        'treinoConcluido': true,
        'treinoData': treinoData,
      });
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Adiciona refeição ao diário.
  Future<void> addMeal(
      String userId, String date, Map<String, dynamic> mealMap) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.addMealToDiary(userId, date, mealMap);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Obtém histórico de diários.
  Future<List<DiaryModel>> getHistory(String userId, {int limit = 90}) async {
    try {
      return await _firestoreDataSource.getDiaryHistory(userId, limit: limit);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
