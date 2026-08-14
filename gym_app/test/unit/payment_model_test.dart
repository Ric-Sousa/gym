import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/payment_model.dart';

void main() {
  test('marks unpaid payment past due date as overdue', () {
    final payment = PaymentModel(
      userId: 'u1',
      valor: 30,
      data: DateTime.now(),
      status: 'pending',
      dataVencimento: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(payment.isOverdue, isTrue);
    expect(payment.effectiveStatus, 'overdue');
  });

  test('paid payment is never overdue', () {
    final payment = PaymentModel(
      userId: 'u1',
      valor: 30,
      data: DateTime.now(),
      status: 'paid',
      dataVencimento: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(payment.isOverdue, isFalse);
    expect(payment.effectiveStatus, 'paid');
  });

  test('scheduled payment is not overdue before its due date', () {
    final payment = PaymentModel(
      userId: 'u1',
      valor: 30,
      data: DateTime.now(),
      status: 'scheduled',
      dataVencimento: DateTime.now().subtract(const Duration(days: 1)),
      stripeSubscriptionId: 'sub_123',
    );

    expect(payment.isOverdue, isFalse);
    expect(payment.canStartCheckout, isFalse);
    expect(payment.tipoMensalidadeLabel, 'Pagamento');
  });

  test('cancelled payment is not overdue or available for checkout', () {
    final payment = PaymentModel(
      userId: 'u1',
      valor: 30,
      data: DateTime.now(),
      status: 'cancelled',
      dataVencimento: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(payment.isCancelled, isTrue);
    expect(payment.isOverdue, isFalse);
    expect(payment.canStartCheckout, isFalse);
  });

  test('serializes period and payment metadata', () {
    final start = DateTime(2026, 8, 1);
    final end = DateTime(2026, 8, 31);
    final payment = PaymentModel(
      userId: 'u1',
      valor: 30,
      data: start,
      periodoInicio: start,
      periodoFim: end,
      metodo: 'transferência',
    );
    final map = payment.toMap();
    expect(map['periodoInicio'], start);
    expect(map['periodoFim'], end);
    expect(map['metodo'], 'transferência');
  });
}
