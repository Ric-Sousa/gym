import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/food_model.dart';

/// Cliente de pesquisa da base pública Open Food Facts.
///
/// A chamada passa pela Cloud Function para evitar CORS no Flutter Web e para
/// manter o User-Agent da integração no servidor.
class OpenFoodFactsDataSource {
  static const _cacheDuration = Duration(minutes: 10);

  final FirebaseFunctions _functions;
  final Map<String, _CachedFoodSearch> _cache = {};
  Future<void> _requestQueue = Future<void>.value();

  OpenFoodFactsDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Pesquisa produtos com nome disponível em português.
  ///
  /// Falhas da API externa são tratadas como uma pesquisa sem resultados,
  /// permitindo que os alimentos locais continuem disponíveis.
  Future<List<FoodModel>> searchFoods(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final cacheKey = trimmedQuery.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheDuration) {
      return cached.foods;
    }

    final previousRequest = _requestQueue;
    final requestFinished = Completer<void>();
    _requestQueue = requestFinished.future;
    await previousRequest;

    try {
      final cachedAfterQueue = _cache[cacheKey];
      if (cachedAfterQueue != null &&
          DateTime.now().difference(cachedAfterQueue.createdAt) <
              _cacheDuration) {
        return cachedAfterQueue.foods;
      }

      final callable = _functions.httpsCallable('searchOpenFoodFacts');
      final result = await callable.call<Map<String, dynamic>>({
        'query': trimmedQuery,
      });
      final products = result.data['products'];
      if (products is! List) return [];

      final foods = products
          .whereType<Map>()
          .map((product) => parseProduct(Map<String, dynamic>.from(product)))
          .whereType<FoodModel>()
          .toList();
      _cache.removeWhere(
        (_, value) =>
            DateTime.now().difference(value.createdAt) >= _cacheDuration,
      );
      _cache[cacheKey] = _CachedFoodSearch(DateTime.now(), foods);
      return foods;
    } on FirebaseFunctionsException {
      return [];
    } catch (_) {
      return [];
    } finally {
      requestFinished.complete();
    }
  }

  /// Converte um produto da API no modelo usado pela app.
  /// Retorna null quando não há nome em português ou dados nutricionais.
  static FoodModel? parseProduct(Map<String, dynamic> product) {
    // Exige o campo específico de nome em português; não usa
    // `product_name` como fallback para evitar apresentar nomes estrangeiros.
    final name = _firstNonEmpty([product['product_name_pt']]);
    if (name == null) return null;

    final nutriments = product['nutriments'];
    final nutrients = nutriments is Map
        ? Map<String, dynamic>.from(nutriments)
        : const <String, dynamic>{};
    final energyKcal = _number(nutrients['energy-kcal_100g']);
    final energyKj = _number(nutrients['energy_100g']);
    final calories = energyKcal ?? (energyKj == null ? null : energyKj / 4.184);
    final hasNutritionalData =
        calories != null ||
        nutrients.keys.any(
          (key) => key.endsWith('_100g') && _number(nutrients[key]) != null,
        );
    if (!hasNutritionalData) return null;

    final code = _firstNonEmpty([product['code']]);
    return FoodModel(
      id: code == null ? 'off_${name.toLowerCase()}' : 'off_$code',
      nome: name,
      caloriasPor100g: calories!,
      proteinasPor100g: _number(nutrients['proteins_100g']),
      hidratosPor100g: _number(nutrients['carbohydrates_100g']),
      gordurasPor100g: _number(nutrients['fat_100g']),
      categoria: 'Open Food Facts',
      origem: 'Open Food Facts',
    );
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}

class _CachedFoodSearch {
  final DateTime createdAt;
  final List<FoodModel> foods;

  const _CachedFoodSearch(this.createdAt, this.foods);
}
