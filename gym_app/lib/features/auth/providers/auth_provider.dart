import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/legacy.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/services/fcm_service.dart';
import '../screens/privacy_policy_screen.dart';
import '../../../shared/providers/global_providers.dart';

/// Estado de autenticação.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Estado do AuthNotifier.
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final User? firebaseUser;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.firebaseUser,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    User? firebaseUser,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      firebaseUser: clearUser ? null : (firebaseUser ?? this.firebaseUser),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isAdmin => user?.isAdmin ?? false;
  bool get isAluno => user?.isAluno ?? false;

  /// A conclusão é permanente para esta ficha inicial.
  ///
  /// A configuração das perguntas pode ser editada pelo personal trainer sem
  /// invalidar a resposta já submetida. `questionnaireVersion` é guardado como
  /// marcador histórico da versão usada no preenchimento, não como uma versão
  /// que tenha de coincidir com a configuração atual.
  bool get needsQuestionnaire =>
      user != null && user!.isAluno && !user!.hasCompletedQuestionnaire;
  bool get needsPrivacyPolicy =>
      user != null &&
      user!.isAluno &&
      (!user!.hasAcceptedPrivacyPolicy ||
          user!.privacyPolicyVersion != PrivacyPolicyScreen.version);
}

/// Notifier de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final FCMService _fcmService;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel>? _profileSubscription;
  Timer? _accessTimer;
  Timer? _paymentReturnGraceTimer;
  bool _allowPaymentReturn = Uri.base.queryParameters['pagamento'] == 'sucesso';

  AuthNotifier(this._authRepository, this._fcmService)
    : super(const AuthState()) {
    if (_allowPaymentReturn) {
      // O webhook pode demorar alguns segundos a marcar o pagamento e a
      // renovar o contrato. Não expulsar a sessão durante esse retorno.
      _paymentReturnGraceTimer = Timer(const Duration(minutes: 5), () {
        if (state.user != null && !state.user!.isAccessAllowed) {
          signOut();
        }
        _allowPaymentReturn = false;
      });
    }
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        if (user != null) {
          // Mostra loading enquanto carrega o UserModel do Firestore
          state = state.copyWith(status: AuthStatus.loading);
          try {
            final userModel = await _authRepository.getUserModel(
              allowPaymentReturn: _allowPaymentReturn,
            );
            state = AuthState(
              status: AuthStatus.authenticated,
              user: userModel,
              firebaseUser: user,
            );
            _watchProfile(userModel.uid);
            _startAccessTimer();
          } on AuthFailure catch (e) {
            await _authRepository.signOut();
            state = AuthState(
              status: AuthStatus.error,
              errorMessage: e.message,
            );
          } catch (_) {
            // Se falhar ao carregar o UserModel, faz logout
            await _authRepository.signOut();
            state = const AuthState(status: AuthStatus.unauthenticated);
          }
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      },
      onError: (_) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      },
    );
  }

  /// Inicia sessão.
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final (userModel, userCredential) = await _authRepository.signIn(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: userModel,
        firebaseUser: userCredential.user,
      );
      _watchProfile(userModel.uid);
      _startAccessTimer();
    } on AuthFailure catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } on NetworkFailure {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sem ligação à internet.',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Ocorreu um erro inesperado.',
      );
    }
  }

  void _startAccessTimer() {
    _accessTimer?.cancel();
    final user = state.user;
    if (user == null || user.isAdmin || user.contractEndsAt == null) return;

    final delay = user.contractEndsAt!.difference(DateTime.now());
    if (delay.isNegative || delay == Duration.zero) {
      if (_allowPaymentReturn) return;
      signOut();
      return;
    }

    _accessTimer = Timer(delay, () {
      if (state.user != null && !state.user!.isAccessAllowed) {
        signOut();
      }
    });
  }

  void _watchProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _authRepository.userStream(uid).listen((
      userModel,
    ) async {
      if (!userModel.isAccessAllowed) {
        if (_allowPaymentReturn) {
          // Mantém a sessão enquanto o webhook Stripe sincroniza o novo
          // período. O timer de segurança encerra-a se isso não acontecer.
          if (state.status == AuthStatus.authenticated) {
            state = state.copyWith(user: userModel);
          }
          return;
        }
        await signOut();
        return;
      }

      _allowPaymentReturn = false;
      _paymentReturnGraceTimer?.cancel();
      _paymentReturnGraceTimer = null;
      if (state.status == AuthStatus.authenticated) {
        state = state.copyWith(user: userModel);
        _startAccessTimer();
      }
    }, onError: (_) {});
  }

  /// Termina sessão.
  Future<void> signOut() async {
    await _fcmService.removeToken();
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _accessTimer?.cancel();
    _accessTimer = null;
    await _authRepository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Envia e-mail de recuperação.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return null;
    } on NetworkFailure catch (e) {
      return e.message;
    } on AuthException catch (e) {
      return e.message;
    } on ServerException catch (e) {
      return e.message;
    } catch (_) {
      return 'Erro ao enviar e-mail de recuperação.';
    }
  }

  /// Atualiza o userModel após login (ex: quando o stream deteta autenticação).
  Future<void> refreshUser() async {
    final fbUser = state.firebaseUser;
    if (fbUser == null) return;
    try {
      final userModel = await _authRepository.getUserModel(
        allowPaymentReturn: _allowPaymentReturn,
      );
      state = state.copyWith(user: userModel, status: AuthStatus.authenticated);
    } catch (_) {}
  }

  /// Evita reabrir a ficha entre a confirmaÃ§Ã£o do servidor e a atualizaÃ§Ã£o
  /// do listener do Firestore.
  void markQuestionnaireCompleted(String version) {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(
      user: user.copyWith(
        questionnaireCompletedAt: DateTime.now(),
        questionnaireVersion: version,
      ),
      status: AuthStatus.authenticated,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _accessTimer?.cancel();
    _paymentReturnGraceTimer?.cancel();
    super.dispose();
  }
}

/// Provider do AuthNotifier.
final authProvider = StateNotifierProvider.autoDispose<AuthNotifier, AuthState>(
  (ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    return AuthNotifier(authRepository, ref.watch(fcmServiceProvider));
  },
);
