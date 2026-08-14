import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/legacy.dart';
import '../../../core/errors/failures.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
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
  bool get needsPrivacyPolicy =>
      user != null &&
      user!.isAluno &&
      (!user!.hasAcceptedPrivacyPolicy ||
          user!.privacyPolicyVersion != PrivacyPolicyScreen.version);
}

/// Notifier de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel>? _profileSubscription;
  Timer? _accessTimer;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        if (user != null) {
          // Mostra loading enquanto carrega o UserModel do Firestore
          state = state.copyWith(status: AuthStatus.loading);
          try {
            final userModel = await _authRepository.getUserModel();
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
        await signOut();
        return;
      }
      if (state.status == AuthStatus.authenticated) {
        state = state.copyWith(user: userModel);
        _startAccessTimer();
      }
    }, onError: (_) {});
  }

  /// Termina sessão.
  Future<void> signOut() async {
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
    } on NetworkFailure {
      return 'Sem ligação à internet.';
    } catch (e) {
      return 'Erro ao enviar e-mail de recuperação.';
    }
  }

  /// Atualiza o userModel após login (ex: quando o stream deteta autenticação).
  Future<void> refreshUser() async {
    final fbUser = state.firebaseUser;
    if (fbUser == null) return;
    try {
      final userModel = await _authRepository.getUserModel();
      state = state.copyWith(user: userModel, status: AuthStatus.authenticated);
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _accessTimer?.cancel();
    super.dispose();
  }
}

/// Provider do AuthNotifier.
final authProvider = StateNotifierProvider.autoDispose<AuthNotifier, AuthState>(
  (ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    return AuthNotifier(authRepository);
  },
);
