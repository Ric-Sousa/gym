import 'package:uuid/uuid.dart';

import '../../core/services/audio_recording_model.dart';
import '../../data/datasources/storage_datasource.dart';
import '../../data/models/message_model.dart';

Future<MessageModel> createUploadedAudioMessage({
  required StorageDataSource storage,
  required String senderId,
  required String chatId,
  required RecordedAudio audio,
}) async {
  final timestamp = DateTime.now();
  final path =
      'chat_audio/$chatId/${senderId}_${const Uuid().v4()}.${audio.extension}';
  final storagePath = await storage.uploadFile(
    path: path,
    fileBytes: audio.bytes,
    contentType: audio.contentType,
  );
  return MessageModel(
    remetenteId: senderId,
    texto: '',
    timestamp: timestamp,
    audioUrl: storagePath,
    audioDurationMs: audio.durationMs,
    storagePath: path,
  );
}
