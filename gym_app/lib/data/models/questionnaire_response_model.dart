/// Respostas da ficha inicial de anamnese do aluno.
class QuestionnaireResponse {
  static const currentVersion = 'questionnaire-2026-08-gender';

  /// IDs e rótulos usados tanto pelo formulário como pelo painel admin.
  static const labels = <String, String>{
    'birthDate': 'Data de nascimento',
    'genero': 'Sexo',
    'profession': 'Profissão',
    'activity': 'Prática de exercício físico',
    'sedentary': 'Rotina sedentária',
    'meals': 'Refeições por dia',
    'water': 'Água ingerida por dia',
    'sleep': 'Horas de sono',
    'pathologies': 'Patologias ou limitações',
    'familyPathologies': 'Histórico familiar relevante',
    'surgery': 'Cirurgias nos últimos 5 anos',
    'medication': 'Medicação ou suplementos',
    'allergies': 'Alergias ou intolerâncias',
    'dislikedFoods': 'Alimentos que não gosta',
    'preferredFoods': 'Alimentos que prefere',
    'outsideMeals': 'Refeições fora da dieta',
    'objective': 'Objetivo principal',
  };

  final String version;
  final DateTime completedAt;
  final Map<String, String> answers;

  const QuestionnaireResponse({
    required this.version,
    required this.completedAt,
    required this.answers,
  });

  factory QuestionnaireResponse.fromMap(Map<String, dynamic> map) {
    final rawAnswers = map['answers'];
    final answers = <String, String>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        if (entry.key is String && entry.value != null) {
          answers[entry.key as String] = entry.value.toString();
        }
      }
    }

    return QuestionnaireResponse(
      version: map['version'] as String? ?? '',
      completedAt: _dateFromMap(map['completedAt']) ?? DateTime.now(),
      answers: answers,
    );
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'completedAt': completedAt,
      'answers': answers,
    };
  }

  bool get isCurrent => version == QuestionnaireResponse.currentVersion;

  bool get isComplete => labels.keys.every((key) {
        final value = answers[key]?.trim();
        return value != null && value.isNotEmpty;
      });
}
