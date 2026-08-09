import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/progress_model.dart';
import '../helpers/mock_timestamp.dart';

void main() {
  group('ProgressModel', () {
    const id = 'prog1';
    const userId = 'user123';
    final data = MockTimestamp(DateTime(2026, 7, 23));

    test('fromMap cria modelo com todos os campos', () {
      final map = {
        'data': data,
        'peso': 80.5,
        'medidas': {'cintura': 85.0, 'quadril': 100.0, 'braço': 35.0},
        'fotos': [
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
        ],
      };

      final progress = ProgressModel.fromMap(id, userId, map);

      expect(progress.id, id);
      expect(progress.userId, userId);
      expect(progress.data, data.toDate());
      expect(progress.peso, 80.5);
      expect(progress.medidas, {
        'cintura': 85.0,
        'quadril': 100.0,
        'braço': 35.0,
      });
      expect(progress.fotos, [
        'https://example.com/photo1.jpg',
        'https://example.com/photo2.jpg',
      ]);
    });

    test('fromMap usa valores padrão quando campos estão ausentes', () {
      final map = {'data': data};

      final progress = ProgressModel.fromMap(id, userId, map);

      expect(progress.peso, isNull);
      expect(progress.medidas, isEmpty);
      expect(progress.fotos, isEmpty);
    });

    test(
      'fromMap lê campos dinâmicos do Firestore sem perder URLs válidas',
      () {
        final map = <String, dynamic>{
          'data': data,
          'fotos': ['https://example.com/front.jpg', null, 123],
          'fotosPorPosicao': {
            ' frente ': ' https://example.com/front.jpg ',
            'Lado 1': null,
            'Costas': ' https://example.com/back.jpg ',
            'Vazio': ' ',
          },
        };

        final progress = ProgressModel.fromMap(id, userId, map);

        expect(progress.fotos, ['https://example.com/front.jpg', '', '']);
        expect(progress.fotosPorPosicao, {
          'frente': 'https://example.com/front.jpg',
          'Costas': 'https://example.com/back.jpg',
        });
      },
    );

    test('fromMap preserva fotos associadas a cada posição', () {
      final map = {
        'data': data,
        'fotos': [
          'https://example.com/front.jpg',
          '',
          'https://example.com/back.jpg',
          '',
        ],
        'fotosPorPosicao': {
          'Frente': 'https://example.com/front.jpg',
          'Costas': 'https://example.com/back.jpg',
        },
      };

      final progress = ProgressModel.fromMap(id, userId, map);

      expect(progress.fotosPorPosicao, {
        'Frente': 'https://example.com/front.jpg',
        'Costas': 'https://example.com/back.jpg',
      });
      expect(progress.fotos[1], isEmpty);
      expect(progress.fotos[3], isEmpty);
    });

    test('toMap converte para mapa corretamente', () {
      final date = DateTime(2026, 7, 23);
      final progress = ProgressModel(
        id: id,
        userId: userId,
        data: date,
        peso: 80.5,
        medidas: {'cintura': 85.0},
        fotos: ['https://example.com/photo.jpg'],
      );

      final map = progress.toMap();

      expect(map['userId'], userId);
      expect(map['data'], date);
      expect(map['peso'], 80.5);
      expect(map['medidas'], {'cintura': 85.0});
      expect(map['fotos'], ['https://example.com/photo.jpg']);
    });

    test('copyWith altera apenas campos especificados', () {
      final date = DateTime(2026, 7, 23);
      final progress = ProgressModel(
        id: id,
        userId: userId,
        data: date,
        peso: 80.0,
      );

      final updated = progress.copyWith(peso: 82.0);

      expect(updated.id, id);
      expect(updated.userId, userId);
      expect(updated.peso, 82.0);
      expect(updated.data, date);
    });

    test('copyWith clearPeso remove o peso', () {
      final date = DateTime(2026, 7, 23);
      final progress = ProgressModel(
        id: id,
        userId: userId,
        data: date,
        peso: 80.0,
      );

      final cleared = progress.copyWith(clearPeso: true);

      expect(cleared.peso, isNull);
    });

    test('construtor usa id vazio e listas vazias por padrão', () {
      final date = DateTime(2026, 7, 23);
      final progress = ProgressModel(userId: userId, data: date);

      expect(progress.id, '');
      expect(progress.medidas, isEmpty);
      expect(progress.fotos, isEmpty);
    });
  });
}
