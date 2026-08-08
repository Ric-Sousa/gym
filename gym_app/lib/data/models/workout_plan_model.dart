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
  final String categoria; // 'musculação', 'funcional', 'cardio', 'pesos_livres'
  final String
  equipamento; // 'barra', 'haltere', 'kettlebell', 'corda', 'peso_corporal', 'banda', 'outro'
  final int? duracao; // segundos — exercícios cronometrados (corda, prancha)
  final int? rounds; // rounds para circuito funcional

  const Exercise({
    required this.nome,
    required this.series,
    required this.repeticoes,
    this.cargaSugerida,
    this.descanso = 60,
    this.videoURL,
    this.observacoes,
    this.grupoMuscular,
    this.categoria = 'musculação',
    this.equipamento = 'outro',
    this.duracao,
    this.rounds,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      nome: map['nome'] as String? ?? '',
      series: (map['series'] as num?)?.toInt() ?? 3,
      repeticoes: (map['repeticoes'] as num?)?.toInt() ?? 10,
      cargaSugerida: (map['cargaSugerida'] as num?)?.toDouble(),
      descanso: (map['descanso'] as num?)?.toInt() ?? 60,
      videoURL: map['videoURL'] as String?,
      observacoes: map['observacoes'] as String?,
      grupoMuscular: map['grupoMuscular'] as String?,
      categoria: map['categoria'] as String? ?? 'musculação',
      equipamento: map['equipamento'] as String? ?? 'outro',
      duracao: (map['duracao'] as num?)?.toInt(),
      rounds: (map['rounds'] as num?)?.toInt(),
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
      'categoria': categoria,
      'equipamento': equipamento,
      if (duracao != null) 'duracao': duracao,
      if (rounds != null) 'rounds': rounds,
    };
  }
}

/// Dia de treino no plano semanal.
class WorkoutDay {
  final String diaSemana; // 'Segunda-feira', etc.
  final String foco; // 'Peito', 'Costas', etc.
  /// Identificador estável do sub-plano.
  final String subPlanoId;

  /// Nome do sub-plano/rotina. Dados antigos usam o dia como fallback.
  final String subPlano;
  final List<Exercise> exercicios;

  const WorkoutDay({
    required this.diaSemana,
    this.foco = '',
    this.subPlanoId = '',
    this.subPlano = '',
    this.exercicios = const [],
  });

  factory WorkoutDay.fromMap(Map<String, dynamic> map, {String? legacyId}) {
    final exerciciosList = map['exercicios'] as List? ?? [];
    final diaSemana = map['diaSemana'] as String? ?? '';
    final subPlano = map['subPlano'] as String? ?? map['nome'] as String? ?? '';
    final storedId = map['subPlanoId'] as String? ?? '';
    return WorkoutDay(
      diaSemana: diaSemana,
      foco: map['foco'] as String? ?? '',
      // Legacy documents did not have an ID. Derive one deterministically so
      // the admin and student read the same sub-plan identity on every load.
      subPlanoId: storedId.trim().isNotEmpty
          ? storedId
          : (legacyId ?? _legacySubPlanId(diaSemana, subPlano)),
      subPlano: subPlano,
      exercicios: exerciciosList
          .whereType<Map>()
          .map((e) => Exercise.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static String _legacySubPlanId(String weekday, String name) {
    final source = '${name.trim()}-${weekday.trim()}';
    final slug = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'legacy-${slug.isEmpty ? 'subplan' : slug}';
  }

  String get displayName => subPlano.trim().isEmpty ? diaSemana : subPlano;

  Map<String, dynamic> toMap() {
    return {
      'diaSemana': diaSemana,
      'foco': foco,
      if (subPlanoId.trim().isNotEmpty) 'subPlanoId': subPlanoId,
      if (subPlano.trim().isNotEmpty) 'subPlano': subPlano,
      'exercicios': exercicios.map((e) => e.toMap()).toList(),
    };
  }
}

/// Plano de treino (documento por ciclo/semana).
class WorkoutPlanModel {
  final String id;
  final String nome; // 'Semana 1', 'Ciclo A', etc.
  final String userId;
  final List<WorkoutDay> dias;

  const WorkoutPlanModel({
    required this.nome,
    required this.userId,
    this.id = '',
    this.dias = const [],
  });

  factory WorkoutPlanModel.fromMap(
    String id,
    String userId,
    Map<String, dynamic> map,
  ) {
    final diasList = map['dias'] as List? ?? [];
    return WorkoutPlanModel(
      id: id,
      nome: map['nome'] as String? ?? id,
      userId: userId,
      dias: diasList.whereType<Map>().map((entry) {
        final map = Map<String, dynamic>.from(entry);
        return WorkoutDay.fromMap(map);
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'dias': dias.map((d) => d.toMap()).toList()};
  }

  /// Obtém o treino de um dia específico.
  ///
  /// Os planos antigos podem conter pequenas diferenças de capitalização,
  /// acentos ou o sufixo "-feira". Normalizamos ambos os valores para que um
  /// treino atribuído continue a aparecer no ecrã do aluno.
  WorkoutDay? getWorkoutForDay(String diaSemana) {
    final requested = _normalizeWeekday(diaSemana);
    for (final day in dias) {
      if (_normalizeWeekday(day.diaSemana) == requested) return day;
    }
    return null;
  }

  static String _normalizeWeekday(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    normalized = normalized.replaceAll(RegExp(r'[-_\s]+'), '');
    if (normalized.endsWith('feira')) {
      normalized = normalized.substring(0, normalized.length - 5);
    }
    return normalized.replaceAll(RegExp(r'[^a-z]'), '');
  }
}
