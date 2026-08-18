/// Modelo de registo de uma série executada.
class SerieLog {
  final int numero;
  final double? carga;
  final int? repeticoes;
  final bool concluida;

  /// True quando a série foi acrescentada pelo aluno durante o treino.
  final bool adicionadaManualmente;

  const SerieLog({
    required this.numero,
    this.carga,
    this.repeticoes,
    this.concluida = false,
    this.adicionadaManualmente = false,
  });

  factory SerieLog.fromMap(Map<String, dynamic> map) {
    return SerieLog(
      numero: (map['numero'] as num?)?.toInt() ?? 1,
      carga: (map['carga'] as num?)?.toDouble(),
      repeticoes: (map['repeticoes'] as num?)?.toInt(),
      concluida: map['concluida'] is bool ? map['concluida'] as bool : false,
      adicionadaManualmente: map['adicionadaManualmente'] is bool
          ? map['adicionadaManualmente'] as bool
          : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'numero': numero,
      if (carga != null) 'carga': carga,
      if (repeticoes != null) 'repeticoes': repeticoes,
      'concluida': concluida,
      if (adicionadaManualmente) 'adicionadaManualmente': true,
    };
  }

  SerieLog copyWith({
    int? numero,
    double? carga,
    int? repeticoes,
    bool? concluida,
    bool? adicionadaManualmente,
    bool clearCarga = false,
    bool clearRepeticoes = false,
  }) {
    return SerieLog(
      numero: numero ?? this.numero,
      carga: clearCarga ? null : (carga ?? this.carga),
      repeticoes: clearRepeticoes ? null : (repeticoes ?? this.repeticoes),
      concluida: concluida ?? this.concluida,
      adicionadaManualmente:
          adicionadaManualmente ?? this.adicionadaManualmente,
    );
  }
}

/// Modelo de registo de um exercício executado.
class ExerciseLog {
  final String nome;
  final String? grupoMuscular;
  final List<SerieLog> series;

  const ExerciseLog({
    required this.nome,
    this.grupoMuscular,
    this.series = const [],
  });

  /// Cria a partir de um exercício planeado, gerando series vazias.
  factory ExerciseLog.fromExercise(
    String nome,
    int totalSeries,
    String? grupoMuscular,
  ) {
    return ExerciseLog(
      nome: nome,
      grupoMuscular: grupoMuscular,
      series: List.generate(totalSeries, (i) => SerieLog(numero: i + 1)),
    );
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    final seriesList = map['series'] as List? ?? [];
    return ExerciseLog(
      nome: map['nome'] is String ? map['nome'] as String : '',
      grupoMuscular: map['grupoMuscular'] is String
          ? map['grupoMuscular'] as String
          : null,
      series: seriesList
          .whereType<Map>()
          .map((s) => SerieLog.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      if (grupoMuscular != null) 'grupoMuscular': grupoMuscular,
      'series': series.map((s) => s.toMap()).toList(),
    };
  }

  int get seriesConcluidas => series.where((s) => s.concluida).length;
  int get totalSeries => series.length;
  bool get todasConcluidas => series.every((s) => s.concluida);
  double? get cargaMaxima {
    if (series.isEmpty) return null;
    return series.where((s) => s.carga != null).fold<double?>(null, (max, s) {
      if (max == null) return s.carga;
      return s.carga! > max ? s.carga : max;
    });
  }
}

/// Modelo de registo de treino executado (log diário).
class WorkoutLogModel {
  final String id;
  final String userId;
  final DateTime data;
  final String planoSemana;
  final String diaSemana;

  /// Identifica o sub-plano associado ao treino. Opcional para logs antigos.
  final String? subPlanoId;
  final String foco;
  final List<ExerciseLog> exercicios;
  final DateTime? completedAt;
  final int duracaoMinutos;

  const WorkoutLogModel({
    this.id = '',
    required this.userId,
    required this.data,
    required this.planoSemana,
    required this.diaSemana,
    this.subPlanoId,
    this.foco = '',
    this.exercicios = const [],
    this.completedAt,
    this.duracaoMinutos = 0,
  });

  factory WorkoutLogModel.fromMap(
    String id,
    String userId,
    Map<String, dynamic> map,
  ) {
    final exerciciosList = map['exercicios'] as List? ?? [];
    return WorkoutLogModel(
      id: id,
      userId: userId,
      data: _parseDate(map['data']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      planoSemana: map['planoSemana'] as String? ?? '',
      diaSemana: map['diaSemana'] as String? ?? '',
      subPlanoId: map['subPlanoId'] as String?,
      foco: map['foco'] as String? ?? '',
      exercicios: exerciciosList
          .whereType<Map>()
          .map((e) => ExerciseLog.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      completedAt: _parseDate(map['completedAt']),
      duracaoMinutos: (map['duracaoMinutos'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'data': data,
      'planoSemana': planoSemana,
      'diaSemana': diaSemana,
      if (subPlanoId != null && subPlanoId!.isNotEmpty)
        'subPlanoId': subPlanoId,
      'foco': foco,
      'exercicios': exercicios.map((e) => e.toMap()).toList(),
      if (completedAt != null) 'completedAt': completedAt,
      'duracaoMinutos': duracaoMinutos,
    };
  }

  int get seriesTotais => exercicios.fold(0, (sum, e) => sum + e.totalSeries);
  int get seriesConcluidas =>
      exercicios.fold(0, (sum, e) => sum + e.seriesConcluidas);
  bool get concluido => completedAt != null;
  double get progresso =>
      seriesTotais > 0 ? seriesConcluidas / seriesTotais : 0.0;

  WorkoutLogModel copyWith({
    String? id,
    String? userId,
    DateTime? data,
    String? planoSemana,
    String? diaSemana,
    String? subPlanoId,
    String? foco,
    List<ExerciseLog>? exercicios,
    DateTime? completedAt,
    int? duracaoMinutos,
  }) {
    return WorkoutLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      planoSemana: planoSemana ?? this.planoSemana,
      diaSemana: diaSemana ?? this.diaSemana,
      subPlanoId: subPlanoId ?? this.subPlanoId,
      foco: foco ?? this.foco,
      exercicios: exercicios ?? this.exercicios,
      completedAt: completedAt ?? this.completedAt,
      duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
    );
  }
}
