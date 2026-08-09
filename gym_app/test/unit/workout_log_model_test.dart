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
