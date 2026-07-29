/// Modelo de pagamento no Firestore.
class PaymentModel {
  final String id;
  final String userId;
  final double valor;
  final String moeda; // 'eur', 'usd'
  final String status; // 'pending', 'paid', 'failed', 'refunded'
  final DateTime data;
  final String? descricao;
  final String? faturaUrl;
  final String? stripeSessionId;
  final String? stripePaymentIntentId;

  const PaymentModel({
    this.id = '',
    required this.userId,
    required this.valor,
    this.moeda = 'eur',
    this.status = 'pending',
    required this.data,
    this.descricao,
    this.faturaUrl,
    this.stripeSessionId,
    this.stripePaymentIntentId,
  });

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      moeda: map['moeda'] as String? ?? 'eur',
      status: map['status'] as String? ?? 'pending',
      data: (map['data'] as dynamic).toDate() as DateTime,
      descricao: map['descricao'] as String?,
      faturaUrl: map['faturaUrl'] as String?,
      stripeSessionId: map['stripeSessionId'] as String?,
      stripePaymentIntentId: map['stripePaymentIntentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'valor': valor,
      'moeda': moeda,
      'status': status,
      'data': data,
      if (descricao != null) 'descricao': descricao,
      if (faturaUrl != null) 'faturaUrl': faturaUrl,
      if (stripeSessionId != null) 'stripeSessionId': stripeSessionId,
      if (stripePaymentIntentId != null)
        'stripePaymentIntentId': stripePaymentIntentId,
    };
  }

  String get valorFormatado => '${valor.toStringAsFixed(2)} ${moeda.toUpperCase()}';
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
}
