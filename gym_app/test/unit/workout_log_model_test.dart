import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/workout_log_model.dart';

void main() {
  group('SerieLog', () {
    test('serializa carga e repetições para o registo', () {
      const serie = SerieLog(
        numero: 1,
        carga: 42.5,
        repeticoes: 10,
        concluida: true,
      );

      expect(serie.toMap(), {
        'numero': 1,
        'carga': 42.5,
        'repeticoes': 10,
        'concluida': true,
      });
    });

    test('preserva a marca de série adicionada manualmente', () {
      const serie = SerieLog(numero: 4, adicionadaManualmente: true);

      expect(serie.toMap()['adicionadaManualmente'], true);
      expect(SerieLog.fromMap(serie.toMap()).adicionadaManualmente, isTrue);
    });

    test('preserva a marca manual no documento completo do treino', () {
      final log = WorkoutLogModel(
        userId: 'aluno-1',
        data: DateTime(2026, 8, 9),
        planoSemana: 'Plano A',
        diaSemana: 'segunda',
        exercicios: const [
          ExerciseLog(
            nome: 'Supino',
            series: [SerieLog(numero: 1, adicionadaManualmente: true)],
          ),
        ],
      );

      final restored = WorkoutLogModel.fromMap('log-1', 'aluno-1', log.toMap());

      expect(
        restored.exercicios.single.series.single.adicionadaManualmente,
        isTrue,
      );
    });

    test('lê carga e repetições guardadas', () {
      final serie = SerieLog.fromMap({
        'numero': 2,
        'carga': 55,
        'repeticoes': 8,
        'concluida': false,
      });

      expect(serie.numero, 2);
      expect(serie.carga, 55.0);
      expect(serie.repeticoes, 8);
      expect(serie.concluida, isFalse);
    });
  });
}
