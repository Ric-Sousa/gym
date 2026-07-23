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

/// Plano nutricional (documento por dia da semana).
class NutritionPlanModel {
  final String dia; // 'Segunda-feira', etc.
  final String userId;
  final double metaCalorias;
  final List<PlannedMeal> refeicoes;

  const NutritionPlanModel({
    required this.dia,
    required this.userId,
    this.metaCalorias = 0.0,
    this.refeicoes = const [],
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'metaCalorias': metaCalorias,
      'refeicoes': refeicoes.map((r) => r.toMap()).toList(),
    };
  }

  double get totalCaloriasPlaneadas =>
      refeicoes.fold(0.0, (sum, r) => sum + r.totalCalorias);
}
