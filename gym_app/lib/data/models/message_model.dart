/// Modelo de mensagem no chat.
class MessageModel {
  final String id;
  final String remetenteId;
  final String texto;
  final DateTime timestamp;
  final bool lida;

  const MessageModel({
    this.id = '',
    required this.remetenteId,
    required this.texto,
    required this.timestamp,
    this.lida = false,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      remetenteId: map['remetenteId'] as String? ?? '',
      texto: map['texto'] as String? ?? '',
      timestamp: (map['timestamp'] as dynamic).toDate() as DateTime,
      lida: map['lida'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'remetenteId': remetenteId,
      'texto': texto,
      'timestamp': timestamp,
      'lida': lida,
    };
  }

  MessageModel copyWith({
    String? id,
    String? remetenteId,
    String? texto,
    DateTime? timestamp,
    bool? lida,
  }) {
    return MessageModel(
      id: id ?? this.id,
      remetenteId: remetenteId ?? this.remetenteId,
      texto: texto ?? this.texto,
      timestamp: timestamp ?? this.timestamp,
      lida: lida ?? this.lida,
    );
  }
}
