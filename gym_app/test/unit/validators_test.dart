import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('retorna null para email válido', () {
        expect(Validators.email('joao@email.com'), null);
      });

      test('retorna erro para email vazio', () {
        expect(Validators.email(''), contains('obrigatório'));
      });

      test('retorna erro para email null', () {
        expect(Validators.email(null), contains('obrigatório'));
      });

      test('retorna erro para email sem @', () {
        expect(Validators.email('joaoemail.com'), contains('inválido'));
      });

      test('retorna erro para email sem domínio', () {
        expect(Validators.email('joao@'), contains('inválido'));
      });
    });

    group('password', () {
      test('retorna null para palavra-passe válida', () {
        expect(Validators.password('123456'), null);
      });

      test('retorna erro para palavra-passe curta', () {
        expect(Validators.password('12345'), contains('6 caracteres'));
      });

      test('retorna erro para palavra-passe vazia', () {
        expect(Validators.password(''), contains('obrigatória'));
      });
    });

    group('name', () {
      test('retorna null para nome válido', () {
        expect(Validators.name('João Silva'), null);
      });

      test('retorna erro para nome com 1 caractere', () {
        expect(Validators.name('A'), contains('2 caracteres'));
      });

      test('retorna erro para nome vazio', () {
        expect(Validators.name(''), contains('obrigatório'));
      });
    });

    group('exerciseSeries', () {
      test('retorna null para séries válidas', () {
        expect(Validators.exerciseSeries('3'), null);
      });

      test('retorna null para 10 séries (limite)', () {
        expect(Validators.exerciseSeries('10'), null);
      });

      test('retorna erro para 0 séries', () {
        expect(Validators.exerciseSeries('0'), contains('1-10'));
      });

      test('retorna erro para mais de 10 séries', () {
        expect(Validators.exerciseSeries('11'), contains('1-10'));
      });

      test('retorna erro para texto', () {
        expect(Validators.exerciseSeries('abc'), contains('1-10'));
      });

      test('retorna erro para valor vazio', () {
        expect(Validators.exerciseSeries(''), contains('Obrigatório'));
      });
    });

    group('exerciseReps', () {
      test('retorna null para repetições válidas', () {
        expect(Validators.exerciseReps('12'), null);
      });

      test('retorna null para 100 reps (limite)', () {
        expect(Validators.exerciseReps('100'), null);
      });

      test('retorna erro para 0 reps', () {
        expect(Validators.exerciseReps('0'), contains('1-100'));
      });

      test('retorna erro para mais de 100 reps', () {
        expect(Validators.exerciseReps('101'), contains('1-100'));
      });

      test('retorna erro para texto', () {
        expect(Validators.exerciseReps('abc'), contains('1-100'));
      });

      test('retorna erro para valor vazio', () {
        expect(Validators.exerciseReps(''), contains('Obrigatório'));
      });
    });

    group('calories', () {
      test('retorna null para calorias válidas', () {
        expect(Validators.calories('500'), null);
      });

      test('retorna null para calorias zero', () {
        expect(Validators.calories('0'), null);
      });

      test('aceita vírgula como decimal', () {
        expect(Validators.calories('250,5'), null);
      });

      test('retorna erro para valor negativo', () {
        expect(Validators.calories('-10'), contains('inválidas'));
      });

      test('retorna erro para texto', () {
        expect(Validators.calories('abc'), contains('inválidas'));
      });

      test('retorna erro para valor vazio', () {
        expect(Validators.calories(''), contains('Obrigatório'));
      });
    });

    group('positiveNumber', () {
      test('retorna null para número positivo', () {
        expect(Validators.positiveNumber('10.5'), null);
      });

      test('aceita vírgula como decimal', () {
        expect(Validators.positiveNumber('10,5'), null);
      });

      test('retorna erro para zero', () {
        expect(Validators.positiveNumber('0'), contains('maior que zero'));
      });

      test('retorna erro para texto', () {
        expect(Validators.positiveNumber('abc'), contains('número'));
      });
    });
  });
}
