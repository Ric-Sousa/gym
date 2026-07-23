import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/nutrition_plan_model.dart';
import '../models/food_model.dart';

/// Repository para planos nutricionais e alimentos.
class NutritionRepository {
  final FirestoreDataSource _firestoreDataSource;

  NutritionRepository({required FirestoreDataSource firestoreDataSource})
      : _firestoreDataSource = firestoreDataSource;

  /// Obtém o plano nutricional para um dia da semana.
  Future<NutritionPlanModel?> getPlan(String userId, String diaSemana) async {
    try {
      return await _firestoreDataSource.getNutritionPlan(userId, diaSemana);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Guarda/atualiza plano nutricional.
  Future<void> savePlan(
      String userId, String diaSemana, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.setNutritionPlan(userId, diaSemana, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Lista todos os alimentos.
  Future<List<FoodModel>> getAllFoods() async {
    try {
      return await _firestoreDataSource.getAllFoods();
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Pesquisa alimentos.
  Future<List<FoodModel>> searchFoods(String query) async {
    try {
      return await _firestoreDataSource.searchFoods(query);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Adiciona alimento à base de dados.
  Future<void> addFood(Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.addFood(data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
