/// Modelo de marcação de aula/sessão com PT.
class BookingModel {
  final String id;
  final String studentId;
  final String trainerId;
  final DateTime data;
  final int duracaoMinutos;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
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
    return BookingModel(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      data: (map['data'] as dynamic).toDate() as DateTime,
      duracaoMinutos: map['duracaoMinutos'] as int? ?? 60,
      status: map['status'] as String? ?? 'pending',
      notas: map['notas'] as String?,
      tipo: map['tipo'] as String? ?? 'presencial',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate() as DateTime
          : null,
    );
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

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  String get horaFormatada =>
      '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  String get fimFormatado {
    final fim = data.add(Duration(minutes: duracaoMinutos));
    return '${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}';
  }
}
