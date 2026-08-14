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
    required this.createdAt,
  });

  factory AppNotificationModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final rawDate = map['createdAt'];
    DateTime createdAt;
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      createdAt = rawDate;
    } else {
      createdAt = DateTime.tryParse(rawDate?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return AppNotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? 'Aviso',
      body: map['body'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      action: map['action'] as String?,
      paymentId: map['paymentId'] as String?,
      createdAt: createdAt,
    );
  }

  AppNotificationModel copyWith({bool? read}) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      read: read ?? this.read,
      action: action,
      paymentId: paymentId,
      createdAt: createdAt,
    );
  }
}
