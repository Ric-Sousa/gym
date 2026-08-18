import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/storage_resource.dart';

/// Data source para Firebase Storage.
class StorageDataSource {
  final FirebaseStorage _storage;

  StorageDataSource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Faz upload de uma imagem e retorna o path privado, não um URL bearer.
  Future<String> uploadImage({
    required String path,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    _validatePath(path);
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
      );
      await ref.putData(fileBytes, metadata);
      return ref.fullPath;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao fazer upload');
    }
  }

  /// Faz upload de um ficheiro e retorna o path privado.
  Future<String> uploadFile({
    required String path,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    _validatePath(path);
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      await ref.putData(fileBytes, metadata);
      return ref.fullPath;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao fazer upload');
    }
  }

  /// Apaga um ficheiro.
  Future<void> deleteFile(String path) async {
    _validatePath(path);
    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao apagar ficheiro');
    }
  }

  void _validatePath(String path) {
    if (!StorageResource.isPrivatePath(path)) {
      throw ValidationException(message: 'Path Storage inválido.');
    }
  }
}
