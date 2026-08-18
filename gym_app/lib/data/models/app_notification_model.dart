import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String? action;
  final String? paymentId;
  final Map<String, String> metadata;
  final int unreadCount;
  final DateTime createdAt;

  const AppNotificationModel({
    this.id = '',
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.action,
    this.paymentId,
    this.metadata = const {},
    this.unreadCount = 1,
    required this.createdAt,
  });

  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    DateTime createdAt;
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      createdAt = rawDate;
    } else {
      createdAt =
          DateTime.tryParse(rawDate?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    final rawMetadata = map['metadata'];
    final metadata = rawMetadata is Map
        ? rawMetadata.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    final rawUnreadCount = map['unreadCount'];

    return AppNotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? 'Aviso',
      body: map['body'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      action: map['action'] as String?,
      paymentId: map['paymentId'] as String?,
      metadata: metadata,
      unreadCount: rawUnreadCount is num && rawUnreadCount > 0
          ? rawUnreadCount.toInt()
          : 1,
      createdAt: createdAt,
    );
  }

  bool get isChat => type == 'chat' || type.startsWith('chat_');

  /// Identifica a conversa para que várias mensagens do mesmo remetente/grupo
  /// apareçam como um único aviso no sino.
  String get groupKey {
    if (!isChat) return 'notification:$id';
    final salaId = metadata['salaId'];
    if (salaId != null && salaId.isNotEmpty) return 'chat:$salaId';
    return 'chat:$type:$title';
  }

  AppNotificationModel copyWith({bool? read, int? unreadCount, String? body}) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body ?? this.body,
      read: read ?? this.read,
      action: action,
      paymentId: paymentId,
      metadata: metadata,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
    );
  }

  /// Agrupa avisos de mensagens por conversa, mantendo os restantes avisos
  /// individuais. O aviso mais recente representa o conteúdo apresentado.
  static List<AppNotificationModel> groupNotifications(
    Iterable<AppNotificationModel> source,
  ) {
    final grouped = <String, List<AppNotificationModel>>{};
    for (final notification in source) {
      grouped.putIfAbsent(notification.groupKey, () => []).add(notification);
    }

    final result = <AppNotificationModel>[];
    for (final items in grouped.values) {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = items.first;
      final unreadCount = items.fold<int>(
        0,
        (total, item) => total + (item.read ? 0 : item.unreadCount),
      );
      result.add(
        latest.copyWith(
          read: unreadCount == 0,
          unreadCount: unreadCount,
          body: unreadCount > 1
              ? '$unreadCount novas mensagens · Última: ${latest.body}'
              : latest.body,
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}
