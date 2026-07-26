import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/workout_plan_model.dart';

void main() {
  group('Exercise', () {
    test('fromMap cria exercício com todos os campos', () {
      final map = {
        'nome': 'Supino Reto',
        'series': 4,
        'repeticoes': 10,
        'cargaSugerida': 60.0,
        'descanso': 90,
        'videoURL': 'https://example.com/supino.mp4',
        'observacoes': 'Manter cotovelos a 45°',
        'grupoMuscular': 'Peito',
      };

      final exercise = Exercise.fromMap(map);

      expect(exercise.nome, 'Supino Reto');
      expect(exercise.series, 4);
      expect(exercise.repeticoes, 10);
      expect(exercise.cargaSugerida, 60.0);
      expect(exercise.descanso, 90);
      expect(exercise.videoURL, 'https://example.com/supino.mp4');
      expect(exercise.observacoes, 'Manter cotovelos a 45°');
      expect(exercise.grupoMuscular, 'Peito');
    });

    test('fromMap usa valores padrão', () {
      final map = {'nome': 'Agachamento'};

      final exercise = Exercise.fromMap(map);

      expect(exercise.nome, 'Agachamento');
      expect(exercise.series, 3);
      expect(exercise.repeticoes, 10);
      expect(exercise.descanso, 60);
      expect(exercise.cargaSugerida, isNull);
      expect(exercise.videoURL, isNull);
    });

    test('toMap converte para mapa corretamente', () {
      const exercise = Exercise(
        nome: 'Supino Reto',
        series: 4,
        repeticoes: 10,
        cargaSugerida: 60.0,
        descanso: 90,
        grupoMuscular: 'Peito',
      );

      final map = exercise.toMap();

      expect(map['nome'], 'Supino Reto');
      expect(map['series'], 4);
      expect(map['repeticoes'], 10);
      expect(map['cargaSugerida'], 60.0);
      expect(map['descanso'], 90);
      expect(map['grupoMuscular'], 'Peito');
      // Valores null não aparecem
      expect(map.containsKey('videoURL'), false);
      expect(map.containsKey('observacoes'), false);
    });
  });

  group('WorkoutDay', () {
    test('fromMap cria dia de treino com exercícios', () {
      final map = {
        'diaSemana': 'Segunda-feira',
        'foco': 'Peito e Tríceps',
        'exercicios': [
          {'nome': 'Supino Reto', 'series': 4, 'repeticoes': 10},
          {'nome': 'Crucifixo', 'series': 3, 'repeticoes': 12},
        ],
      };

      final day = WorkoutDay.fromMap(map);

      expect(day.diaSemana, 'Segunda-feira');
      expect(day.foco, 'Peito e Tríceps');
      expect(day.exercicios.length, 2);
      expect(day.exercicios[0].nome, 'Supino Reto');
      expect(day.exercicios[1].nome, 'Crucifixo');
    });

    test('fromMap usa valores padrão', () {
      final map = <String, dynamic>{};

      final day = WorkoutDay.fromMap(map);

      expect(day.diaSemana, '');
      expect(day.foco, '');
      expect(day.exercicios, isEmpty);
    });

    test('toMap converte para mapa corretamente', () {
      const day = WorkoutDay(
        diaSemana: 'Terça-feira',
        foco: 'Costas e Bíceps',
        exercicios: [
          Exercise(nome: 'Puxada Alta', series: 3, repeticoes: 12),
        ],
      );

      final map = day.toMap();

      expect(map['diaSemana'], 'Terça-feira');
      expect(map['foco'], 'Costas e Bíceps');
      expect(map['exercicios'], isA<List>());
      expect((map['exercicios'] as List).length, 1);
    });
  });

  group('WorkoutPlanModel', () {
    const nome = 'Semana 1 - Ciclo A';
    const userId = 'user123';

    test('fromMap cria plano com dias de treino', () {
      final map = {
        'dias': [
          {
            'diaSemana': 'Segunda-feira',
            'foco': 'Peito',
            'exercicios': [
              {'nome': 'Supino', 'series': 4, 'repeticoes': 10},
            ],
          },
          {
            'diaSemana': 'Quarta-feira',
            'foco': 'Costas',
            'exercicios': [
              {'nome': 'Remada', 'series': 3, 'repeticoes': 12},
            ],
          },
        ],
      };

      final plan = WorkoutPlanModel.fromMap(nome, userId, map);

      expect(plan.nome, nome);
      expect(plan.userId, userId);
      expect(plan.dias.length, 2);
      expect(plan.dias[0].diaSemana, 'Segunda-feira');
      expect(plan.dias[1].diaSemana, 'Quarta-feira');
    });

    test('fromMap usa lista vazia quando não há dias', () {
      final map = <String, dynamic>{};

      final plan = WorkoutPlanModel.fromMap(nome, userId, map);

      expect(plan.dias, isEmpty);
    });

    test('toMap converte para mapa corretamente', () {
      const plan = WorkoutPlanModel(
        nome: nome,
        userId: userId,
        dias: [
          WorkoutDay(diaSemana: 'Segunda-feira', foco: 'Peito', exercicios: []),
        ],
      );

      final map = plan.toMap();

      expect(map['dias'], isA<List>());
      expect((map['dias'] as List).length, 1);
      expect(map.containsKey('nome'), false); // nome não vai no mapa
      expect(map.containsKey('userId'), false); // userId não vai no mapa
    });

    test('getWorkoutForDay encontra o treino do dia', () {
      const plan = WorkoutPlanModel(
        nome: nome,
        userId: userId,
        dias: [
          WorkoutDay(diaSemana: 'Segunda-feira', foco: 'Peito'),
          WorkoutDay(diaSemana: 'Quarta-feira', foco: 'Costas'),
          WorkoutDay(diaSemana: 'Sexta-feira', foco: 'Pernas'),
        ],
      );

      final workout = plan.getWorkoutForDay('Quarta-feira');
      expect(workout, isNotNull);
      expect(workout!.diaSemana, 'Quarta-feira');
      expect(workout.foco, 'Costas');
    });

    test('getWorkoutForDay retorna null para dia inexistente', () {
      const plan = WorkoutPlanModel(
        nome: nome,
        userId: userId,
        dias: [
          WorkoutDay(diaSemana: 'Segunda-feira', foco: 'Peito'),
        ],
      );

      final workout = plan.getWorkoutForDay('Domingo');
      expect(workout, isNull);
    });
  });
}
