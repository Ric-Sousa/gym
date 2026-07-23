/// Modelo de alimento na base de dados.
class FoodModel {
  final String id;
  final String nome;
  final double caloriasPor100g;
  final double? proteinasPor100g;
  final double? hidratosPor100g;
  final double? gordurasPor100g;
  final String? categoria; // 'proteína', 'hidrato', 'gordura', 'vegetal', etc.

  const FoodModel({
    this.id = '',
    required this.nome,
    required this.caloriasPor100g,
    this.proteinasPor100g,
    this.hidratosPor100g,
    this.gordurasPor100g,
    this.categoria,
  });

  factory FoodModel.fromMap(String id, Map<String, dynamic> map) {
    return FoodModel(
      id: id,
      nome: map['nome'] as String? ?? '',
      caloriasPor100g: (map['caloriasPor100g'] as num?)?.toDouble() ?? 0.0,
      proteinasPor100g: (map['proteinasPor100g'] as num?)?.toDouble(),
      hidratosPor100g: (map['hidratosPor100g'] as num?)?.toDouble(),
      gordurasPor100g: (map['gordurasPor100g'] as num?)?.toDouble(),
      categoria: map['categoria'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'caloriasPor100g': caloriasPor100g,
      if (proteinasPor100g != null) 'proteinasPor100g': proteinasPor100g,
      if (hidratosPor100g != null) 'hidratosPor100g': hidratosPor100g,
      if (gordurasPor100g != null) 'gordurasPor100g': gordurasPor100g,
      if (categoria != null) 'categoria': categoria,
    };
  }

  /// Calcula calorias para uma quantidade específica (em gramas).
  double caloriasParaQuantidade(double gramas) {
    return (caloriasPor100g / 100) * gramas;
  }

  FoodModel copyWith({
    String? id,
    String? nome,
    double? caloriasPor100g,
    double? proteinasPor100g,
    double? hidratosPor100g,
    double? gordurasPor100g,
    String? categoria,
  }) {
    return FoodModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      caloriasPor100g: caloriasPor100g ?? this.caloriasPor100g,
      proteinasPor100g: proteinasPor100g ?? this.proteinasPor100g,
      hidratosPor100g: hidratosPor100g ?? this.hidratosPor100g,
      gordurasPor100g: gordurasPor100g ?? this.gordurasPor100g,
      categoria: categoria ?? this.categoria,
    );
  }
}
