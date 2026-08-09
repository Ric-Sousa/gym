import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food_model.dart';

/// Cliente de pesquisa da base pública Open Food Facts.
///
/// A pesquisa é feita no endpoint português e não altera a base Firestore.
/// Os resultados são usados apenas como sugestões para o aluno.
class OpenFoodFactsDataSource {
  static const _baseUrl = 'https://pt.openfoodfacts.org/cgi/search.pl';
  static const _userAgent = 'GymApp/1.0 (https://github.com/Ric-Sousa/gym)';
  static const _cacheDuration = Duration(minutes: 10);

  final http.Client _client;
  final Map<String, _CachedFoodSearch> _cache = {};
  DateTime? _lastRequestAt;
  Future<void> _requestQueue = Future<void>.value();

  OpenFoodFactsDataSource({http.Client? client})
    : _client = client ?? http.Client();

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

      final lastRequestAt = _lastRequestAt;
      if (lastRequestAt != null) {
        final elapsed = DateTime.now().difference(lastRequestAt);
        if (elapsed < const Duration(seconds: 6)) {
          await Future<void>.delayed(const Duration(seconds: 6) - elapsed);
        }
      }
      _lastRequestAt = DateTime.now();

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'search_terms': trimmedQuery,
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'page_size': '20',
          'lc': 'pt',
          'fields':
              'code,product_name,product_name_pt,languages_codes,nutriments,categories_tags_pt',
        },
      );

      final response = await _client
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return [];
      final products = body['products'];
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
    } catch (_) {
      return [];
    } finally {
      requestFinished.complete();
    }
  }

  /// Converte um produto da API no modelo usado pela app.
  /// Retorna null quando não há nome ou informação nutricional utilizável.
  static FoodModel? parseProduct(Map<String, dynamic> product) {
    final portugueseName = _firstNonEmpty([product['product_name_pt']]);
    final languageCodes = product['languages_codes'];
    final hasPortugueseName = languageCodes is List
        ? languageCodes.any(
            (language) => language.toString().toLowerCase().startsWith('pt'),
          )
        : languageCodes is Map
        ? languageCodes.keys.any(
            (language) => language.toString().toLowerCase().startsWith('pt'),
          )
        : false;
    final name =
        portugueseName ??
        (hasPortugueseName ? _firstNonEmpty([product['product_name']]) : null);
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
