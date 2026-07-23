import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/connectivity_service.dart';
import '../datasources/auth_datasource.dart';
import '../models/user_model.dart';

/// Repository de autenticação.
class AuthRepository {
  final AuthDataSource _authDataSource;
  final ConnectivityService _connectivityService;

  AuthRepository({
    required AuthDataSource authDataSource,
    required ConnectivityService connectivityService,
  })  : _authDataSource = authDataSource,
        _connectivityService = connectivityService;

  User? get currentUser => _authDataSource.currentUser;
  Stream<User?> get authStateChanges => _authDataSource.authStateChanges;

  /// Inicia sessão com e-mail e palavra-passe.
  /// Retorna o UserModel do Firestore após autenticação bem-sucedida.
  Future<(UserModel, UserCredential)> signIn({
    required String email,
    required String password,
  }) async {
    if (!await _connectivityService.isConnected) {
      throw NetworkFailure();
    }

    final userCredential = await _authDataSource.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;
    try {
      final userDoc = await _authDataSource.getUserDoc(uid);
      final userModel = UserModel.fromMap(uid, userDoc.data()! as Map<String, dynamic>);
      return (userModel, userCredential);
    } on DocumentNotFoundException {
      // Logout se o documento de utilizador não existir
      await _authDataSource.signOut();
      throw AuthFailure(
        message: 'Documento de utilizador não encontrado. Contacta o suporte.',
        code: 'no-user-doc',
      );
    }
  }

  /// Termina sessão.
  Future<void> signOut() async {
    await _authDataSource.signOut();
  }

  /// Envia e-mail de recuperação de palavra-passe.
  Future<void> sendPasswordResetEmail(String email) async {
    if (!await _connectivityService.isConnected) {
      throw NetworkFailure();
    }
    await _authDataSource.sendPasswordResetEmail(email);
  }
}
