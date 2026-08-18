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

  /// Garante que uma sala direta existe antes de um upload associado.
  Future<void> ensureChatRoom(
    String salaId,
    List<String> participantIds,
  ) async {
    try {
      await _firestoreDataSource.ensureChatRoom(salaId, participantIds);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream de mensagens.
  Stream<List<MessageModel>> messagesStream(String salaId) {
    // Preserva erros de permissão/rede para o provider poder expor o estado
    // de erro, em vez de transformar uma falha numa conversa aparentemente vazia.
    return _firestoreDataSource.messagesStream(salaId);
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
  Future<void> sendMessage(
    String salaId,
    MessageModel message, {
    List<String>? participantIds,
  }) async {
    if (!await _connectivityService.isConnected) throw NetworkFailure();
    try {
      await _firestoreDataSource.sendMessage(
        salaId,
        message.toMap(),
        participantIds: participantIds,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream que indica se o outro participante está a digitar.
  Stream<String?> typingStream(String salaId, String myUserId) {
    return _firestoreDataSource.typingStream(salaId, myUserId);
  }

  /// Define ou remove o estado de digitação.
  Future<void> setTypingStatus(
    String salaId,
    String userId,
    bool isTyping, {
    List<String>? participantIds,
  }) async {
    await _firestoreDataSource.setTypingStatus(
      salaId,
      userId,
      isTyping,
      participantIds: participantIds,
    );
  }
}
