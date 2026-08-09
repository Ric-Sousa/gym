import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/connectivity_service.dart';
import '../datasources/auth_datasource.dart';
import '../models/user_model.dart';
import 'payment_repository.dart';

/// Repository de autenticação.
class AuthRepository {
  final AuthDataSource _authDataSource;
  final ConnectivityService _connectivityService;
  final PaymentRepository _paymentRepository;

  AuthRepository({
    required AuthDataSource authDataSource,
    required ConnectivityService connectivityService,
    required PaymentRepository paymentRepository,
  }) : _authDataSource = authDataSource,
       _connectivityService = connectivityService,
       _paymentRepository = paymentRepository;

  User? get currentUser => _authDataSource.currentUser;
  Stream<User?> get authStateChanges => _authDataSource.authStateChanges;

  /// Observa o perfil para detetar desativação ou término agendado em tempo real.
  Stream<UserModel> userStream(String uid) {
    return _authDataSource.userDocStream(uid).map((doc) {
      if (!doc.exists) throw const DocumentNotFoundFailure();
      return UserModel.fromMap(uid, doc.data()! as Map<String, dynamic>);
    });
  }

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
      final userModel = UserModel.fromMap(
        uid,
        userDoc.data()! as Map<String, dynamic>,
      );
      if (!userModel.isAccessAllowed ||
          await _hasOverduePayment(userModel.uid)) {
        await _authDataSource.signOut();
        throw AuthFailure(
          message: userModel.accessStatus == 'Contrato terminado'
              ? 'O teu contrato terminou. Contacta o administrador.'
              : await _hasOverduePayment(userModel.uid)
              ? 'Existe uma mensalidade em atraso. Contacta o administrador.'
              : 'O teu perfil está inativo. Contacta o administrador.',
          code: 'account-inactive',
        );
      }
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

  /// Obtém o UserModel do Firestore para o utilizador atual.
  /// Usado quando o Firebase Auth restaura a sessão (ex: F5 no browser).
  Future<UserModel> getUserModel() async {
    final user = _authDataSource.currentUser;
    if (user == null)
      throw const AuthFailure(message: 'Sem sessão ativa', code: 'no-session');
    final userDoc = await _authDataSource.getUserDoc(user.uid);
    final userModel = UserModel.fromMap(
      user.uid,
      userDoc.data()! as Map<String, dynamic>,
    );
    if (!userModel.isAccessAllowed || await _hasOverduePayment(userModel.uid)) {
      throw AuthFailure(
        message: userModel.accessStatus == 'Contrato terminado'
            ? 'O teu contrato terminou. Contacta o administrador.'
            : await _hasOverduePayment(userModel.uid)
            ? 'Existe uma mensalidade em atraso. Contacta o administrador.'
            : 'O teu perfil está inativo. Contacta o administrador.',
        code: 'account-inactive',
      );
    }
    return userModel;
  }

  Future<bool> _hasOverduePayment(String userId) async {
    try {
      final payments = await _paymentRepository.getPayments(userId);
      return payments.any((payment) => payment.isOverdue);
    } catch (_) {
      // Sem conseguir confirmar o estado financeiro, falha fechada:
      // o acesso não deve ser concedido com informação incompleta.
      return true;
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
