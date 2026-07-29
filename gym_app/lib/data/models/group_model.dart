import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de grupo de chat para alunos trocarem horários/blocos.
class GroupModel {
  final String id;
  final String nome;
  final List<String> membros; // user IDs
  final String criadoPor;
  final DateTime createdAt;

  const GroupModel({
    this.id = '',
    required this.nome,
    this.membros = const [],
    required this.criadoPor,
    required this.createdAt,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      nome: map['nome'] as String? ?? '',
      membros: List<String>.from(map['membros'] as List? ?? []),
      criadoPor: map['criadoPor'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'membros': membros,
      'criadoPor': criadoPor,
      'createdAt': createdAt,
    };
  }
}
