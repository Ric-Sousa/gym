/// Modelo de grupo de chat para alunos trocarem horários/blocos.
class GroupModel {
  static DateTime _parseTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is DateTime) return rawTimestamp;
    if (rawTimestamp is String) {
      final parsed = DateTime.tryParse(rawTimestamp);
      if (parsed != null) return parsed;
    }
    if (rawTimestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt());
    }
    try {
      final converted = (rawTimestamp as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final String id;
  final String nome;
  final List<String> membros; // user IDs
  final String criadoPor;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastTimestamp;
  /// Path privado Storage; URLs antigas são resolvidas pelo widget de recurso.
  final String? imagemUrl;
  final Map<String, String> membrosNomes;
  final Map<String, String> membrosFotos;
  final Map<String, DateTime> lastReadAtByUser;
  final String? criadoPorNome;
  final String? criadoPorFoto;

  const GroupModel({
    this.id = '',
    required this.nome,
    this.membros = const [],
    required this.criadoPor,
    required this.createdAt,
    this.lastMessage,
    this.lastTimestamp,
    this.imagemUrl,
    this.membrosNomes = const {},
    this.membrosFotos = const {},
    this.lastReadAtByUser = const {},
    this.criadoPorNome,
    this.criadoPorFoto,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      nome: map['nome'] is String ? map['nome'] as String : '',
      membros: (map['membros'] is List ? map['membros'] as List : const [])
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList(),
      criadoPor: map['criadoPor'] is String ? map['criadoPor'] as String : '',
      createdAt: _parseTimestamp(map['createdAt']),
      lastMessage: map['lastMessage'] is String ? map['lastMessage'] as String : null,
      lastTimestamp: map['lastTimestamp'] == null
          ? null
          : _parseTimestamp(map['lastTimestamp']),
      imagemUrl: map['imagemUrl'] is String ? map['imagemUrl'] as String : null,
      membrosNomes: Map<String, String>.from(
        (map['membrosNomes'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{},
      ),
      membrosFotos: Map<String, String>.from(
        (map['membrosFotos'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{},
      ),
      lastReadAtByUser: Map<String, DateTime>.fromEntries(
        ((map['lastReadAtByUser'] as Map?) ?? const {}).entries
            .map((entry) => MapEntry(
                  entry.key.toString(),
                  _parseTimestamp(entry.value),
                )),
      ),
      criadoPorNome: map['criadoPorNome'] is String ? map['criadoPorNome'] as String : null,
      criadoPorFoto: map['criadoPorFoto'] is String ? map['criadoPorFoto'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'membros': membros,
      'criadoPor': criadoPor,
      'createdAt': createdAt,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastTimestamp != null) 'lastTimestamp': lastTimestamp,
      if (imagemUrl != null && imagemUrl!.isNotEmpty) 'imagemUrl': imagemUrl,
      if (membrosNomes.isNotEmpty) 'membrosNomes': membrosNomes,
      if (membrosFotos.isNotEmpty) 'membrosFotos': membrosFotos,
      if (lastReadAtByUser.isNotEmpty) 'lastReadAtByUser': lastReadAtByUser,
      if (criadoPorNome != null && criadoPorNome!.isNotEmpty)
        'criadoPorNome': criadoPorNome,
      if (criadoPorFoto != null && criadoPorFoto!.isNotEmpty)
        'criadoPorFoto': criadoPorFoto,
    };
  }

  GroupModel copyWith({
    String? nome,
    List<String>? membros,
    String? imagemUrl,
    Map<String, String>? membrosNomes,
    Map<String, String>? membrosFotos,
    Map<String, DateTime>? lastReadAtByUser,
    String? criadoPorNome,
    String? criadoPorFoto,
  }) {
    return GroupModel(
      id: id,
      nome: nome ?? this.nome,
      membros: membros ?? this.membros,
      criadoPor: criadoPor,
      createdAt: createdAt,
      lastMessage: lastMessage,
      lastTimestamp: lastTimestamp,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      membrosNomes: membrosNomes ?? this.membrosNomes,
      membrosFotos: membrosFotos ?? this.membrosFotos,
      lastReadAtByUser: lastReadAtByUser ?? this.lastReadAtByUser,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      criadoPorFoto: criadoPorFoto ?? this.criadoPorFoto,
    );
  }
}
