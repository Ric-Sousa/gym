import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../models/user_model.dart';

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

  /// Stream do utilizador.
  Stream<UserModel> userStream(String uid) {
    return _firestoreDataSource.userStream(uid).handleError((e) {
      if (e is ServerException) throw ServerFailure(message: e.message);
      throw const ServerFailure(message: 'Erro ao carregar utilizador');
    });
  }

  /// Atualiza perfil do utilizador.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.updateUser(uid, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
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
}
