import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/user_model.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';

void main() {
  UserModel aluno({String? questionnaireVersion}) => UserModel(
        uid: 'student-1',
        nome: 'Aluno',
        email: 'aluno@example.com',
        questionnaireVersion: questionnaireVersion,
      );

  test('não reabre a ficha quando já existe um marcador de conclusão', () {
    final state = AuthState(
      status: AuthStatus.authenticated,
      user: aluno(questionnaireVersion: 'questionnaire-version-anterior'),
    );

    expect(state.needsQuestionnaire, isFalse);
  });

  test('não reabre a ficha quando a versão concluída é diferente da atual', () {
    final state = AuthState(
      status: AuthStatus.authenticated,
      user: aluno(questionnaireVersion: 'versao-criada-antes-de-editar-perguntas'),
    );

    expect(state.needsQuestionnaire, isFalse);
  });

  test('mostra a ficha quando o aluno ainda não tem conclusão', () {
    final state = AuthState(
      status: AuthStatus.authenticated,
      user: aluno(),
    );

    expect(state.needsQuestionnaire, isTrue);
  });

  test('administradores nunca precisam da ficha do aluno', () {
    final state = AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(
        uid: 'admin-1',
        nome: 'Admin',
        email: 'admin@example.com',
        role: 'admin',
      ),
    );

    expect(state.needsQuestionnaire, isFalse);
  });
}
