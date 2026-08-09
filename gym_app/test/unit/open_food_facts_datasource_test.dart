import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/datasources/open_food_facts_datasource.dart';

void main() {
  group('OpenFoodFactsDataSource', () {
    test('converte produto com nome e macronutrientes', () {
      final food = OpenFoodFactsDataSource.parseProduct({
        'code': '5601234567890',
        'product_name_pt': 'Iogurte natural',
        'product_name': 'Yaourt nature',
        'nutriments': {
          'energy-kcal_100g': 62,
          'proteins_100g': 4.3,
          'carbohydrates_100g': 5.2,
          'fat_100g': 2.1,
        },
      });

      expect(food, isNotNull);
      expect(food!.id, 'off_5601234567890');
      expect(food.nome, 'Iogurte natural');
      expect(food.caloriasPor100g, 62);
      expect(food.proteinasPor100g, 4.3);
      expect(food.hidratosPor100g, 5.2);
      expect(food.gordurasPor100g, 2.1);
      expect(food.origem, 'Open Food Facts');
    });

    test('converte energia em kJ para kcal quando necessário', () {
      final food = OpenFoodFactsDataSource.parseProduct({
        'product_name_pt': 'Produto',
        'nutriments': {'energy_100g': 418.4},
      });

      expect(food, isNotNull);
      expect(food!.nome, 'Produto');
      expect(food.caloriasPor100g, closeTo(100, 0.001));
    });

    test('ignora produto sem nome específico em português', () {
      expect(
        OpenFoodFactsDataSource.parseProduct({
          'product_name': 'Nome estrangeiro',
          'languages_codes': ['pt'],
          'nutriments': {'energy-kcal_100g': 100},
        }),
        isNull,
      );
    });

    test('ignora produto sem dados nutricionais', () {
      expect(
        OpenFoodFactsDataSource.parseProduct({
          'product_name_pt': 'Água',
          'nutriments': {},
        }),
        isNull,
      );
    });
  });
}
