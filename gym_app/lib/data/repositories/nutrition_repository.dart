import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/nutrition_plan_model.dart';
import '../models/food_model.dart';
import '../datasources/open_food_facts_datasource.dart';

/// Repository para planos nutricionais e alimentos.
class NutritionRepository {
  final FirestoreDataSource _firestoreDataSource;
  final OpenFoodFactsDataSource _openFoodFactsDataSource;

  NutritionRepository({
    required FirestoreDataSource firestoreDataSource,
    OpenFoodFactsDataSource? openFoodFactsDataSource,
  }) : _firestoreDataSource = firestoreDataSource,
       _openFoodFactsDataSource =
           openFoodFactsDataSource ?? OpenFoodFactsDataSource();

  /// Obtém o plano nutricional para um dia da semana.
  Future<NutritionPlanModel?> getPlan(String userId, String diaSemana) async {
    try {
      return await _firestoreDataSource.getNutritionPlan(userId, diaSemana);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream do plano nutricional para um dia.
  Stream<NutritionPlanModel?> watchPlan(String userId, String diaSemana) {
    return _firestoreDataSource.nutritionPlanStream(userId, diaSemana);
  }

  /// Stream de todos os alimentos locais.
  Stream<List<FoodModel>> watchAllFoods() {
    return _firestoreDataSource.watchAllFoods();
  }

  /// Guarda/atualiza plano nutricional.
  Future<void> savePlan(
    String userId,
    String diaSemana,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestoreDataSource.setNutritionPlan(userId, diaSemana, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Lista todos os alimentos guardados localmente no Firestore.
  Future<List<FoodModel>> getAllFoods() async {
    try {
      return await _firestoreDataSource.getAllFoods();
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Lista os alimentos disponíveis para seleção, incluindo a mesma base
  /// Open Food Facts usada pela pesquisa do aluno e do admin.
  Future<List<FoodModel>> getAvailableFoods() async {
    List<FoodModel> localFoods = [];
    try {
      localFoods = await getAllFoods();
    } catch (_) {
      // A base externa continua disponível mesmo quando o Firestore falha.
    }

    final externalFoods = await _openFoodFactsDataSource.getInitialFoods();
    final names = localFoods.map(_normaliseName).toSet();
    final merged = [...localFoods];
    for (final food in externalFoods) {
      if (names.add(_normaliseName(food))) merged.add(food);
    }
    return merged;
  }

  /// Pesquisa alimentos.
  Future<List<FoodModel>> searchFoods(String query) async {
    List<FoodModel> localFoods = [];
    try {
      localFoods = await _firestoreDataSource.searchFoods(query);
    } on ServerException catch (_) {
      // A API externa ainda pode fornecer resultados se o Firestore falhar.
    }

    final externalFoods = await _openFoodFactsDataSource.searchFoods(query);
    final names = localFoods.map(_normaliseName).toSet();
    final merged = [...localFoods];

    for (final food in externalFoods) {
      if (names.add(_normaliseName(food))) merged.add(food);
    }
    return merged;
  }

  static String _normaliseName(FoodModel food) =>
      food.nome.trim().toLowerCase();

  /// Adiciona alimento à base de dados.
  Future<void> addFood(Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.addFood(data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Remove alimento da base de dados.
  Future<void> deleteFood(String foodId) async {
    try {
      await _firestoreDataSource.deleteFood(foodId);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
