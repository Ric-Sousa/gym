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

  const GroupModel({
    this.id = '',
    required this.nome,
    this.membros = const [],
    required this.criadoPor,
    required this.createdAt,
    this.lastMessage,
    this.lastTimestamp,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      nome: map['nome'] as String? ?? '',
      membros: List<String>.from(map['membros'] as List? ?? []),
      criadoPor: map['criadoPor'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
      lastMessage: map['lastMessage'] as String?,
      lastTimestamp: map['lastTimestamp'] == null
          ? null
          : _parseTimestamp(map['lastTimestamp']),
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
    };
  }
}
