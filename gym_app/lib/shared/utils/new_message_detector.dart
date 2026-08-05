import '../../core/services/sound_service.dart';
import '../../data/models/message_model.dart';

/// Mixin que detecta novas mensagens de chat e toca um chime de notificação.
///
/// Mantém um registo interno dos IDs já vistos para evitar tocar o som
/// na carga inicial ou em mensagens já conhecidas.
///
/// Uso:
/// ```dart
/// class _ChatState extends ConsumerState<ChatScreen> with NewMessageDetector {
///   // No callback de dados do stream:
///   detectNewMessages(messages, myUserId);
///   // Para reset ao trocar de conversa:
///   resetDetector();
/// }
/// ```
mixin NewMessageDetector {
  final Set<String> _seenMessageIds = {};
  bool _initialLoadDone = false;

  /// Analisa a lista de [messages] e toca o chime para mensagens
  /// novas que não sejam do utilizador atual ([myId]).
  ///
  /// Se [playSound] for false, não toca o som (ex: quando o user
  /// está dentro do chat e já está a ver as mensagens).
  void detectNewMessages(
    List<MessageModel> messages,
    String myId, {
    bool playSound = true,
    void Function(MessageModel)? onNewMessage,
  }) {
    // Mesmo uma fotografia vazia conta como a carga inicial. Sem esta marca,
    // a primeira mensagem de uma conversa nova seria confundida com hidratação
    // e o som seria perdido.
    if (!_initialLoadDone) {
      // Primeira carga: apenas regista os IDs, sem tocar som
      _seenMessageIds.addAll(messages.map((m) => m.id));
      _initialLoadDone = true;
      return;
    }

    for (final msg in messages) {
      if (!_seenMessageIds.contains(msg.id)) {
        _seenMessageIds.add(msg.id);
        // Toca o chime apenas para mensagens de outros remetentes. O callback
        // é útil para testes e para integrações que precisam reagir ao evento
        // sem duplicar o mecanismo de deduplicação por ID.
        if (msg.remetenteId != myId) {
          onNewMessage?.call(msg);
          if (playSound) SoundService().playNotificationChime();
        }
      }
    }
  }

  /// Reseta o estado interno (ex: ao trocar de conversa).
  void resetDetector() {
    _seenMessageIds.clear();
    _initialLoadDone = false;
  }
}
