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

    test('fromMap não quebra quando timestamp está ausente', () {
      final message = MessageModel.fromMap(id, {
        'remetenteId': remetenteId,
        'texto': texto,
      });

      expect(message.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('fromMap aceita timestamp ISO e milissegundos', () {
      final iso = MessageModel.fromMap(id, {
        'remetenteId': remetenteId,
        'texto': texto,
        'timestamp': '2026-07-23T14:30:00.000Z',
      });
      final millis = MessageModel.fromMap(id, {
        'remetenteId': remetenteId,
        'texto': texto,
        'timestamp': 1780000000000,
      });

      expect(iso.timestamp, DateTime.parse('2026-07-23T14:30:00.000Z'));
      expect(
        millis.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1780000000000),
      );
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

    test('suporta mensagens de áudio sem quebrar mensagens de texto', () {
      final audioTimestamp = MockTimestamp(DateTime(2026, 7, 23, 15, 0));
      final audio = MessageModel.fromMap('audio1', {
        'remetenteId': remetenteId,
        'texto': '',
        'timestamp': audioTimestamp,
        'lida': false,
        'audioUrl': 'https://example.com/audio.m4a',
        'audioDurationMs': 4200,
      });

      expect(audio.isAudio, true);
      expect(audio.audioUrl, 'https://example.com/audio.m4a');
      expect(audio.audioDurationMs, 4200);
      expect(audio.toMap()['audioUrl'], 'https://example.com/audio.m4a');
      expect(audio.toMap()['audioDurationMs'], 4200);
    });

    test('reconhece e serializa anexos de imagem', () {
      final image = MessageModel.fromMap('image1', {
        'remetenteId': remetenteId,
        'texto': '',
        'timestamp': timestamp,
        'lida': false,
        'attachmentUrl': 'https://example.com/image.jpg',
        'attachmentName': 'image.jpg',
        'attachmentType': 'image/jpeg',
      });

      expect(image.isAttachment, true);
      expect(image.attachmentUrl, 'https://example.com/image.jpg');
      expect(image.attachmentName, 'image.jpg');
      expect(image.attachmentType, 'image/jpeg');
      expect(image.toMap()['attachmentUrl'], 'https://example.com/image.jpg');
      expect(image.toMap()['texto'], isEmpty);
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
