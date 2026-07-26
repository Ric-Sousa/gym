import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/message_model.dart';
import '../helpers/mock_timestamp.dart';

void main() {
  group('MessageModel', () {
    const id = 'msg123';
    const remetenteId = 'user456';
    const texto = 'Olá, como estás?';
    final timestamp = MockTimestamp(DateTime(2026, 7, 23, 14, 30));

    test('fromMap cria modelo com todos os campos', () {
      final map = {
        'remetenteId': remetenteId,
        'texto': texto,
        'timestamp': timestamp,
        'lida': true,
      };

      final message = MessageModel.fromMap(id, map);

      expect(message.id, id);
      expect(message.remetenteId, remetenteId);
      expect(message.texto, texto);
      expect(message.timestamp, timestamp.toDate());
      expect(message.lida, true);
    });

    test('fromMap usa valores padrão quando campos estão ausentes', () {
      final map = {
        'remetenteId': remetenteId,
        'texto': texto,
        'timestamp': timestamp,
      };

      final message = MessageModel.fromMap(id, map);

      expect(message.lida, false);
    });

    test('toMap converte para mapa corretamente', () {
      final date = DateTime(2026, 7, 23, 14, 30);
      final message = MessageModel(
        id: id,
        remetenteId: remetenteId,
        texto: texto,
        timestamp: date,
        lida: true,
      );

      final map = message.toMap();

      expect(map['remetenteId'], remetenteId);
      expect(map['texto'], texto);
      expect(map['timestamp'], date);
      expect(map['lida'], true);
    });

    test('copyWith altera apenas campos especificados', () {
      final date = DateTime(2026, 7, 23, 14, 30);
      final message = MessageModel(
        id: id,
        remetenteId: remetenteId,
        texto: texto,
        timestamp: date,
      );

      final updated = message.copyWith(texto: 'Tudo bem!', lida: true);

      expect(updated.id, id);
      expect(updated.remetenteId, remetenteId);
      expect(updated.texto, 'Tudo bem!');
      expect(updated.lida, true);
      expect(updated.timestamp, date);
    });

    test('construtor usa id vazio por padrão', () {
      final date = DateTime(2026, 7, 23, 14, 30);
      final message = MessageModel(
        remetenteId: remetenteId,
        texto: texto,
        timestamp: date,
      );

      expect(message.id, '');
    });
  });
}
