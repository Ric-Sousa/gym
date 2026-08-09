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
      expect(food.origem, 'base externa');
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

    test('aceita os alimentos pesquisados em português', () {
      for (final name in ['Maçã', 'Arroz', 'Massa', 'Ovos', 'Queijo']) {
        final food = OpenFoodFactsDataSource.parseProduct({
          'product_name_pt': name,
          'nutriments': {'energy-kcal_100g': 100},
        });

        expect(food, isNotNull, reason: 'Falhou para $name');
        expect(food!.nome, name);
      }
    });

    test('usa o nome principal quando não existe tradução específica', () {
      final food = OpenFoodFactsDataSource.parseProduct({
        'product_name': 'Leite meio gordo',
        'nutriments': {'energy-kcal_100g': 50},
      });

      expect(food, isNotNull);
      expect(food!.nome, 'Leite meio gordo');
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
