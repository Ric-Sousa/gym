import 'package:cloud_functions/cloud_functions.dart';
import '../../data/models/booking_model.dart';

/// Dispara notificação de atualização de booking (fire-and-forget).
/// Não bloqueia a UI — erros são silenciados.
void fireBookingNotification(BookingModel booking, String newStatus) {
  FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('notifyBookingUpdate')
      .call({
    'bookingId': booking.id,
    'studentId': booking.studentId,
    'trainerId': booking.trainerId,
    'newStatus': newStatus,
    'bookingDate': booking.data.toIso8601String(),
    'tipo': booking.tipo,
  }); // fire-and-forget
}
