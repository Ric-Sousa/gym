import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de grupo de chat para alunos trocarem horários/blocos.
class GroupModel {
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
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastMessage: map['lastMessage'] as String?,
      lastTimestamp: map['lastTimestamp'] != null
          ? (map['lastTimestamp'] as Timestamp).toDate()
          : null,
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
