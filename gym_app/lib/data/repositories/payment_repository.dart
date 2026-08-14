import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../datasources/firestore_datasource.dart';
import '../models/payment_model.dart';

/// Repositório de pagamentos (Stripe + Firestore).
class PaymentRepository {
  final FirestoreDataSource _firestore;

  PaymentRepository({required FirestoreDataSource firestoreDataSource})
    : _firestore = firestoreDataSource;

  /// Cria uma cobrança pendente com período calculado pelo servidor.
  Future<String> createPaymentSchedule({
    required String userId,
    required double valor,
    required String tipoMensalidade,
  }) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('createPaymentSchedule');
    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'valor': valor,
      'tipoMensalidade': tipoMensalidade,
    });
    return result.data['paymentId'] as String;
  }

  /// Cria o checkout da subscrição para o cliente autenticado.
  Future<String> createPaymentCheckoutSession({
    required String paymentId,
  }) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('createPaymentCheckoutSession');
    final result = await callable.call<Map<String, dynamic>>({
      'paymentId': paymentId,
    });
    return result.data['url'] as String;
  }

  /// Compatibilidade com sessões Stripe antigas criadas pelo admin.
  Future<String> createCheckoutSession({
    required String userId,
    required double valor,
    String? descricao,
    DateTime? periodoInicio,
    DateTime? periodoFim,
    DateTime? dataVencimento,
  }) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('createCheckoutSession');

    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'valor': valor,
      if (descricao != null) 'descricao': descricao,
      if (periodoInicio != null)
        'periodoInicio': periodoInicio.toIso8601String(),
      if (periodoFim != null) 'periodoFim': periodoFim.toIso8601String(),
      if (dataVencimento != null)
        'dataVencimento': dataVencimento.toIso8601String(),
    });

    final url = result.data['url'] as String;
    return url;
  }

  /// Cancela uma cobrança pendente através da Cloud Function.
  Future<void> cancelPayment({required String paymentId}) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('cancelPayment');
    await callable.call<Map<String, dynamic>>({'paymentId': paymentId});
  }

  /// Cancela apenas a renovação automática no fim do período pago.
  Future<void> cancelPaymentSubscription({required String paymentId}) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('cancelPaymentSubscription');
    await callable.call<Map<String, dynamic>>({'paymentId': paymentId});
  }

  /// Cria checkout público para um cliente bloqueado por atraso.
  Future<String> createRecoveryCheckoutSession({required String token}) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('createPaymentRecoveryCheckoutSession');
    final result = await callable.call<Map<String, dynamic>>({'token': token});
    return result.data['url'] as String;
  }

  Future<void> resendPaymentRecovery({required String paymentId}) async {
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = fn.httpsCallable('resendPaymentRecovery');
    await callable.call<Map<String, dynamic>>({'paymentId': paymentId});
  }

  /// Obtém pagamentos de um utilizador específico.
  Future<List<PaymentModel>> getPayments(String userId) {
    return _firestore.getPayments(userId);
  }

  /// Obtém todos os pagamentos (admin).
  Future<List<PaymentModel>> getAllPayments() {
    return _firestore.getAllPayments();
  }

  Future<void> addManualPayment(Map<String, dynamic> data) {
    return _firestore.addPayment(data);
  }

  Future<void> updatePayment(String id, Map<String, dynamic> data) {
    return _firestore.updatePayment(id, data);
  }

  /// Stream de pagamentos de um utilizador.
  ///
  /// A ordenação é feita localmente para não exigir um índice composto
  /// (userId + data) e evitar tentativas repetidas do listener Web quando
  /// esse índice não está criado no Firestore.
  Stream<List<PaymentModel>> watchPayments(String userId) {
    return FirebaseFirestore.instance
        .collection('pagamentos')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final payments = snap.docs
              .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
              .toList();
          payments.sort((a, b) => b.data.compareTo(a.data));
          return payments;
        });
  }
}
