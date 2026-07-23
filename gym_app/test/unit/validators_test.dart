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
