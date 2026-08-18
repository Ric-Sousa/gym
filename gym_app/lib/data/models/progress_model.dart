/// Modelo de progresso físico do aluno.
class ProgressModel {
  final String id;
  final String userId;
  final DateTime data;
  final double? peso;
  final Map<String, double> medidas; // cintura, quadril, braço, etc.
  /// Paths privados Storage; URLs HTTP/GS antigas são lidas como legado.
  final List<String> fotos;
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
    final medidasRaw = map['medidas'] is Map
        ? Map<String, dynamic>.from(map['medidas'] as Map)
        : <String, dynamic>{};
    final medidas = <String, double>{};
    for (final entry in medidasRaw.entries) {
      if (entry.value is num) {
        medidas[entry.key] = (entry.value as num).toDouble();
      }
    }

    // Firestore devolve estes campos como List/Map dinâmicos. Não fazer um
    // cast direto para List<String>/Map<String, String>: documentos antigos
    // podem conter nulls ou valores não-string e isso faria todo o histórico
    // falhar antes de o resolver conseguir aproveitar as fotos válidas.
    final fotos =
        (map['fotos'] as List?)
            ?.map((value) => value is String ? value : '')
            .toList() ??
        <String>[];
    final fotosPorPosicao = <String, String>{};
    final fotosPorPosicaoRaw = map['fotosPorPosicao'];
    if (fotosPorPosicaoRaw is Map) {
      for (final entry in fotosPorPosicaoRaw.entries) {
        final position = entry.key?.toString().trim() ?? '';
        final url = entry.value is String ? (entry.value as String).trim() : '';
        if (position.isNotEmpty && url.isNotEmpty) {
          fotosPorPosicao[position] = url;
        }
      }
    }

    final parsedDate = _parseDate(map['data']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rawWeight = map['peso'];
    final weight = rawWeight is num && rawWeight >= 0 && rawWeight <= 500
        ? rawWeight.toDouble()
        : null;
    return ProgressModel(
      id: id,
      userId: userId,
      data: parsedDate,
      peso: weight,
      medidas: medidas,
      fotos: fotos,
      fotosPorPosicao: fotosPorPosicao,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final parsed = (value as dynamic).toDate();
      return parsed is DateTime ? parsed : null;
    } catch (_) {
      return null;
    }
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
