/// Exercício da biblioteca global do personal trainer.
///
/// Este modelo é separado de [Exercise]: [Exercise] representa a prescrição
/// num plano (séries, carga e descanso), enquanto este modelo representa os
/// dados reutilizáveis do exercício.
class ExerciseCatalogModel {
  final String id;
  final String nome;
  final List<String> instrucoes;
  final String nivel;
  final String categoria;
  final String equipamento;
  final String? forca;
  final String? mecanica;
  final List<String> musculosPrimarios;
  final List<String> musculosSecundarios;
  final String grupoMuscular;
  final List<String> imagens;
  final String? videoUrl;
  final bool ativo;
  final String? origem;
  final String? origemId;
  final DateTime? importadoEm;
  final DateTime? atualizadoEm;

  const ExerciseCatalogModel({
    required this.id,
    required this.nome,
    this.instrucoes = const [],
    this.nivel = 'iniciante',
    this.categoria = 'forca',
    this.equipamento = 'outro',
    this.forca,
    this.mecanica,
    this.musculosPrimarios = const [],
    this.musculosSecundarios = const [],
    this.grupoMuscular = 'Geral',
    this.imagens = const [],
    this.videoUrl,
    this.ativo = true,
    this.origem,
    this.origemId,
    this.importadoEm,
    this.atualizadoEm,
  });

  factory ExerciseCatalogModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ExerciseCatalogModel(
      id: id,
      nome: map['nome'] as String? ?? '',
      instrucoes: _stringList(map['instrucoes'] ?? map['instructions']),
      nivel: map['nivel'] as String? ?? map['level'] as String? ?? 'iniciante',
      categoria: map['categoria'] as String? ?? map['category'] as String? ?? 'forca',
      equipamento: map['equipamento'] as String? ?? 'outro',
      forca: map['forca'] as String? ?? map['force'] as String?,
      mecanica: map['mecanica'] as String? ?? map['mechanic'] as String?,
      musculosPrimarios: _normalizeMuscles(
        _stringList(map['musculosPrimarios'] ?? map['primaryMuscles']),
      ),
      musculosSecundarios: _normalizeMuscles(
        _stringList(map['musculosSecundarios'] ?? map['secondaryMuscles']),
      ),
      grupoMuscular: canonicalMuscleGroup(
        map['grupoMuscular'] as String? ??
            _firstString(map['musculosPrimarios'] ?? map['primaryMuscles']),
      ),
      imagens: _stringList(map['imagens'] ?? map['images']),
      videoUrl: map['videoUrl'] as String? ?? map['videoURL'] as String?,
      ativo: map['ativo'] as bool? ?? true,
      origem: map['origem'] as String?,
      origemId: map['origemId'] as String? ?? map['sourceId'] as String?,
      importadoEm: _dateValue(map['importadoEm']),
      atualizadoEm: _dateValue(map['atualizadoEm']),
    );
  }

  /// Converte o formato do repositório externo para o modelo da aplicação.
  factory ExerciseCatalogModel.fromSourceMap(Map<String, dynamic> map) {
    final sourceId = map['id'] as String? ?? '';
    return ExerciseCatalogModel(
      id: sourceId,
      nome: map['name'] as String? ?? '',
      instrucoes: _stringList(map['instructions']),
      nivel: _normalizeValue(map['level'] as String?, fallback: 'iniciante'),
      categoria: _normalizeCategory(map['category'] as String?),
      equipamento: _normalizeEquipment(map['equipment'] as String?),
      forca: map['force'] as String?,
      mecanica: map['mechanic'] as String?,
      musculosPrimarios: _normalizeMuscles(_stringList(map['primaryMuscles'])),
      musculosSecundarios: _normalizeMuscles(
        _stringList(map['secondaryMuscles']),
      ),
      grupoMuscular: canonicalMuscleGroup(
        _firstString(map['primaryMuscles']),
      ),
      imagens: _stringList(map['images']),
      ativo: true,
      origem: 'joao-gugel/exercicios-bd-ptbr',
      origemId: sourceId,
    );
  }

  Map<String, dynamic> toMap({DateTime? now}) {
    return {
      'nome': nome,
      'instrucoes': instrucoes,
      'nivel': nivel,
      'categoria': categoria,
      'equipamento': equipamento,
      if (forca != null) 'forca': forca,
      if (mecanica != null) 'mecanica': mecanica,
      'musculosPrimarios': musculosPrimarios,
      'musculosSecundarios': musculosSecundarios,
      'grupoMuscular': grupoMuscular,
      // São apenas referências; o repositório externo não distribui imagens.
      'imagens': imagens,
      if (videoUrl != null && videoUrl!.trim().isNotEmpty) 'videoUrl': videoUrl,
      'ativo': ativo,
      if (origem != null) 'origem': origem,
      if (origemId != null) 'origemId': origemId,
      if (importadoEm != null) 'importadoEm': importadoEm,
      if (atualizadoEm != null) 'atualizadoEm': atualizadoEm,
      if (now != null) 'atualizadoEm': now,
    };
  }

  ExerciseCatalogModel copyWith({
    String? nome,
    List<String>? instrucoes,
    String? nivel,
    String? categoria,
    String? equipamento,
    String? forca,
    String? mecanica,
    List<String>? musculosPrimarios,
    List<String>? musculosSecundarios,
    String? grupoMuscular,
    List<String>? imagens,
    String? videoUrl,
    bool? ativo,
    DateTime? atualizadoEm,
  }) {
    return ExerciseCatalogModel(
      id: id,
      nome: nome ?? this.nome,
      instrucoes: instrucoes ?? this.instrucoes,
      nivel: nivel ?? this.nivel,
      categoria: categoria ?? this.categoria,
      equipamento: equipamento ?? this.equipamento,
      forca: forca ?? this.forca,
      mecanica: mecanica ?? this.mecanica,
      musculosPrimarios: musculosPrimarios ?? this.musculosPrimarios,
      musculosSecundarios: musculosSecundarios ?? this.musculosSecundarios,
      grupoMuscular: grupoMuscular ?? this.grupoMuscular,
      imagens: imagens ?? this.imagens,
      videoUrl: videoUrl ?? this.videoUrl,
      ativo: ativo ?? this.ativo,
      origem: origem,
      origemId: origemId,
      importadoEm: importadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static String _firstString(dynamic value) {
    final values = _stringList(value);
    return values.isEmpty ? '' : values.first;
  }

  static List<String> _normalizeMuscles(List<String> values) {
    return values.map(canonicalMuscleGroup).toSet().toList();
  }

  /// Converte nomes PT-BR/inglês do dataset para categorias estáveis da app.
  static String canonicalMuscleGroup(String value) {
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
    normalized = normalized.replaceAll(RegExp(r'[-_]'), ' ');

    if (normalized.contains('chest') ||
        normalized.contains('peitoral') ||
        normalized == 'peito' ||
        normalized == 'peitorais') {
      return 'Peito';
    }
    if (normalized.contains('lower back') ||
        normalized.contains('lombar') ||
        normalized.contains('erector')) {
      return 'Lombar';
    }
    if (normalized.contains('lat') ||
        normalized.contains('back') ||
        normalized == 'costas' ||
        normalized == 'dorsais' ||
        normalized == 'dorsal') {
      return 'Costas';
    }
    if (normalized.contains('shoulder') ||
        normalized.contains('deltoid') ||
        normalized == 'ombro' ||
        normalized == 'ombros') {
      return 'Ombros';
    }
    if (normalized.contains('hamstring') ||
        normalized.contains('isquiotibial') ||
        normalized.contains('posterior')) {
      return 'Posterior';
    }
    if (normalized.contains('glute') || normalized.contains('gluteo')) {
      return 'Glúteos';
    }
    if (normalized.contains('quadricep') || normalized.contains('quadrice')) {
      return 'Quadríceps';
    }
    if (normalized.contains('bicep')) return 'Bíceps';
    if (normalized.contains('tricep')) return 'Tríceps';
    if (normalized.contains('abdomin') || normalized == 'abs') {
      return 'Abdominais';
    }
    if (normalized.contains('calf') || normalized.contains('panturrilha')) {
      return 'Panturrilhas';
    }
    if (normalized.contains('adductor') || normalized.contains('adutor')) {
      return 'Adutores';
    }
    if (normalized.contains('abductor') || normalized.contains('abdutor')) {
      return 'Abdutores';
    }
    if (normalized.contains('trap')) return 'Trapézio';
    if (normalized.contains('forearm') || normalized.contains('antebraco')) {
      return 'Antebraços';
    }
    if (normalized.contains('neck') || normalized.contains('pescoco')) {
      return 'Pescoço';
    }
    if (normalized.contains('core')) return 'Core';
    return value.trim().isEmpty ? 'Geral' : _titleCase(value.trim());
  }

  static String _titleCase(String value) {
    return value.isEmpty
        ? 'Geral'
        : value[0].toUpperCase() + value.substring(1);
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return value is String ? DateTime.tryParse(value) : null;
    }
  }

  static String _normalizeValue(String? value, {required String fallback}) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  static String _normalizeCategory(String? value) {
    final normalized = _normalizeValue(value, fallback: 'forca');
    const categories = {
      'strength': 'forca',
      'strength training': 'forca',
      'stretching': 'alongamento',
      'plyometrics': 'pliometria',
      'cardio': 'cardio',
      'olympic weightlifting': 'levantamento_olimpico',
      'strongman': 'strongman',
    };
    return categories[normalized] ?? normalized;
  }

  static String _normalizeEquipment(String? value) {
    final normalized = _normalizeValue(value, fallback: 'outro');
    const equipment = {
      'body only': 'peso_corporal',
      'bodyweight': 'peso_corporal',
      'peso-do-corpo': 'peso_corporal',
      'peso corporal': 'peso_corporal',
      'barbell': 'barra',
      'dumbbell': 'haltere',
      'kettlebells': 'kettlebell',
      'kettlebell': 'kettlebell',
      'cable': 'polia',
      'machine': 'maquina',
      'maquina': 'maquina',
      'máquina': 'maquina',
      'outros': 'outro',
      'bands': 'banda',
      'band': 'banda',
      'rope': 'corda',
      'foam roll': 'rolo',
      'other': 'outro',
      'outro': 'outro',
    };
    return equipment[normalized] ?? normalized;
  }
}
