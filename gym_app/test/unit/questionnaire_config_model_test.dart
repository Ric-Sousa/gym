import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/questionnaire_config_model.dart';
import 'package:gym_app/data/models/questionnaire_response_model.dart';

void main() {
  test('configuração padrão mantém os três tópicos da ficha atual', () {
    final config = QuestionnaireConfig.defaultConfig();

    expect(config.topics.map((topic) => topic.title), [
      'Dados do aluno',
      'Sobre ti',
      'Saúde e rotina',
      'Alimentação e objetivo',
    ]);
    expect(config.topics.first.isProtected, isTrue);
    expect(config.topics.first.questions.map((question) => question.id), [
      'birthDate',
      'nome',
      'genero',
      'peso',
      'altura',
    ]);
    expect(
      config.topics
          .firstWhere((topic) => topic.id == 'health')
          .questions
          .firstWhere((question) => question.id == 'medicationHas')
          .detailId,
      'medication',
    );
  });

  test('configuração reinsere e protege os dados do aluno ao ler uma configuração antiga', () {
    final decoded = QuestionnaireConfig.fromMap(const {
      'version': QuestionnaireConfig.version,
      'topics': [
        {
          'id': 'profile',
          'title': 'Perfil',
          'questions': [
            {'id': 'nome', 'label': 'Nome antigo', 'type': 'text'},
          ],
        },
      ],
    });

    expect(decoded.topics.first.isProtected, isTrue);
    expect(decoded.topics.first.title, 'Dados do aluno');
    expect(
      decoded.topics.first.questions
          .firstWhere((question) => question.id == 'nome')
          .label,
      'Nome',
    );
    expect(decoded.topics.skip(1).expand((topic) => topic.questions),
        isNot(contains(predicate<QuestionnaireQuestion>((question) =>
            QuestionnaireConfig.protectedQuestionIds.contains(question.id)))));
  });

  test('configuração preserva perguntas e campos de detalhe', () {
    const config = QuestionnaireConfig(
      topics: [
        QuestionnaireTopic(
          id: 'goals',
          title: 'Objetivos',
          questions: [
            QuestionnaireQuestion(
              id: 'goal',
              label: 'Qual é o teu objetivo?',
              type: 'binary',
              options: ['sim', 'não'],
              detailId: 'goalDetails',
              detailLabel: 'Explica o teu objetivo',
            ),
          ],
        ),
      ],
    );

    final decoded = QuestionnaireConfig.fromMap(config.toMap());

    final goals = decoded.topics.firstWhere((topic) => topic.id == 'goals');
    expect(goals.questions.single.hasDetail, isTrue);
    expect(goals.questions.single.resolvedDetailId, 'goalDetails');
    expect(goals.questions.single.options, ['sim', 'não']);
  });

  test('resposta dinâmica exige o detalhe quando escolhe sim', () {
    const config = QuestionnaireConfig(
      topics: [
        QuestionnaireTopic(
          id: 'health',
          title: 'Saúde',
          questions: [
            QuestionnaireQuestion(
              id: 'usesMedication',
              label: 'Tomas medicação?',
              type: 'binary',
              options: ['sim', 'não'],
              detailId: 'medicationDetails',
              detailLabel: 'Qual?',
            ),
          ],
        ),
      ],
    );
    final response = QuestionnaireResponse(
      version: QuestionnaireConfig.version,
      completedAt: DateTime(2026, 8, 16),
      answers: const {'usesMedication': 'sim'},
    );

    expect(config.isResponseComplete(response), isFalse);
    final completed = QuestionnaireResponse(
      version: response.version,
      completedAt: response.completedAt,
      answers: const {
        'usesMedication': 'sim',
        'medicationDetails': 'Vitamina prescrita',
      },
    );
    expect(config.isResponseComplete(completed), isTrue);
  });
}
