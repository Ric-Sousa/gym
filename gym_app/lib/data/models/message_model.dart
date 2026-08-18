/// Modelo de mensagem no chat.
class MessageModel {
  static DateTime _parseTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is DateTime) return rawTimestamp;
    if (rawTimestamp is String) {
      final parsed = DateTime.tryParse(rawTimestamp);
      if (parsed != null) return parsed;
    }
    if (rawTimestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt());
    }

    // Firestore Timestamp (e mocks compatíveis) expõem toDate(). Algumas
    // mensagens antigas/pending podem não ter timestamp; não deixamos esse
    // documento derrubar a stream inteira do chat.
    try {
      final converted = (rawTimestamp as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final String id;
  final String remetenteId;
  final String texto;
  final DateTime timestamp;
  final bool lida;
  /// Path privado Storage; URLs antigas continuam compatíveis na leitura.
  final String? audioUrl;
  final int? audioDurationMs;
  /// Path privado Storage; URLs antigas continuam compatíveis na leitura.
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;

  /// Path Storage usado durante o upload. Não é persistido no Firestore;
  /// permite apagar o ficheiro se a escrita da mensagem falhar.
  final String? storagePath;

  const MessageModel({
    this.id = '',
    required this.remetenteId,
    required this.texto,
    required this.timestamp,
    this.lida = false,
    this.audioUrl,
    this.audioDurationMs,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.storagePath,
  });

  bool get isAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get isAttachment =>
      attachmentUrl != null && attachmentUrl!.trim().isNotEmpty;

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = _parseTimestamp(map['timestamp']);
    return MessageModel(
      id: id,
      remetenteId: map['remetenteId'] is String ? map['remetenteId'] as String : '',
      texto: map['texto'] is String ? map['texto'] as String : '',
      timestamp: timestamp,
      lida: map['lida'] is bool ? map['lida'] as bool : false,
      audioUrl: map['audioUrl'] is String ? map['audioUrl'] as String : null,
      audioDurationMs: map['audioDurationMs'] is num
          ? (map['audioDurationMs'] as num).toInt().clamp(0, 24 * 60 * 60 * 1000)
          : null,
      attachmentUrl: map['attachmentUrl'] is String
          ? map['attachmentUrl'] as String
          : null,
      attachmentName: map['attachmentName'] is String
          ? map['attachmentName'] as String
          : null,
      attachmentType: map['attachmentType'] is String
          ? map['attachmentType'] as String
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'remetenteId': remetenteId,
      'texto': texto,
      'timestamp': timestamp,
      'lida': lida,
      if (audioUrl != null && audioUrl!.isNotEmpty) 'audioUrl': audioUrl,
      if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
      if (attachmentUrl != null && attachmentUrl!.isNotEmpty)
        'attachmentUrl': attachmentUrl,
      if (attachmentName != null && attachmentName!.isNotEmpty)
        'attachmentName': attachmentName,
      if (attachmentType != null && attachmentType!.isNotEmpty)
        'attachmentType': attachmentType,
    };
  }

  MessageModel copyWith({
    String? id,
    String? remetenteId,
    String? texto,
    DateTime? timestamp,
    bool? lida,
    String? audioUrl,
    int? audioDurationMs,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    String? storagePath,
  }) {
    return MessageModel(
      id: id ?? this.id,
      remetenteId: remetenteId ?? this.remetenteId,
      texto: texto ?? this.texto,
      timestamp: timestamp ?? this.timestamp,
      lida: lida ?? this.lida,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentType: attachmentType ?? this.attachmentType,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

/// Conta as mensagens recebidas que ainda não foram lidas por [userId].
///
/// [readAt] é usado pelos grupos, que guardam um cursor de leitura por
/// utilizador no documento do grupo. O campo `lida` continua a ser respeitado
/// para manter compatibilidade com mensagens antigas.
int countUnreadMessages(
  Iterable<MessageModel> messages,
  String userId, {
  DateTime? readAt,
}) {
  return messages
      .where(
        (message) =>
            message.remetenteId != userId &&
            !message.lida &&
            (readAt == null || message.timestamp.isAfter(readAt)),
      )
      .length;
}
