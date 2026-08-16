import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/questionnaire_config_model.dart';
import 'package:gym_app/data/models/questionnaire_response_model.dart';

void main() {
  test('configuração padrão mantém os três tópicos da ficha atual', () {
    final config = QuestionnaireConfig.defaultConfig();

    expect(config.topics.map((topic) => topic.title), [
      'Sobre ti',
      'Saúde e rotina',
      'Alimentação e objetivo',
    ]);
    expect(
      config.topics[1].questions
          .firstWhere((question) => question.id == 'medicationHas')
          .detailId,
      'medication',
    );
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

    expect(decoded.topics.single.questions.single.hasDetail, isTrue);
    expect(decoded.topics.single.questions.single.resolvedDetailId, 'goalDetails');
    expect(decoded.topics.single.questions.single.options, ['sim', 'não']);
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
