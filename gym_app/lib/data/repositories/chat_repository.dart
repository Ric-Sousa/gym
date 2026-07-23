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
  })  : _firestoreDataSource = firestoreDataSource,
        _connectivityService = connectivityService;

  /// Obtém o ID da sala de chat.
  String getChatRoomId(String alunoId, String personalId) {
    return _firestoreDataSource.getChatRoomId(alunoId, personalId);
  }

  /// Stream de mensagens.
  Stream<List<MessageModel>> messagesStream(String salaId) {
    return _firestoreDataSource.messagesStream(salaId).handleError((e) {
      if (e is ServerException) throw ServerFailure(message: e.message);
      throw const ServerFailure(message: 'Erro ao carregar mensagens');
    });
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
}
