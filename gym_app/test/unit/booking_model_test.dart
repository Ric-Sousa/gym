import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/booking_model.dart';

void main() {
  BookingModel bookingWithStatus(String status) => BookingModel(
        studentId: 'student-1',
        trainerId: 'trainer-1',
        data: DateTime(2026, 8, 18, 10),
        status: status,
      );

  group('BookingModel status', () {
    test('recognizes approved and accepted legacy statuses', () {
      for (final status in ['confirmed', 'approved', 'accepted', 'aprovada']) {
        final booking = bookingWithStatus(status);
        expect(booking.isConfirmed, isTrue, reason: status);
        expect(booking.isPending, isFalse, reason: status);
      }
    });

    test('recognizes rejected and cancelled legacy statuses', () {
      for (final status in [
        'cancelled',
        'rejected',
        'declined',
        'recusada',
        'rejeitada',
      ]) {
        final booking = bookingWithStatus(status);
        expect(booking.isCancelled, isTrue, reason: status);
        expect(booking.isPending, isFalse, reason: status);
      }
    });

    test('only pending statuses remain pending', () {
      for (final status in ['pending', 'pendente', 'aguarda_aprovacao']) {
        final booking = bookingWithStatus(status);
        expect(booking.isPending, isTrue, reason: status);
        expect(booking.isConfirmed, isFalse, reason: status);
        expect(booking.isCancelled, isFalse, reason: status);
      }
    });
  });
}
