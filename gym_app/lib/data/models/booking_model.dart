/// Modelo de marcação de aula/sessão com PT.
class BookingModel {
  final String id;
  final String studentId;
  final String trainerId;
  final DateTime data;
  final int duracaoMinutos;
  final String status; // pending/confirmed/cancelled/completed e equivalentes legados
  final String? notas;
  final String tipo; // 'presencial', 'online'
  final DateTime? createdAt;

  const BookingModel({
    this.id = '',
    required this.studentId,
    required this.trainerId,
    required this.data,
    this.duracaoMinutos = 60,
    this.status = 'pending',
    this.notas,
    this.tipo = 'presencial',
    this.createdAt,
  });

  factory BookingModel.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['status'];
    final parsedDate = _parseDate(map['data']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final parsedCreatedAt = _parseDate(map['createdAt']);
    final status = rawStatus is String && rawStatus.trim().isNotEmpty
        ? rawStatus
        : map['approved'] == true || map['aprovado'] == true
        ? 'confirmed'
        : map['rejected'] == true ||
              map['recusado'] == true ||
              map['recusada'] == true
        ? 'cancelled'
        : 'pending';

    return BookingModel(
      id: id,
      studentId: map['studentId'] is String ? map['studentId'] as String : '',
      trainerId: map['trainerId'] is String ? map['trainerId'] as String : '',
      data: parsedDate,
      duracaoMinutos: map['duracaoMinutos'] is num
          ? (map['duracaoMinutos'] as num).toInt().clamp(1, 1440)
          : 60,
      status: status,
      notas: map['notas'] is String ? map['notas'] as String : null,
      tipo: map['tipo'] is String ? map['tipo'] as String : 'presencial',
      createdAt: parsedCreatedAt,
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
      'studentId': studentId,
      'trainerId': trainerId,
      'data': data,
      'duracaoMinutos': duracaoMinutos,
      'status': status,
      'tipo': tipo,
      if (notas != null) 'notas': notas,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  String get normalizedStatus => status
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_');

  bool get isConfirmed => const {
    'confirmed',
    'approved',
    'accepted',
    'aprovado',
    'aprovada',
    'aceite',
    'aceita',
  }.contains(normalizedStatus);

  bool get isPending => const {
    'pending',
    'pendente',
    'aguarda_aprovacao',
    'aguardando_aprovacao',
    'aguarda_aprovação',
    'aguardando_aprovação',
  }.contains(normalizedStatus);

  bool get isCancelled => const {
    'cancelled',
    'canceled',
    'rejected',
    'declined',
    'recusado',
    'recusada',
    'rejeitado',
    'rejeitada',
    'cancelado',
    'cancelada',
  }.contains(normalizedStatus);

  bool get isCompleted => const {
    'completed',
    'complete',
    'concluido',
    'concluída',
    'concluida',
  }.contains(normalizedStatus);

  String get horaFormatada =>
      '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  String get fimFormatado {
    final fim = data.add(Duration(minutes: duracaoMinutos));
    return '${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}';
  }
}
