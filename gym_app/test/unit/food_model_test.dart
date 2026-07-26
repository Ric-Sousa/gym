import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/food_model.dart';

void main() {
  group('FoodModel', () {
    const id = 'food123';
    const nome = 'Arroz Branco';
    const calorias = 130.0;

    test('fromMap cria modelo com todos os campos', () {
      final map = {
        'nome': nome,
        'caloriasPor100g': calorias,
        'proteinasPor100g': 2.7,
        'hidratosPor100g': 28.0,
        'gordurasPor100g': 0.3,
        'categoria': 'hidrato',
      };

      final food = FoodModel.fromMap(id, map);

      expect(food.id, id);
      expect(food.nome, nome);
      expect(food.caloriasPor100g, calorias);
      expect(food.proteinasPor100g, 2.7);
      expect(food.hidratosPor100g, 28.0);
      expect(food.gordurasPor100g, 0.3);
      expect(food.categoria, 'hidrato');
    });

    test('fromMap usa valores padrão quando campos estão ausentes', () {
      final map = <String, dynamic>{};

      final food = FoodModel.fromMap(id, map);

      expect(food.nome, '');
      expect(food.caloriasPor100g, 0.0);
      expect(food.proteinasPor100g, isNull);
      expect(food.hidratosPor100g, isNull);
      expect(food.gordurasPor100g, isNull);
      expect(food.categoria, isNull);
    });

    test('toMap converte para mapa corretamente', () {
      const food = FoodModel(
        id: id,
        nome: nome,
        caloriasPor100g: calorias,
        proteinasPor100g: 2.7,
        categoria: 'hidrato',
      );

      final map = food.toMap();

      expect(map['nome'], nome);
      expect(map['caloriasPor100g'], calorias);
      expect(map['proteinasPor100g'], 2.7);
      expect(map['categoria'], 'hidrato');
      // Campos null não devem aparecer
      expect(map.containsKey('hidratosPor100g'), false);
      expect(map.containsKey('gordurasPor100g'), false);
    });

    test('caloriasParaQuantidade calcula corretamente', () {
      const food = FoodModel(
        id: id,
        nome: nome,
        caloriasPor100g: 130.0,
      );

      // 200g → (130 / 100) * 200 = 260
      expect(food.caloriasParaQuantidade(200.0), 260.0);
      // 50g → (130 / 100) * 50 = 65
      expect(food.caloriasParaQuantidade(50.0), 65.0);
      // 0g → 0
      expect(food.caloriasParaQuantidade(0.0), 0.0);
    });

    test('copyWith altera apenas campos especificados', () {
      const food = FoodModel(
        id: id,
        nome: nome,
        caloriasPor100g: calorias,
      );

      final updated = food.copyWith(nome: 'Arroz Integral', caloriasPor100g: 123.0);

      expect(updated.id, id);
      expect(updated.nome, 'Arroz Integral');
      expect(updated.caloriasPor100g, 123.0);
    });

    test('toMap não inclui id no mapa', () {
      const food = FoodModel(
        id: 'abc123',
        nome: 'Peito de Frango',
        caloriasPor100g: 165.0,
      );

      final map = food.toMap();
      expect(map.containsKey('id'), false);
    });
  });
}
