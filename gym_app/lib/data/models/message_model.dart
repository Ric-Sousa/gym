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

  const MessageModel({
    this.id = '',
    required this.remetenteId,
    required this.texto,
    required this.timestamp,
    this.lida = false,
    this.audioUrl,
    this.audioDurationMs,
  });

  bool get isAudio => audioUrl != null && audioUrl!.isNotEmpty;

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
  }) {
    return MessageModel(
      id: id ?? this.id,
      remetenteId: remetenteId ?? this.remetenteId,
      texto: texto ?? this.texto,
      timestamp: timestamp ?? this.timestamp,
      lida: lida ?? this.lida,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
    );
  }
}
