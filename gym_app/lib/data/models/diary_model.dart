/// Modelo de uma refeição registada no diário.
class MealEntry {
  final String tipo; // 'pequeno-almoço', 'almoço', 'lanche', 'jantar', 'extra'
  final String descricao;
  final double calorias;
  final String hora; // HH:mm
  final List<String> alimentos;

  const MealEntry({
    required this.tipo,
    required this.descricao,
    required this.calorias,
    required this.hora,
    this.alimentos = const [],
  });

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      tipo: map['tipo'] as String? ?? '',
      descricao: map['descricao'] as String? ?? '',
      calorias: (map['calorias'] as num?)?.toDouble() ?? 0.0,
      hora: map['hora'] as String? ?? '',
      alimentos: List<String>.from(map['alimentos'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'descricao': descricao,
      'calorias': calorias,
      'hora': hora,
      'alimentos': alimentos,
    };
  }

  MealEntry copyWith({
    String? tipo,
    String? descricao,
    double? calorias,
    String? hora,
    List<String>? alimentos,
  }) {
    return MealEntry(
      tipo: tipo ?? this.tipo,
      descricao: descricao ?? this.descricao,
      calorias: calorias ?? this.calorias,
      hora: hora ?? this.hora,
      alimentos: alimentos ?? this.alimentos,
    );
  }
}

/// Modelo de diário (documento diário do aluno).
class DiaryModel {
  final String data; // YYYY-MM-DD
  final String userId;
  final int agua; // ml
  final int passos;
  final int avaliacao; // 1-5
  final bool treinoConcluido;
  final List<MealEntry> refeicoes;
  final Map<String, dynamic>? treinoData; // dados extra do treino do dia

  const DiaryModel({
    required this.data,
    required this.userId,
    this.agua = 0,
    this.passos = 0,
    this.avaliacao = 0,
    this.treinoConcluido = false,
    this.refeicoes = const [],
    this.treinoData,
  });

  factory DiaryModel.fromMap(String data, String userId, Map<String, dynamic> map) {
    final refeicoesList = map['refeicoes'] as List? ?? [];
    return DiaryModel(
      data: data,
      userId: userId,
      agua: map['agua'] as int? ?? 0,
      passos: map['passos'] as int? ?? 0,
      avaliacao: map['avaliacao'] as int? ?? 0,
      treinoConcluido: map['treinoConcluido'] as bool? ?? false,
      refeicoes: refeicoesList
          .map((r) => MealEntry.fromMap(r as Map<String, dynamic>))
          .toList(),
      treinoData: map['treinoData'] != null
          ? Map<String, dynamic>.from(map['treinoData'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agua': agua,
      'passos': passos,
      'avaliacao': avaliacao,
      'treinoConcluido': treinoConcluido,
      'refeicoes': refeicoes.map((r) => r.toMap()).toList(),
      if (treinoData != null) 'treinoData': treinoData,
    };
  }

  double get totalCalorias =>
      refeicoes.fold(0.0, (sum, r) => sum + r.calorias);

  DiaryModel copyWith({
    String? data,
    String? userId,
    int? agua,
    int? passos,
    int? avaliacao,
    bool? treinoConcluido,
    List<MealEntry>? refeicoes,
    Map<String, dynamic>? treinoData,
  }) {
    return DiaryModel(
      data: data ?? this.data,
      userId: userId ?? this.userId,
      agua: agua ?? this.agua,
      passos: passos ?? this.passos,
      avaliacao: avaliacao ?? this.avaliacao,
      treinoConcluido: treinoConcluido ?? this.treinoConcluido,
      refeicoes: refeicoes ?? this.refeicoes,
      treinoData: treinoData ?? this.treinoData,
    );
  }
}
