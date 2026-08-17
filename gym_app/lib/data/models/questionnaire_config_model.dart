import 'questionnaire_response_model.dart';

/// Tipo de campo apresentado no questionário inicial.
class QuestionnaireQuestion {
  final String id;
  final String label;
  final String type; // text, choice, binary, date
  final List<String> options;
  final bool required;
  final bool multiline;
  final String? hint;
  final String? detailId;
  final String? detailLabel;

  const QuestionnaireQuestion({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = true,
    this.multiline = false,
    this.hint,
    this.detailId,
    this.detailLabel,
  });

  bool get isBinary => type == 'binary';
  bool get hasDetail =>
      isBinary &&
      detailLabel != null &&
      detailLabel!.trim().isNotEmpty;

  String get resolvedDetailId => detailId ?? '${id}_details';

  factory QuestionnaireQuestion.fromMap(Map<String, dynamic> map) {
    return QuestionnaireQuestion(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      options: List<String>.from(map['options'] as List? ?? const []),
      required: map['required'] as bool? ?? true,
      multiline: map['multiline'] as bool? ?? false,
      hint: map['hint']?.toString(),
      detailId: map['detailId']?.toString(),
      detailLabel: map['detailLabel']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'type': type,
        'options': options,
        'required': required,
        'multiline': multiline,
        if (hint != null && hint!.trim().isNotEmpty) 'hint': hint,
        if (detailId != null && detailId!.trim().isNotEmpty)
          'detailId': detailId,
        if (detailLabel != null && detailLabel!.trim().isNotEmpty)
          'detailLabel': detailLabel,
      };

  QuestionnaireQuestion copyWith({
    String? id,
    String? label,
    String? type,
    List<String>? options,
    bool? required,
    bool? multiline,
    String? hint,
    String? detailId,
    String? detailLabel,
  }) {
    return QuestionnaireQuestion(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      required: required ?? this.required,
      multiline: multiline ?? this.multiline,
      hint: hint ?? this.hint,
      detailId: detailId ?? this.detailId,
      detailLabel: detailLabel ?? this.detailLabel,
    );
  }
}

class QuestionnaireTopic {
  final String id;
  final String title;
  final String description;
  final List<QuestionnaireQuestion> questions;
  final bool isProtected;

  const QuestionnaireTopic({
    required this.id,
    required this.title,
    this.description = '',
    this.questions = const [],
    this.isProtected = false,
  });

  factory QuestionnaireTopic.fromMap(Map<String, dynamic> map) {
    return QuestionnaireTopic(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      questions: (map['questions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => QuestionnaireQuestion.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((question) => question.id.isNotEmpty)
          .toList(),
      isProtected: map['protected'] as bool? ?? map['locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'questions': questions.map((question) => question.toMap()).toList(),
        if (isProtected) 'protected': true,
      };

  QuestionnaireTopic copyWith({
    String? id,
    String? title,
    String? description,
    List<QuestionnaireQuestion>? questions,
    bool? isProtected,
  }) {
    return QuestionnaireTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      isProtected: isProtected ?? this.isProtected,
    );
  }
}

class QuestionnaireConfig {
  static const documentId = 'active';
  static const version = QuestionnaireResponse.currentVersion;
  static const protectedTopicId = 'student-data';
  static const protectedQuestionIds = <String>{
    'birthDate',
    'nome',
    'genero',
    'peso',
    'altura',
  };

  final String versionId;
  final List<QuestionnaireTopic> topics;

  const QuestionnaireConfig({
    this.versionId = version,
    this.topics = const [],
  });

  static const protectedStudentDataTopic = QuestionnaireTopic(
        id: protectedTopicId,
        title: 'Dados do aluno',
        description: 'Dados obrigatórios usados para preencher a ficha do aluno.',
        isProtected: true,
        questions: [
          QuestionnaireQuestion(
            id: 'birthDate',
            label: 'Data de aniversário',
            type: 'date',
          ),
          QuestionnaireQuestion(
            id: 'nome',
            label: 'Nome',
            type: 'text',
          ),
          QuestionnaireQuestion(
            id: 'genero',
            label: 'Sexo',
            type: 'choice',
            options: ['masculino', 'feminino'],
          ),
          QuestionnaireQuestion(
            id: 'peso',
            label: 'Peso (kg)',
            type: 'text',
            hint: 'Ex.: 75',
          ),
          QuestionnaireQuestion(
            id: 'altura',
            label: 'Altura (cm)',
            type: 'text',
            hint: 'Ex.: 175',
          ),
        ],
      );

  static List<QuestionnaireTopic> _withProtectedTopic(
    List<QuestionnaireTopic> topics,
  ) {
    final sanitized = topics
        .where((topic) => topic.id != protectedTopicId)
        .map(
          (topic) => topic.copyWith(
            questions: topic.questions
                .where((question) => !protectedQuestionIds.contains(question.id))
                .toList(),
          ),
        )
        .toList();
    return [protectedStudentDataTopic, ...sanitized];
  }

  factory QuestionnaireConfig.fromMap(Map<String, dynamic> map) {
    return QuestionnaireConfig(
      versionId: map['version']?.toString() ?? version,
      topics: _withProtectedTopic(
        (map['topics'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => QuestionnaireTopic.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((topic) => topic.id.isNotEmpty && topic.title.isNotEmpty)
            .toList(),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'version': versionId,
        'topics': _withProtectedTopic(topics)
            .map((topic) => topic.toMap())
            .toList(),
      };

  bool isResponseComplete(QuestionnaireResponse response) {
    for (final topic in topics) {
      for (final question in topic.questions) {
        final value = response.answers[question.id]?.trim() ?? '';
        if (question.required && value.isEmpty) return false;
        if (question.isBinary && value.toLowerCase() == 'sim' && question.hasDetail &&
            (response.answers[question.resolvedDetailId]?.trim().isEmpty ?? true)) {
          return false;
        }
      }
    }
    return true;
  }

  QuestionnaireConfig copyWith({
    String? versionId,
    List<QuestionnaireTopic>? topics,
  }) {
    return QuestionnaireConfig(
      versionId: versionId ?? this.versionId,
      topics: _withProtectedTopic(topics ?? this.topics),
    );
  }

  /// Configuração inicial equivalente ao formulário que já existia.
  static QuestionnaireConfig defaultConfig() {
    return const QuestionnaireConfig(
      topics: [
        protectedStudentDataTopic,
        QuestionnaireTopic(
          id: 'profile',
          title: 'Sobre ti',
          description: 'Informação básica para personalizar o acompanhamento.',
          questions: [
            QuestionnaireQuestion(id: 'profession', label: 'Profissão', type: 'text', hint: 'Ex.: estudante, professora, motorista'),
            QuestionnaireQuestion(id: 'activity', label: 'Já praticas ginásio ou algum desporto?', type: 'choice', options: ['Sim, regularmente', 'Às vezes', 'Ainda não']),
            QuestionnaireQuestion(id: 'sedentary', label: 'Consideras-te uma pessoa sedentária?', type: 'binary', options: ['sim', 'não']),
            QuestionnaireQuestion(id: 'meals', label: 'Quantas refeições costumas fazer por dia?', type: 'choice', options: ['1–2', '3', '4–5', '6 ou mais']),
            QuestionnaireQuestion(id: 'water', label: 'Que quantidade de água bebes diariamente?', type: 'choice', options: ['Menos de 1 L', '1–2 L', '2–3 L', 'Mais de 3 L']),
            QuestionnaireQuestion(id: 'sleep', label: 'Em média, quantas horas dormes?', type: 'choice', options: ['Menos de 5 h', '5–6 h', '7–8 h', 'Mais de 8 h']),
          ],
        ),
        QuestionnaireTopic(
          id: 'health',
          title: 'Saúde e rotina',
          description: 'Assinala Sim ou Não. Se responderes Sim, descreve a situação.',
          questions: [
            QuestionnaireQuestion(id: 'pathologiesHas', label: 'Tens alguma patologia, lesão ou limitação?', type: 'binary', options: ['sim', 'não'], detailId: 'pathologies', detailLabel: 'Descreve a patologia, lesão ou limitação'),
            QuestionnaireQuestion(id: 'familyPathologiesHas', label: 'Existe histórico familiar relevante?', type: 'binary', options: ['sim', 'não'], detailId: 'familyPathologies', detailLabel: 'Descreve o histórico familiar relevante'),
            QuestionnaireQuestion(id: 'surgeryHas', label: 'Foste operado/a nos últimos 5 anos?', type: 'binary', options: ['sim', 'não'], detailId: 'surgery', detailLabel: 'Indica qual foi a cirurgia e quando aconteceu'),
            QuestionnaireQuestion(id: 'medicationHas', label: 'Tomas alguma medicação?', type: 'binary', options: ['sim', 'não'], detailId: 'medication', detailLabel: 'Qual medicação tomas?'),
            QuestionnaireQuestion(id: 'supplementsHas', label: 'Tomas algum suplemento?', type: 'binary', options: ['sim', 'não'], detailId: 'supplements', detailLabel: 'Quais suplementos tomas?'),
            QuestionnaireQuestion(id: 'allergiesHas', label: 'Tens alergias ou intolerâncias alimentares?', type: 'binary', options: ['sim', 'não'], detailId: 'allergies', detailLabel: 'Indica as alergias ou intolerâncias'),
          ],
        ),
        QuestionnaireTopic(
          id: 'goals',
          title: 'Alimentação e objetivo',
          description: 'Estas respostas ajudam a preparar um plano realista para ti.',
          questions: [
            QuestionnaireQuestion(id: 'dislikedFoods', label: 'Que alimentos não gostas ou preferes evitar?', type: 'text', multiline: true),
            QuestionnaireQuestion(id: 'preferredFoods', label: 'Que alimentos gostas e tens facilidade em comer?', type: 'text', multiline: true),
            QuestionnaireQuestion(id: 'outsideMeals', label: 'Quantas vezes por semana comes fora, fast food ou doces?', type: 'text', multiline: true),
            QuestionnaireQuestion(id: 'objective', label: 'Qual é o teu objetivo principal?', type: 'choice', options: ['Perder gordura', 'Ganhar massa muscular', 'Melhorar a condição física', 'Reeducação alimentar', 'Outro']),
          ],
        ),
      ],
    );
  }
}
