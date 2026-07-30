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
  void detectNewMessages(List<MessageModel> messages, String myId) {
    if (messages.isEmpty) return;

    if (!_initialLoadDone) {
      // Primeira carga: apenas regista os IDs, sem tocar som
      _seenMessageIds.addAll(messages.map((m) => m.id));
      _initialLoadDone = true;
      return;
    }

    for (final msg in messages) {
      if (!_seenMessageIds.contains(msg.id)) {
        _seenMessageIds.add(msg.id);
        // Toca o chime apenas para mensagens de outros remetentes
        if (msg.remetenteId != myId) {
          SoundService().playNotificationChime();
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
