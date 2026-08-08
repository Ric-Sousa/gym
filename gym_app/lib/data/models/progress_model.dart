/// Modelo de progresso físico do aluno.
class ProgressModel {
  final String id;
  final String userId;
  final DateTime data;
  final double? peso;
  final Map<String, double> medidas; // cintura, quadril, braço, etc.
  final List<String> fotos; // URLs das fotos (formato legado/compatível)
  final Map<String, String> fotosPorPosicao;

  const ProgressModel({
    this.id = '',
    required this.userId,
    required this.data,
    this.peso,
    this.medidas = const {},
    this.fotos = const [],
    this.fotosPorPosicao = const {},
  });

  factory ProgressModel.fromMap(
    String id,
    String userId,
    Map<String, dynamic> map,
  ) {
    final medidasRaw = map['medidas'] as Map<String, dynamic>? ?? {};
    final medidas = medidasRaw.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return ProgressModel(
      id: id,
      userId: userId,
      data: (map['data'] as dynamic).toDate() as DateTime,
      peso: (map['peso'] as num?)?.toDouble(),
      medidas: medidas,
      fotos: List<String>.from(map['fotos'] as List? ?? []),
      fotosPorPosicao: Map<String, String>.from(
        (map['fotosPorPosicao'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'data': data,
      if (peso != null) 'peso': peso,
      'medidas': medidas,
      'fotos': fotos,
      if (fotosPorPosicao.isNotEmpty) 'fotosPorPosicao': fotosPorPosicao,
    };
  }

  ProgressModel copyWith({
    String? id,
    String? userId,
    DateTime? data,
    double? peso,
    Map<String, double>? medidas,
    List<String>? fotos,
    Map<String, String>? fotosPorPosicao,
    bool clearPeso = false,
  }) {
    return ProgressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      peso: clearPeso ? null : (peso ?? this.peso),
      medidas: medidas ?? this.medidas,
      fotos: fotos ?? this.fotos,
      fotosPorPosicao: fotosPorPosicao ?? this.fotosPorPosicao,
    );
  }
}
