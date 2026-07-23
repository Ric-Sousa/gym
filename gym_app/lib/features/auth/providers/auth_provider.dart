import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
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
      firebaseUser: clearUser
          ? null
          : (firebaseUser ?? this.firebaseUser),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isAdmin => user?.isAdmin ?? false;
  bool get isAluno => user?.isAluno ?? false;
}

/// Notifier de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) {
        if (user != null) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            firebaseUser: user,
          );
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
    } on AuthFailure catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
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

  /// Termina sessão.
  Future<void> signOut() async {
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
    if (state.firebaseUser == null) return;
    try {
      final authDS = _authRepository;
      // Força o reload do user model
      state = state.copyWith(
        status: AuthStatus.authenticated,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider do AuthNotifier.
final authProvider =
    StateNotifierProvider.autoDispose<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
