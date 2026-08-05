import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/message_model.dart';
import 'package:gym_app/shared/utils/new_message_detector.dart';

class _DetectorHost with NewMessageDetector {}

MessageModel _message(String id, String sender) {
  return MessageModel(
    id: id,
    remetenteId: sender,
    texto: 'Mensagem $id',
    timestamp: DateTime(2026, 8, 4, 12, 0),
  );
}

void main() {
  test('deteta a primeira mensagem quando a conversa começou vazia', () {
    final detector = _DetectorHost();
    final received = <String>[];

    detector.detectNewMessages(
      <MessageModel>[],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );
    detector.detectNewMessages(
      [_message('first', 'other')],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );

    expect(received, ['first']);
  });

  test('ignora carga inicial e não repete a mesma mensagem', () {
    final detector = _DetectorHost();
    final received = <String>[];
    final initial = _message('initial', 'other');

    detector.detectNewMessages(
      [initial],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );
    detector.detectNewMessages(
      [initial],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );
    detector.detectNewMessages(
      [initial, _message('next', 'other')],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );

    expect(received, ['next']);
  });

  test('não considera mensagem enviada pelo próprio utilizador como recebida', () {
    final detector = _DetectorHost();
    final received = <String>[];

    detector.detectNewMessages(<MessageModel>[], 'me');
    detector.detectNewMessages(
      [_message('mine', 'me')],
      'me',
      playSound: false,
      onNewMessage: (message) => received.add(message.id),
    );

    expect(received, isEmpty);
  });
}
