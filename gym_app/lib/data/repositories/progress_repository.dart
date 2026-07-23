import 'dart:typed_data';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/firestore_datasource.dart';
import '../datasources/storage_datasource.dart';
import '../models/progress_model.dart';

/// Repository para progresso físico.
class ProgressRepository {
  final FirestoreDataSource _firestoreDataSource;
  final StorageDataSource _storageDataSource;

  ProgressRepository({
    required FirestoreDataSource firestoreDataSource,
    required StorageDataSource storageDataSource,
  })  : _firestoreDataSource = firestoreDataSource,
        _storageDataSource = storageDataSource;

  /// Obtém histórico de progresso.
  Future<List<ProgressModel>> getHistory(String userId, {int limit = 50}) async {
    try {
      return await _firestoreDataSource.getProgressHistory(userId, limit: limit);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Adiciona nova entrada de progresso.
  Future<void> addProgress(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestoreDataSource.addProgressEntry(userId, data);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Faz upload de foto de progresso.
  Future<String> uploadProgressPhoto(
      String userId, String timestamp, Uint8List bytes) async {
    try {
      final path = 'users/$userId/progresso/$timestamp.jpg';
      return await _storageDataSource.uploadImage(
        path: path,
        fileBytes: bytes,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  /// Faz upload de foto de perfil.
  Future<String> uploadProfilePhoto(String userId, Uint8List bytes) async {
    try {
      final path = 'users/$userId/profile.jpg';
      return await _storageDataSource.uploadImage(
        path: path,
        fileBytes: bytes,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
