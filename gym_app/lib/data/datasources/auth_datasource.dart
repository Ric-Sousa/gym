import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/exceptions.dart';

/// Data source para autenticação Firebase.
class AuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Obtém o utilizador autenticado atualmente.
  User? get currentUser => _auth.currentUser;

  /// Stream de alterações de estado de autenticação.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inicia sessão com e-mail e palavra-passe.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro no servidor');
    } catch (e) {
      throw ServerException(message: 'Erro inesperado: $e');
    }
  }

  /// Termina sessão.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao terminar sessão');
    }
  }

  /// Envia e-mail de recuperação de palavra-passe.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseCode(e.code);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro no servidor');
    }
  }

  /// Obtém o documento do utilizador do Firestore.
  Future<DocumentSnapshot> getUserDoc(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        throw DocumentNotFoundException(
          message: 'Documento de utilizador não encontrado',
        );
      }
      return doc;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter utilizador');
    }
  }
}
