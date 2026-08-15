import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/questionnaire_response_model.dart';
import 'package:gym_app/data/models/user_model.dart';

void main() {
  test('questionário preserva respostas e reconhece conclusão', () {
    final answers = {
      for (final id in QuestionnaireResponse.labels.keys) id: 'Resposta',
    };
    for (final id in const [
      'pathologiesHas',
      'familyPathologiesHas',
      'surgeryHas',
      'medicationHas',
      'supplementsHas',
      'allergiesHas',
    ]) {
      answers[id] = 'não';
    }
    expect(QuestionnaireResponse.labels['genero'], 'Sexo');
    final response = QuestionnaireResponse(
      version: QuestionnaireResponse.currentVersion,
      completedAt: DateTime(2026, 8, 15),
      answers: answers,
    );

    final decoded = QuestionnaireResponse.fromMap(response.toMap());

    expect(decoded.isCurrent, isTrue);
    expect(decoded.isComplete, isTrue);
    expect(decoded.answers['objective'], 'Resposta');
  });

  test('resposta sim exige os detalhes correspondentes', () {
    final answers = {
      for (final id in QuestionnaireResponse.labels.keys) id: 'Resposta',
    };
    answers['medicationHas'] = 'sim';
    answers['medication'] = '';
    answers['supplementsHas'] = 'não';
    answers['pathologiesHas'] = 'não';
    answers['familyPathologiesHas'] = 'não';
    answers['surgeryHas'] = 'não';
    answers['allergiesHas'] = 'não';

    final incomplete = QuestionnaireResponse(
      version: QuestionnaireResponse.currentVersion,
      completedAt: DateTime(2026, 8, 15),
      answers: answers,
    );
    expect(incomplete.isComplete, isFalse);

    answers['medication'] = 'Vitamina prescrita';
    expect(incomplete.isComplete, isTrue);
  });

  test('perfil antigo precisa da ficha inicial', () {
    final user = UserModel.fromMap('student-1', {
      'nome': 'Aluno',
      'email': 'aluno@example.com',
      'role': 'aluno',
    });

    expect(user.hasCompletedQuestionnaire, isFalse);
    expect(user.toMap().containsKey('questionnaireVersion'), isFalse);
  });

  test('versão gravada mantém a conclusão mesmo antes de chegar a data', () {
    final user = UserModel.fromMap('student-1', {
      'nome': 'Aluno',
      'email': 'aluno@example.com',
      'role': 'aluno',
      'questionnaireVersion': QuestionnaireResponse.currentVersion,
    });

    expect(user.hasCompletedQuestionnaire, isTrue);
  });
}
