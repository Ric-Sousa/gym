import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../datasources/firestore_datasource.dart';
import '../models/payment_model.dart';

/// Repositório de pagamentos (Stripe + Firestore).
class PaymentRepository {
  final FirestoreDataSource _firestore;

  PaymentRepository({required FirestoreDataSource firestoreDataSource})
      : _firestore = firestoreDataSource;

  /// Cria uma sessão de checkout Stripe (admin) e guarda pagamento pendente.
  /// Retorna o URL da página de pagamento.
  Future<String> createCheckoutSession({
    required String userId,
    required double valor,
    String? descricao,
  }) async {
    final fn = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    );
    final callable = fn.httpsCallable('createCheckoutSession');

    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'valor': valor,
      if (descricao != null) 'descricao': descricao,
    });

    final url = result.data['url'] as String;
    return url;
  }

  /// Obtém pagamentos de um utilizador específico.
  Future<List<PaymentModel>> getPayments(String userId) {
    return _firestore.getPayments(userId);
  }

  /// Obtém todos os pagamentos (admin).
  Future<List<PaymentModel>> getAllPayments() {
    return _firestore.getAllPayments();
  }

  /// Stream de pagamentos de um utilizador.
  Stream<List<PaymentModel>> watchPayments(String userId) {
    return FirebaseFirestore.instance
        .collection('pagamentos')
        .where('userId', isEqualTo: userId)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => PaymentModel.fromMap(doc.id, doc.data())).toList());
  }
}
