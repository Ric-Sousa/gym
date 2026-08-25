import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/storage_datasource.dart';
import '../../data/models/message_model.dart';

Future<MessageModel> createUploadedImageMessage({
  required StorageDataSource storage,
  required String senderId,
  required String chatId,
  required XFile file,
  bool isGroupChat = false,
}) async {
  final bytes = Uint8List.fromList(await file.readAsBytes());
  final extension = file.name.contains('.')
      ? file.name.split('.').last.toLowerCase()
      : 'jpg';
  final contentType = file.mimeType ?? 'image/$extension';
  final root = isGroupChat ? 'group_chat_attachments' : 'chat_attachments';
  final path = '$root/$chatId/${senderId}_${const Uuid().v4()}.$extension';
  final storagePath = await storage.uploadFile(
    path: path,
    fileBytes: bytes,
    contentType: contentType,
  );

  return MessageModel(
    remetenteId: senderId,
    texto: '',
    timestamp: DateTime.now(),
    attachmentUrl: storagePath,
    attachmentName: file.name,
    attachmentType: contentType,
    storagePath: path,
  );
}

/// Remove o upload quando a mensagem não chega a ser persistida.
Future<void> cleanupUploadedMessage(
  StorageDataSource storage,
  MessageModel? message,
) async {
  final path = message?.storagePath;
  if (path == null || path.isEmpty) return;
  await storage.deleteFile(path).catchError((_) {});
}
