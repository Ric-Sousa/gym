import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/utils/food_search.dart';
import 'package:gym_app/data/models/food_model.dart';

void main() {
  const foods = <FoodModel>[
    FoodModel(nome: 'Arroz de bacalhau', caloriasPor100g: 160),
    FoodModel(nome: 'Arroz agulha', caloriasPor100g: 130),
    FoodModel(nome: 'Arroz integral', caloriasPor100g: 124),
    FoodModel(nome: 'Ovo de galinha inteiro', caloriasPor100g: 143),
    FoodModel(nome: 'Ovos mexidos com queijo', caloriasPor100g: 210),
    FoodModel(nome: 'Whey protein', caloriasPor100g: 390),
    FoodModel(nome: 'Batido com whey protein', caloriasPor100g: 120),
  ];

  group('FoodSearch', () {
    test('ignora plural e apresenta o ovo simples antes dos compostos', () {
      final results = FoodSearch.filterAndRank(foods, 'ovos');

      expect(results.map((food) => food.nome), [
        'Ovo de galinha inteiro',
        'Ovos mexidos com queijo',
      ]);
    });

    test('encontra whey protein e dá prioridade ao alimento-base', () {
      final results = FoodSearch.filterAndRank(foods, 'Whey');

      expect(results.first.nome, 'Whey protein');
      expect(results.last.nome, 'Batido com whey protein');
    });

    test('separa arroz simples de arroz composto e preserva relevância', () {
      final results = FoodSearch.filterAndRank(foods, 'arroz');

      expect(results.map((food) => food.nome), [
        'Arroz agulha',
        'Arroz integral',
        'Arroz de bacalhau',
      ]);
      expect(FoodSearch.kindOf(results.first), FoodKind.simple);
      expect(FoodSearch.kindOf(results.last), FoodKind.compound);
    });

    test('tipo explícito prevalece sobre a classificação automática', () {
      const explicit = FoodModel(
        nome: 'Mistura personalizada',
        caloriasPor100g: 100,
        tipo: 'simples',
      );

      expect(FoodSearch.kindOf(explicit), FoodKind.simple);
      expect(explicit.toMap()['tipo'], 'simples');
      expect(
        FoodModel.fromMap('id', explicit.toMap()).tipo,
        FoodKind.simple.value,
      );
    });

    test('pesquisa ignora acentos e caixa', () {
      const accented = FoodModel(nome: 'Pão de centeio', caloriasPor100g: 250);

      expect(FoodSearch.filterAndRank([accented], 'PAES'), [accented]);
    });
  });
}
