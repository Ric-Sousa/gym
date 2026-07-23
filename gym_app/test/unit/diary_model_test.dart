import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/diary_model.dart';

void main() {
  group('DiaryModel', () {
    const userId = 'user123';
    const date = '2026-07-23';

    test('fromMap cria modelo com valores padrão', () {
      final map = <String, dynamic>{};

      final diary = DiaryModel.fromMap(date, userId, map);

      expect(diary.data, date);
      expect(diary.userId, userId);
      expect(diary.agua, 0);
      expect(diary.passos, 0);
      expect(diary.refeicoes, isEmpty);
    });

    test('totalCalorias soma corretamente', () {
      final diary = DiaryModel(
        data: date,
        userId: userId,
        refeicoes: const [
          MealEntry(
            tipo: 'Almoço',
            descricao: 'Arroz e frango',
            calorias: 500,
            hora: '12:00',
          ),
          MealEntry(
            tipo: 'Jantar',
            descricao: 'Salada',
            calorias: 300,
            hora: '19:00',
          ),
        ],
      );

      expect(diary.totalCalorias, 800.0);
    });

    test('toMap converte corretamente', () {
      const diary = DiaryModel(
        data: date,
        userId: userId,
        agua: 1500,
        passos: 5000,
        avaliacao: 4,
        treinoConcluido: true,
      );

      final map = diary.toMap();

      expect(map['agua'], 1500);
      expect(map['passos'], 5000);
      expect(map['avaliacao'], 4);
      expect(map['treinoConcluido'], true);
      expect(map['refeicoes'], isEmpty);
    });
  });

  group('MealEntry', () {
    test('fromMap/toMap são consistentes', () {
      const meal = MealEntry(
        tipo: 'Almoço',
        descricao: 'Arroz e feijão',
        calorias: 450,
        hora: '12:30',
        alimentos: ['Arroz', 'Feijão', 'Bife'],
      );

      final map = meal.toMap();
      final restored = MealEntry.fromMap(map);

      expect(restored.tipo, meal.tipo);
      expect(restored.descricao, meal.descricao);
      expect(restored.calorias, meal.calorias);
      expect(restored.hora, meal.hora);
      expect(restored.alimentos, meal.alimentos);
    });
  });
}
