import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/connectivity_service.dart';
import '../datasources/firestore_datasource.dart';
import '../models/message_model.dart';

/// Repository para o chat.
class ChatRepository {
  final FirestoreDataSource _firestoreDataSource;
  final ConnectivityService _connectivityService;

  ChatRepository({
    required FirestoreDataSource firestoreDataSource,
    required ConnectivityService connectivityService,
  }) : _firestoreDataSource = firestoreDataSource,
       _connectivityService = connectivityService;

  /// Obtém o ID da sala de chat.
  String getChatRoomId(String alunoId, String personalId) {
    return _firestoreDataSource.getChatRoomId(alunoId, personalId);
  }

  /// Stream de mensagens.
  Stream<List<MessageModel>> messagesStream(String salaId) {
    return _firestoreDataSource.messagesStream(salaId).handleError((e, stack) {
      // ignore: avoid_print
      print('Chat messagesStream error for $salaId: $e');
      // Swallow errors — don't re-throw, keep stream alive.
    });
  }

  /// Marca como lidas as mensagens recebidas até [readAt].
  Future<void> markMessagesAsRead(
    String salaId,
    String userId,
    DateTime readAt, {
    bool persistConversationCursor = false,
  }) async {
    try {
      await _firestoreDataSource.markMessagesAsRead(
        salaId,
        userId,
        readAt,
        persistConversationCursor: persistConversationCursor,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Envia uma mensagem.
  Future<void> sendMessage(String salaId, MessageModel message) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.sendMessage(salaId, message.toMap());
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream que indica se o outro participante está a digitar.
  Stream<String?> typingStream(String salaId, String myUserId) {
    return _firestoreDataSource.typingStream(salaId, myUserId).handleError((
      _,
      __,
    ) {
      // ignore: avoid_print
      print('Typing stream error for $salaId');
    });
  }

  /// Define ou remove o estado de digitação.
  Future<void> setTypingStatus(
    String salaId,
    String userId,
    bool isTyping,
  ) async {
    await _firestoreDataSource.setTypingStatus(salaId, userId, isTyping);
  }
}
