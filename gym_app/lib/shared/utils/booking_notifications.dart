import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/booking_model.dart';

/// Dispara notificação de atualização de booking (fire-and-forget).
/// Não bloqueia a UI — erros são silenciados.
void fireBookingNotification(BookingModel booking, String newStatus) {
  () async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('notifyBookingUpdate').call({
        'bookingId': booking.id,
        'newStatus': newStatus,
      });
    } on FirebaseFunctionsException catch (_) {
      // Notificação é best-effort e não deve interromper a alteração da aula.
    } catch (_) {
      // Ignora falhas de rede/autenticação.
    }
  }();
}
