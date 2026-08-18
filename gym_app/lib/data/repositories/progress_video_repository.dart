import 'dart:typed_data';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/config/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../datasources/storage_datasource.dart';
import '../models/progress_video_model.dart';

class ProgressVideoRepository {
  final FirestoreDataSource _firestore;
  final StorageDataSource _storage;

  ProgressVideoRepository({
    required FirestoreDataSource firestore,
    required StorageDataSource storage,
  }) : _firestore = firestore,
       _storage = storage;

  Future<List<ProgressVideoModel>> getVideos(String userId) async {
    try {
      return await _firestore.getProgressVideos(userId);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  Stream<List<ProgressVideoModel>> watchVideos(String userId) {
    return _firestore.watchProgressVideos(userId);
  }

  Future<ProgressVideoModel> uploadVideo({
    required String userId,
    required String uploaderId,
    required String exerciseName,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    try {
      const allowedTypes = {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'webm': 'video/webm',
        'avi': 'video/x-msvideo',
      };
      final normalizedExtension = extension.toLowerCase();
      if (!allowedTypes.containsKey(normalizedExtension) ||
          contentType != allowedTypes[normalizedExtension] ||
          bytes.length > 200 * 1024 * 1024) {
        throw ValidationException(message: 'Formato ou tamanho de vídeo inválido.');
      }
      final videoId = '${DateTime.now().microsecondsSinceEpoch}';
      final path =
          '${AppConstants.progressVideoPath.replaceAll('{userId}', userId).replaceAll('{videoId}', videoId)}.$normalizedExtension';
      final storagePath = await _storage.uploadFile(
        path: path,
        fileBytes: bytes,
        contentType: contentType,
      );
      final video = ProgressVideoModel(
        id: videoId,
        userId: userId,
        exerciseName: exerciseName,
        videoUrl: storagePath,
        createdAt: DateTime.now(),
        uploadedBy: uploaderId,
      );
      try {
        await _firestore.addProgressVideo(userId, videoId, video.toMap());
      } catch (_) {
        await _storage.deleteFile(path).catchError((_) {});
        rethrow;
      }
      return video;
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  Future<void> reviewVideo(
    String userId,
    String videoId, {
    required String status,
    String? feedback,
  }) async {
    try {
      await _firestore.updateProgressVideo(userId, videoId, {
        'status': status,
        'feedback': feedback,
        'reviewedAt': DateTime.now(),
      });
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
