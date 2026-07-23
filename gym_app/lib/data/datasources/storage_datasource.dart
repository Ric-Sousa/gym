import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/errors/exceptions.dart';

/// Data source para Firebase Storage.
class StorageDataSource {
  final FirebaseStorage _storage;

  StorageDataSource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Faz upload de uma imagem e retorna a URL.
  Future<String> uploadImage({
    required String path,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType ?? 'image/jpeg');
      await ref.putData(fileBytes, metadata);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao fazer upload');
    }
  }

  /// Faz upload de um ficheiro.
  Future<String> uploadFile({
    required String path,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      await ref.putData(fileBytes, metadata);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao fazer upload');
    }
  }

  /// Obtém a URL de download de um ficheiro.
  Future<String> getDownloadURL(String path) async {
    try {
      return await _storage.ref().child(path).getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao obter URL de download');
    }
  }

  /// Apaga um ficheiro.
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao apagar ficheiro');
    }
  }
}
