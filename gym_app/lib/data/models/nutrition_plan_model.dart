/// Alimento individual no plano nutricional.
class Alimento {
  final String nome;
  final String quantidade;
  final double calorias;
  final double? proteinas;
  final double? hidratos;
  final double? gorduras;

  const Alimento({
    required this.nome,
    required this.quantidade,
    required this.calorias,
    this.proteinas,
    this.hidratos,
    this.gorduras,
  });

  /// Tenta extrair os gramas a partir do campo [quantidade].
  /// Ex: "150g" → 150.0, "200 gramas" → 200.0.
  /// Retorna null se não for possível fazer o parse.
  double? get quantidadeGramas {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(quantidade);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Calcula calorias proporcionais aos gramas consumidos.
  /// Se [quantidadeGramas] não estiver disponível, retorna [calorias] total.
  double caloriasParaGramas(double gramas) {
    final porcaoG = quantidadeGramas;
    if (porcaoG == null || porcaoG <= 0) return calorias;
    return (gramas / porcaoG) * calorias;
  }

  /// Calcula proteínas proporcionais aos gramas consumidos.
  double proteinasParaGramas(double gramas) {
    final porcaoG = quantidadeGramas;
    if (porcaoG == null || porcaoG <= 0) return proteinas ?? 0;
    return (gramas / porcaoG) * (proteinas ?? 0);
  }

  /// Calcula hidratos proporcionais aos gramas consumidos.
  double hidratosParaGramas(double gramas) {
    final porcaoG = quantidadeGramas;
    if (porcaoG == null || porcaoG <= 0) return hidratos ?? 0;
    return (gramas / porcaoG) * (hidratos ?? 0);
  }

  /// Calcula gorduras proporcionais aos gramas consumidos.
  double gordurasParaGramas(double gramas) {
    final porcaoG = quantidadeGramas;
    if (porcaoG == null || porcaoG <= 0) return gorduras ?? 0;
    return (gramas / porcaoG) * (gorduras ?? 0);
  }

  factory Alimento.fromMap(Map<String, dynamic> map) {
    return Alimento(
      nome: map['nome'] as String? ?? '',
      quantidade: map['quantidade'] as String? ?? '',
      calorias: (map['calorias'] as num?)?.toDouble() ?? 0.0,
      proteinas: (map['proteinas'] as num?)?.toDouble(),
      hidratos: (map['hidratos'] as num?)?.toDouble(),
      gorduras: (map['gorduras'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'quantidade': quantidade,
      'calorias': calorias,
      if (proteinas != null) 'proteinas': proteinas,
      if (hidratos != null) 'hidratos': hidratos,
      if (gorduras != null) 'gorduras': gorduras,
    };
  }
}

/// Refeição planeada no plano nutricional.
class PlannedMeal {
  final String tipo; // 'pequeno-almoço', 'almoço', 'lanche', 'jantar'
  final List<Alimento> alimentos;
  final String? instrucoes;

  const PlannedMeal({
    required this.tipo,
    this.alimentos = const [],
    this.instrucoes,
  });

  factory PlannedMeal.fromMap(Map<String, dynamic> map) {
    final alimentosList = map['alimentos'] as List? ?? [];
    return PlannedMeal(
      tipo: map['tipo'] as String? ?? '',
      alimentos: alimentosList
          .map((a) => Alimento.fromMap(a as Map<String, dynamic>))
          .toList(),
      instrucoes: map['instrucoes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'alimentos': alimentos.map((a) => a.toMap()).toList(),
      if (instrucoes != null) 'instrucoes': instrucoes,
    };
  }

  double get totalCalorias =>
      alimentos.fold(0.0, (sum, a) => sum + a.calorias);
}

/// Suplemento no plano nutricional.
class Suplemento {
  final String nome;
  final String dosagem;
  final String horario; // 'pré-treino', 'pós-treino', 'manhã', 'noite', 'qualquer'

  const Suplemento({
    required this.nome,
    required this.dosagem,
    this.horario = 'qualquer',
  });

  factory Suplemento.fromMap(Map<String, dynamic> map) {
    return Suplemento(
      nome: map['nome'] as String? ?? '',
      dosagem: map['dosagem'] as String? ?? '',
      horario: map['horario'] as String? ?? 'qualquer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'dosagem': dosagem,
      'horario': horario,
    };
  }
}

/// Plano nutricional (documento por dia da semana).
class NutritionPlanModel {
  final String dia; // 'Segunda-feira', etc.
  final String userId;
  final double metaCalorias;
  final List<PlannedMeal> refeicoes;
  final List<Suplemento> suplementos;

  const NutritionPlanModel({
    required this.dia,
    required this.userId,
    this.metaCalorias = 0.0,
    this.refeicoes = const [],
    this.suplementos = const [],
  });

  factory NutritionPlanModel.fromMap(
      String dia, String userId, Map<String, dynamic> map) {
    final refeicoesList = map['refeicoes'] as List? ?? [];
    return NutritionPlanModel(
      dia: dia,
      userId: userId,
      metaCalorias: (map['metaCalorias'] as num?)?.toDouble() ?? 0.0,
      refeicoes: refeicoesList
          .map((r) => PlannedMeal.fromMap(r as Map<String, dynamic>))
          .toList(),
      suplementos: (map['suplementos'] as List? ?? [])
          .map((s) => Suplemento.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'metaCalorias': metaCalorias,
      'refeicoes': refeicoes.map((r) => r.toMap()).toList(),
      'suplementos': suplementos.map((s) => s.toMap()).toList(),
    };
  }

  double get totalCaloriasPlaneadas =>
      refeicoes.fold(0.0, (sum, r) => sum + r.totalCalorias);
}
