/// Respostas da ficha inicial de anamnese do aluno.
class QuestionnaireResponse {
  static const currentVersion = 'questionnaire-2026-08-health-v2';

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
    'pathologiesHas': 'Tem patologias ou limitações',
    'pathologies': 'Detalhes de patologias ou limitações',
    'familyPathologiesHas': 'Tem histórico familiar relevante',
    'familyPathologies': 'Detalhes do histórico familiar',
    'surgeryHas': 'Teve cirurgias nos últimos 5 anos',
    'surgery': 'Detalhes das cirurgias',
    'medicationHas': 'Toma medicação',
    'medication': 'Medicação que toma',
    'supplementsHas': 'Toma suplementos',
    'supplements': 'Suplementos que toma',
    'allergiesHas': 'Tem alergias ou intolerâncias',
    'allergies': 'Detalhes de alergias ou intolerâncias',
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

  static const _conditionalDetails = <String, String>{
    'pathologiesHas': 'pathologies',
    'familyPathologiesHas': 'familyPathologies',
    'surgeryHas': 'surgery',
    'medicationHas': 'medication',
    'supplementsHas': 'supplements',
    'allergiesHas': 'allergies',
  };

  static const _conditionalDetailKeys = <String>{
    'pathologies',
    'familyPathologies',
    'surgery',
    'medication',
    'supplements',
    'allergies',
  };

  bool get isComplete {
    for (final key in labels.keys) {
      final detailKey = _conditionalDetails[key];
      if (detailKey != null) {
        final answer = answers[key]?.trim().toLowerCase();
        if (answer != 'sim' && answer != 'não') return false;
        if (answer == 'sim' && (answers[detailKey]?.trim().isEmpty ?? true)) {
          return false;
        }
        continue;
      }
      if (_conditionalDetailKeys.contains(key)) {
        continue;
      }
      if (answers[key]?.trim().isEmpty ?? true) return false;
    }
    return true;
  }
}
