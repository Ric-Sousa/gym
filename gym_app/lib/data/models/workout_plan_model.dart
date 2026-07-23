/// Exercício individual no plano de treino.
class Exercise {
  final String nome;
  final int series;
  final int repeticoes;
  final double? cargaSugerida;
  final int descanso; // segundos
  final String? videoURL;
  final String? observacoes;
  final String? grupoMuscular;

  const Exercise({
    required this.nome,
    required this.series,
    required this.repeticoes,
    this.cargaSugerida,
    this.descanso = 60,
    this.videoURL,
    this.observacoes,
    this.grupoMuscular,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      nome: map['nome'] as String? ?? '',
      series: map['series'] as int? ?? 3,
      repeticoes: map['repeticoes'] as int? ?? 10,
      cargaSugerida: (map['cargaSugerida'] as num?)?.toDouble(),
      descanso: map['descanso'] as int? ?? 60,
      videoURL: map['videoURL'] as String?,
      observacoes: map['observacoes'] as String?,
      grupoMuscular: map['grupoMuscular'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'series': series,
      'repeticoes': repeticoes,
      if (cargaSugerida != null) 'cargaSugerida': cargaSugerida,
      'descanso': descanso,
      if (videoURL != null) 'videoURL': videoURL,
      if (observacoes != null) 'observacoes': observacoes,
      if (grupoMuscular != null) 'grupoMuscular': grupoMuscular,
    };
  }
}

/// Dia de treino no plano semanal.
class WorkoutDay {
  final String diaSemana; // 'Segunda-feira', etc.
  final String foco; // 'Peito', 'Costas', etc.
  final List<Exercise> exercicios;

  const WorkoutDay({
    required this.diaSemana,
    this.foco = '',
    this.exercicios = const [],
  });

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    final exerciciosList = map['exercicios'] as List? ?? [];
    return WorkoutDay(
      diaSemana: map['diaSemana'] as String? ?? '',
      foco: map['foco'] as String? ?? '',
      exercicios: exerciciosList
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diaSemana': diaSemana,
      'foco': foco,
      'exercicios': exercicios.map((e) => e.toMap()).toList(),
    };
  }
}

/// Plano de treino (documento por ciclo/semana).
class WorkoutPlanModel {
  final String nome; // 'Semana 1', 'Ciclo A', etc.
  final String userId;
  final List<WorkoutDay> dias;

  const WorkoutPlanModel({
    required this.nome,
    required this.userId,
    this.dias = const [],
  });

  factory WorkoutPlanModel.fromMap(
      String nome, String userId, Map<String, dynamic> map) {
    final diasList = map['dias'] as List? ?? [];
    return WorkoutPlanModel(
      nome: nome,
      userId: userId,
      dias: diasList
          .map((d) => WorkoutDay.fromMap(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dias': dias.map((d) => d.toMap()).toList(),
    };
  }

  /// Obtém o treino de um dia específico.
  WorkoutDay? getWorkoutForDay(String diaSemana) {
    try {
      return dias.firstWhere((d) => d.diaSemana == diaSemana);
    } catch (_) {
      return null;
    }
  }
}
