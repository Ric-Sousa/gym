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
  final String? audioUrl;
  final int? audioDurationMs;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;

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
  });

  bool get isAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get isAttachment =>
      attachmentUrl != null && attachmentUrl!.trim().isNotEmpty;

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = _parseTimestamp(map['timestamp']);
    return MessageModel(
      id: id,
      remetenteId: map['remetenteId'] as String? ?? '',
      texto: map['texto'] as String? ?? '',
      timestamp: timestamp,
      lida: map['lida'] as bool? ?? false,
      audioUrl: map['audioUrl'] as String?,
      audioDurationMs: (map['audioDurationMs'] as num?)?.toInt(),
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      attachmentType: map['attachmentType'] as String?,
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
    );
  }
}
