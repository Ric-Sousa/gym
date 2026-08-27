import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/user_model.dart';
import '../models/questionnaire_response_model.dart';
import '../models/questionnaire_config_model.dart';

/// Repository para operações de utilizador.
class UserRepository {
  final FirestoreDataSource _firestoreDataSource;

  UserRepository({required FirestoreDataSource firestoreDataSource})
    : _firestoreDataSource = firestoreDataSource;

  /// Obtém modelo de utilizador.
  Future<UserModel> getUser(String uid) async {
    try {
      return await _firestoreDataSource.getUser(uid);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    } on DocumentNotFoundException {
      throw const DocumentNotFoundFailure();
    }
  }

  /// Obtém apenas os dados públicos usados no chat.
  Future<UserModel> getChatProfile(String uid) async {
    try {
      return await _firestoreDataSource.getChatProfile(uid);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    } on DocumentNotFoundException {
      throw const DocumentNotFoundFailure();
    }
  }

  /// Stream do utilizador.
  Stream<UserModel> userStream(String uid) {
    return _firestoreDataSource.userStream(uid).handleError((e) {
      if (e is ServerException) throw ServerFailure(message: e.message);
      throw const ServerFailure(message: 'Erro ao carregar utilizador');
    });
  }

  /// Atualiza o perfil público mínimo usado pelos chats.
  Future<void> updateChatProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.updateChatProfile(uid, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Atualiza perfil do utilizador.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.updateUser(uid, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Obtém as respostas da ficha de anamnese de um aluno.
  Future<QuestionnaireResponse?> getQuestionnaire(String uid) async {
    try {
      return await _firestoreDataSource.getQuestionnaire(uid);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Guarda a ficha de anamnese preenchida pelo aluno.
  Future<void> saveQuestionnaire(
    String uid,
    QuestionnaireResponse response, {
    String? nome,
    String? genero,
    double? peso,
    double? altura,
    DateTime? dataNascimento,
  }) async {
    try {
      await _firestoreDataSource.saveQuestionnaire(
        uid,
        response,
        nome: nome,
        genero: genero,
        peso: peso,
        altura: altura,
        dataNascimento: dataNascimento,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Obtém a nota privada do administrador para um cliente.
  Future<String> getAdminNote(String uid) async {
    try {
      return await _firestoreDataSource.getAdminNote(uid);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Guarda a nota privada do administrador para um cliente.
  Future<void> setAdminNote(String uid, String note, {String? adminId}) async {
    try {
      await _firestoreDataSource.setAdminNote(uid, note, adminId: adminId);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream de todos os alunos (admin).
  Stream<List<UserModel>> watchAllAlunos() {
    return _firestoreDataSource.watchAllAlunos();
  }

  /// Stream da configuração editável do questionário.
  Stream<QuestionnaireConfig> questionnaireConfigStream() {
    return _firestoreDataSource.questionnaireConfigStream();
  }

  /// Guarda a configuração editável do questionário.
  Future<void> saveQuestionnaireConfig(QuestionnaireConfig config) async {
    try {
      await _firestoreDataSource.saveQuestionnaireConfig(config);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Stream da ficha de anamnese de um aluno.
  Stream<QuestionnaireResponse?> questionnaireStream(String uid) {
    return _firestoreDataSource.questionnaireStream(uid);
  }

  /// Lista todos os alunos (admin).
  Future<List<UserModel>> getAllAlunos() async {
    try {
      return await _firestoreDataSource.getAllAlunos();
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Pesquisa alunos por nome (admin).
  Future<List<UserModel>> searchAlunos(String query) async {
    try {
      return await _firestoreDataSource.searchAlunos(query);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Obtém nomes de utilizadores por lista de UIDs (batch).
  Future<Map<String, String>> getUserNames(List<String> uids) async {
    try {
      return await _firestoreDataSource.getUserNames(uids);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
