/// Modelo de pagamento no Firestore.
class PaymentModel {
  final String id;
  final String userId;
  final double valor;
  final String moeda; // 'eur', 'usd'
  final String status; // 'pending', 'scheduled', 'paid', 'failed', 'refunded', 'cancelled'
  final DateTime data;
  final String? descricao;
  final String? faturaUrl;
  final String? stripeSessionId;
  final String? stripePaymentIntentId;
  final String? stripeSubscriptionId;
  final String? stripeInvoiceId;
  final String? stripeHostedInvoiceUrl;
  final String? tipoMensalidade; // 'mensal', 'trimestral' ou 'anual'
  final DateTime? periodoInicio;
  final DateTime? periodoFim;
  final DateTime? dataVencimento;
  final DateTime? paidAt;
  final String? metodo;
  final String? comprovativoUrl;
  final bool subscriptionCancelAtPeriodEnd;

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
    this.stripeSubscriptionId,
    this.stripeInvoiceId,
    this.stripeHostedInvoiceUrl,
    this.tipoMensalidade,
    this.periodoInicio,
    this.periodoFim,
    this.dataVencimento,
    this.paidAt,
    this.metodo,
    this.comprovativoUrl,
    this.subscriptionCancelAtPeriodEnd = false,
  });

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      moeda: map['moeda'] as String? ?? 'eur',
      status: map['status'] as String? ?? 'pending',
      data: _dateFromMap(map['data']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      descricao: map['descricao'] as String?,
      faturaUrl: map['faturaUrl'] as String?,
      stripeSessionId: map['stripeSessionId'] as String?,
      stripePaymentIntentId: map['stripePaymentIntentId'] as String?,
      stripeSubscriptionId: map['stripeSubscriptionId'] as String?,
      stripeInvoiceId: map['stripeInvoiceId'] as String?,
      stripeHostedInvoiceUrl: map['stripeHostedInvoiceUrl'] as String?,
      tipoMensalidade: map['tipoMensalidade'] as String?,
      periodoInicio: _dateFromMap(map['periodoInicio']),
      periodoFim: _dateFromMap(map['periodoFim']),
      dataVencimento: _dateFromMap(map['dataVencimento']),
      paidAt: _dateFromMap(map['paidAt']),
      metodo: map['metodo'] as String?,
      comprovativoUrl: map['comprovativoUrl'] as String?,
      subscriptionCancelAtPeriodEnd:
          map['subscriptionCancelAtPeriodEnd'] as bool? ?? false,
    );
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
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
      if (stripeSubscriptionId != null)
        'stripeSubscriptionId': stripeSubscriptionId,
      if (stripeInvoiceId != null) 'stripeInvoiceId': stripeInvoiceId,
      if (stripeHostedInvoiceUrl != null)
        'stripeHostedInvoiceUrl': stripeHostedInvoiceUrl,
      if (tipoMensalidade != null) 'tipoMensalidade': tipoMensalidade,
      if (periodoInicio != null) 'periodoInicio': periodoInicio,
      if (periodoFim != null) 'periodoFim': periodoFim,
      if (dataVencimento != null) 'dataVencimento': dataVencimento,
      if (paidAt != null) 'paidAt': paidAt,
      if (metodo != null) 'metodo': metodo,
      if (comprovativoUrl != null) 'comprovativoUrl': comprovativoUrl,
      if (subscriptionCancelAtPeriodEnd)
        'subscriptionCancelAtPeriodEnd': true,
    };
  }

  String get valorFormatado =>
      '${valor.toStringAsFixed(2)} ${moeda.toUpperCase()}';
  String get effectiveStatus => isOverdue ? 'overdue' : status;
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get canStartCheckout =>
      !isPaid &&
      !isCancelled &&
      status != 'refunded' &&
      status != 'scheduled' &&
      stripeHostedInvoiceUrl == null &&
      stripeSubscriptionId == null;
  String get tipoMensalidadeLabel {
    switch (tipoMensalidade) {
      case 'trimestral':
        return 'Trimestral';
      case 'anual':
        return 'Anual';
      case 'mensal':
        return 'Mensal';
      default:
        return 'Pagamento';
    }
  }
  bool get isOverdue {
    if (isPaid || isCancelled || status == 'refunded' || isScheduled) return false;
    final deadline = dataVencimento ?? periodoFim;
    return deadline != null && !deadline.isAfter(DateTime.now());
  }
}
