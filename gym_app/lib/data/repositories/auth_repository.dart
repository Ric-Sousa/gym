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
      final hasOverdue = !userModel.isAdmin &&
          await _hasOverduePayment(userModel.uid);
      if (!userModel.isAdmin && (!userModel.isAccessAllowed || hasOverdue)) {
        await _authDataSource.signOut();
        throw AuthFailure(
          message: userModel.accessStatus == 'Contrato terminado'
              ? 'O teu contrato terminou. Usa o portal enviado por e-mail para regularizar.'
              : hasOverdue
              ? 'Existe uma mensalidade em atraso. Usa o portal enviado por e-mail para regularizar.'
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
    } on ServerFailure {
      await _authDataSource.signOut();
      rethrow;
    }
  }

  /// Obtém o UserModel do Firestore para o utilizador atual.
  /// Usado quando o Firebase Auth restaura a sessão (ex: F5 no browser).
  Future<UserModel> getUserModel({bool allowPaymentReturn = false}) async {
    final user = _authDataSource.currentUser;
    if (user == null)
      throw const AuthFailure(message: 'Sem sessão ativa', code: 'no-session');
    final userDoc = await _authDataSource.getUserDoc(user.uid);
    final userModel = UserModel.fromMap(
      user.uid,
      userDoc.data()! as Map<String, dynamic>,
    );
    final hasOverdue = !userModel.isAdmin &&
        !allowPaymentReturn &&
        await _hasOverduePayment(userModel.uid);
    // Ao regressar do Checkout, o webhook pode ainda estar a atualizar o
    // pagamento/contrato. Preservamos a sessão durante esse curto intervalo;
    // fora deste retorno, os bloqueios continuam a ser aplicados normalmente.
    final manuallyDeactivated = !userModel.isActive;
    if (!userModel.isAdmin &&
        (!allowPaymentReturn &&
            (manuallyDeactivated || !userModel.isAccessAllowed || hasOverdue))) {
      throw AuthFailure(
        message: userModel.accessStatus == 'Contrato terminado'
            ? 'O teu contrato terminou. Usa o portal enviado por e-mail para regularizar.'
            : hasOverdue
            ? 'Existe uma mensalidade em atraso. Usa o portal enviado por e-mail para regularizar.'
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
      // Não confundir indisponibilidade do Firestore com uma dívida real. O
      // login é interrompido com erro técnico e pode ser repetido, sem marcar
      // a conta como inadimplente localmente.
      throw const ServerFailure(
        message: 'Não foi possível confirmar o estado dos pagamentos. Tenta novamente.',
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
