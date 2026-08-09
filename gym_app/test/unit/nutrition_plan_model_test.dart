import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/nutrition_plan_model.dart';

void main() {
  group('Alimento', () {
    test('fromMap cria alimento com todos os campos', () {
      final map = {
        'nome': 'Arroz Branco',
        'quantidade': '150g',
        'calorias': 195.0,
        'proteinas': 4.0,
        'hidratos': 42.0,
        'gorduras': 0.5,
      };

      final alimento = Alimento.fromMap(map);

      expect(alimento.nome, 'Arroz Branco');
      expect(alimento.quantidade, '150g');
      expect(alimento.calorias, 195.0);
      expect(alimento.proteinas, 4.0);
      expect(alimento.hidratos, 42.0);
      expect(alimento.gorduras, 0.5);
    });

    test('fromMap usa valores padrão', () {
      final map = <String, dynamic>{};

      final alimento = Alimento.fromMap(map);

      expect(alimento.nome, '');
      expect(alimento.quantidade, '');
      expect(alimento.calorias, 0.0);
      expect(alimento.proteinas, isNull);
    });

    test('toMap converte para mapa corretamente', () {
      const alimento = Alimento(
        nome: 'Peito de Frango',
        quantidade: '200g',
        calorias: 330.0,
        proteinas: 62.0,
      );

      final map = alimento.toMap();

      expect(map['nome'], 'Peito de Frango');
      expect(map['quantidade'], '200g');
      expect(map['calorias'], 330.0);
      expect(map['proteinas'], 62.0);
      expect(map.containsKey('hidratos'), false);
      expect(map.containsKey('gorduras'), false);
    });

    test('quantidadeGramas extrai número da string', () {
      const a1 = Alimento(nome: '', quantidade: '150g', calorias: 0);
      const a2 = Alimento(nome: '', quantidade: '200 gramas', calorias: 0);
      const a3 = Alimento(nome: '', quantidade: '1.5kg', calorias: 0);

      expect(a1.quantidadeGramas, 150.0);
      expect(a2.quantidadeGramas, 200.0);
      expect(a3.quantidadeGramas, 1.5);
    });

    test('quantidadeGramas retorna null para string sem número', () {
      const a = Alimento(nome: '', quantidade: 'a gosto', calorias: 0);
      expect(a.quantidadeGramas, isNull);
    });

    test('caloriasParaGramas calcula proporcionalmente', () {
      const alimento = Alimento(
        nome: 'Arroz',
        quantidade: '100g',
        calorias: 130.0,
      );

      // 50g → (50/100) * 130 = 65
      expect(alimento.caloriasParaGramas(50.0), 65.0);
      // 200g → (200/100) * 130 = 260
      expect(alimento.caloriasParaGramas(200.0), 260.0);
    });

    test('caloriasParaGramas retorna total quando sem quantidadeGramas', () {
      const alimento = Alimento(
        nome: 'Azeite',
        quantidade: 'a gosto',
        calorias: 90.0,
      );

      expect(alimento.caloriasParaGramas(10.0), 90.0);
    });

    test('proteinasParaGramas calcula proporcionalmente', () {
      const alimento = Alimento(
        nome: 'Frango',
        quantidade: '200g',
        calorias: 330.0,
        proteinas: 62.0,
      );

      // 100g → (100/200) * 62 = 31
      expect(alimento.proteinasParaGramas(100.0), 31.0);
    });

    test('hidratosParaGramas e gordurasParaGramas calculam corretamente', () {
      const alimento = Alimento(
        nome: 'Pão',
        quantidade: '50g',
        calorias: 130.0,
        hidratos: 25.0,
        gorduras: 2.0,
      );

      // 100g → (100/50) * 25 = 50
      expect(alimento.hidratosParaGramas(100.0), 50.0);
      // 25g → (25/50) * 2 = 1
      expect(alimento.gordurasParaGramas(25.0), 1.0);
    });
  });

  group('PlannedMeal', () {
    test('fromMap cria refeição com alimentos', () {
      final map = {
        'tipo': 'Almoço',
        'instrucoes': 'Comer devagar',
        'alimentos': [
          {'nome': 'Arroz', 'quantidade': '150g', 'calorias': 195.0},
          {
            'nome': 'Frango',
            'quantidade': '200g',
            'calorias': 330.0,
            'proteinas': 62.0,
          },
        ],
      };

      final meal = PlannedMeal.fromMap(map);

      expect(meal.tipo, 'Almoço');
      expect(meal.instrucoes, 'Comer devagar');
      expect(meal.alimentos.length, 2);
      expect(meal.alimentos[0].nome, 'Arroz');
      expect(meal.alimentos[1].nome, 'Frango');
    });

    test('fromMap usa valores padrão', () {
      final map = <String, dynamic>{};

      final meal = PlannedMeal.fromMap(map);

      expect(meal.tipo, '');
      expect(meal.alimentos, isEmpty);
      expect(meal.instrucoes, isNull);
    });

    test('toMap converte para mapa corretamente', () {
      const meal = PlannedMeal(
        tipo: 'Jantar',
        alimentos: [
          Alimento(nome: 'Salmão', quantidade: '150g', calorias: 312.0),
        ],
        instrucoes: 'Grelhar sem óleo',
      );

      final map = meal.toMap();

      expect(map['tipo'], 'Jantar');
      expect(map['instrucoes'], 'Grelhar sem óleo');
      expect(map['alimentos'], isA<List>());
      expect((map['alimentos'] as List).length, 1);
    });

    test('totalCalorias soma corretamente', () {
      const meal = PlannedMeal(
        tipo: 'Almoço',
        alimentos: [
          Alimento(nome: 'Arroz', quantidade: '100g', calorias: 130.0),
          Alimento(nome: 'Feijão', quantidade: '100g', calorias: 100.0),
          Alimento(nome: 'Bife', quantidade: '150g', calorias: 250.0),
        ],
      );

      expect(meal.totalCalorias, 480.0);
    });
  });

  group('NutritionPlanModel', () {
    const dia = 'Segunda-feira';
    const userId = 'user123';

    test('fromMap cria plano nutricional com refeições', () {
      final map = {
        'metaCalorias': 2000.0,
        'refeicoes': [
          {
            'tipo': 'Pequeno-almoço',
            'alimentos': [
              {'nome': 'Aveia', 'quantidade': '80g', 'calorias': 300.0},
            ],
          },
          {
            'tipo': 'Almoço',
            'alimentos': [
              {'nome': 'Arroz', 'quantidade': '150g', 'calorias': 195.0},
            ],
          },
        ],
      };

      final plan = NutritionPlanModel.fromMap(dia, userId, map);

      expect(plan.dia, dia);
      expect(plan.userId, userId);
      expect(plan.metaCalorias, 2000.0);
      expect(plan.refeicoes.length, 2);
      expect(plan.refeicoes[0].tipo, 'Pequeno-almoço');
      expect(plan.refeicoes[1].tipo, 'Almoço');
    });

    test('fromMap usa valores padrão', () {
      final map = <String, dynamic>{};

      final plan = NutritionPlanModel.fromMap(dia, userId, map);

      expect(plan.metaCalorias, 0.0);
      expect(plan.refeicoes, isEmpty);
    });

    test('toMap converte para mapa corretamente', () {
      const plan = NutritionPlanModel(
        dia: dia,
        userId: userId,
        metaCalorias: 1800.0,
        refeicoes: [
          PlannedMeal(
            tipo: 'Jantar',
            alimentos: [
              Alimento(nome: 'Sopa', quantidade: '300ml', calorias: 120.0),
            ],
          ),
        ],
      );

      final map = plan.toMap();

      expect(map['metaCalorias'], 1800.0);
      expect(map['refeicoes'], isA<List>());
      expect((map['refeicoes'] as List).length, 1);
    });

    test('totalCaloriasPlaneadas soma todas as refeições', () {
      const plan = NutritionPlanModel(
        dia: dia,
        userId: userId,
        refeicoes: [
          PlannedMeal(
            tipo: 'Almoço',
            alimentos: [
              Alimento(nome: 'Arroz', quantidade: '100g', calorias: 130.0),
              Alimento(nome: 'Frango', quantidade: '150g', calorias: 250.0),
            ],
          ),
          PlannedMeal(
            tipo: 'Jantar',
            alimentos: [
              Alimento(nome: 'Sopa', quantidade: '300ml', calorias: 120.0),
            ],
          ),
        ],
      );

      // 130 + 250 + 120 = 500
      expect(plan.totalCaloriasPlaneadas, 500.0);
    });
  });
}
