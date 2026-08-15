import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gym_app/data/models/user_model.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/core/config/admin_theme.dart';

/// Mock AuthNotifier para testes de widget.
/// Permite controlar o estado de autenticação sem Firebase.
class MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  final Future<String?> Function(String email)? onPasswordReset;

  MockAuthNotifier(super.state, {this.onPasswordReset});

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> sendPasswordResetEmail(String email) async {
    return onPasswordReset?.call(email);
  }

  @override
  Future<void> refreshUser() async {}
}

/// Estados de autenticação pré-configurados para testes.
final adminAuthState = AuthState(
  status: AuthStatus.authenticated,
  user: UserModel(
    uid: 'test-admin-123',
    nome: 'Test Admin',
    email: 'admin@test.com',
    role: 'admin',
  ),
);

final alunoAuthState = AuthState(
  status: AuthStatus.authenticated,
  user: UserModel(
    uid: 'test-aluno-456',
    nome: 'Test Aluno',
    email: 'aluno@test.com',
    role: 'aluno',
    pesoAtual: 80.0,
    altura: 175.0,
  ),
);

const unauthenticatedState = AuthState(status: AuthStatus.unauthenticated);
const loadingState = AuthState(status: AuthStatus.loading);
const errorState = AuthState(
  status: AuthStatus.error,
  errorMessage: 'Email ou palavra-passe inválidos.',
);

/// Inicializa os dados de locale necessários para testes com DateFormat.
Future<void> initLocaleForTests() async {
  await initializeDateFormatting('pt', null);
}

/// Cria um ProviderScope + MaterialApp para testes de widget.
Widget createTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: [AdminThemeColors.dark],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        extensions: [AdminThemeColors.dark],
      ),
      home: child,
    ),
  );
}
