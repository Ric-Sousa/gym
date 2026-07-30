import '../datasources/firestore_datasource.dart';
import '../models/booking_model.dart';

/// Repositório de marcações de aulas (agenda).
class BookingRepository {
  final FirestoreDataSource _firestore;

  BookingRepository({required FirestoreDataSource firestoreDataSource})
      : _firestore = firestoreDataSource;

  /// Marcações do aluno.
  Future<List<BookingModel>> getStudentBookings(String studentId) {
    return _firestore.getStudentBookings(studentId);
  }

  /// Marcações do trainer (admin).
  Future<List<BookingModel>> getTrainerBookings(String trainerId) {
    return _firestore.getTrainerBookings(trainerId);
  }

  /// Adiciona uma nova marcação.
  Future<void> addBooking(Map<String, dynamic> data) {
    return _firestore.addBooking(data);
  }

  /// Atualiza estado de uma marcação.
  Future<void> updateBooking(String id, Map<String, dynamic> data) {
    return _firestore.updateBooking(id, data);
  }

  /// Stream de marcações do aluno.
  Stream<List<BookingModel>> watchStudentBookings(String studentId) {
    return _firestore.watchStudentBookings(studentId);
  }

  /// Stream de marcações confirmadas/pending do trainer (para conflitos).
  Stream<List<BookingModel>> watchTrainerBookings(String trainerId) {
    return _firestore.watchTrainerBookings(trainerId);
  }
}
