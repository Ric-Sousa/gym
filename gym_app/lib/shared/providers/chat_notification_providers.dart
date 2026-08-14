import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Evento comum para os sons de mensagens recebidas.
class StableChatNotification {
  final String roomId;
  final DateTime timestamp;

  const StableChatNotification({required this.roomId, required this.timestamp});
}

DateTime? _timestampFrom(
  Map<String, dynamic>? data, [
  String key = 'timestamp',
]) {
  final value = data?[key];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _directRoomId(String firstId, String secondId) {
  final ids = [firstId, secondId]..sort();
  return '${AppConstants.chatRoomPrefix}_${ids[0]}_${ids[1]}';
}

/// Mensagens diretas recebidas pelo aluno. Observa apenas a sala do seu PT.
final stableAlunoChatNotificationProvider =
    StreamProvider.family<StableChatNotification, String>((ref, userId) {
      if (userId.isEmpty) return const Stream.empty();
      final personalId = ref.watch(authProvider).user?.personalId ?? '';
      if (personalId.isEmpty || personalId == userId) {
        return const Stream.empty();
      }

      final roomId = _directRoomId(userId, personalId);
      final firestore = FirebaseFirestore.instance;
      final controller = StreamController<StableChatNotification>();
      final seenIds = <String>{};
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
      var disposed = false;

      void emit(DocumentSnapshot<Map<String, dynamic>> doc) {
        if (controller.isClosed) return;
        final data = doc.data();
        if (data == null || data['remetenteId'] == userId) return;
        final timestamp = _timestampFrom(data);
        if (timestamp != null) {
          controller.add(
            StableChatNotification(roomId: roomId, timestamp: timestamp),
          );
        }
      }

      late void Function() start;

      start = () {
        if (disposed) return;
        subscription?.cancel();
        var initial = true;
        subscription = firestore
            .collection(AppConstants.chatCollection)
            .doc(roomId)
            .collection(AppConstants.messagesSubcollection)
            .snapshots()
            .listen((snapshot) {
              if (initial) {
                initial = false;
                seenIds.addAll(snapshot.docs.map((doc) => doc.id));
                return;
              }
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added &&
                    seenIds.add(change.doc.id)) {
                  emit(change.doc);
                }
              }
            }, onError: (_) {
              // O SDK do Firestore gere a reconexão de listeners. Não
              // reiniciar manualmente em loop quando há erro de rede/permissão.
            });
      };

      start();
      ref.onDispose(() {
        disposed = true;
        subscription?.cancel();
        controller.close();
      });
      return controller.stream;
    });

/// Mensagens de grupos recebidas pelo aluno. Apenas grupos onde ele é membro
/// são consultados, em vez de uma collectionGroup global.
final stableAlunoGroupNotificationProvider =
    StreamProvider.family<StableChatNotification, String>((ref, userId) {
      if (userId.isEmpty) return const Stream.empty();

      final firestore = FirebaseFirestore.instance;
      final controller = StreamController<StableChatNotification>();
      final subscriptions =
          <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
      final seenIdsByGroup = <String, Set<String>>{};
      final initialGroupIds = <String>{};
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      groupsSubscription;
      var groupsInitial = true;
      var disposed = false;

      void emit(String groupId, DocumentSnapshot<Map<String, dynamic>> doc) {
        if (controller.isClosed) return;
        final data = doc.data();
        if (data == null || data['remetenteId'] == userId) return;
        final timestamp = _timestampFrom(data);
        if (timestamp != null) {
          controller.add(
            StableChatNotification(roomId: groupId, timestamp: timestamp),
          );
        }
      }

      late void Function() start;

      void cancelChildren() {
        for (final subscription in subscriptions.values) {
          subscription.cancel();
        }
        subscriptions.clear();
      }

      void watchGroup(String groupId) {
        if (subscriptions.containsKey(groupId)) return;
        var initial = true;
        subscriptions[groupId] = firestore
            .collection(AppConstants.groupsCollection)
            .doc(groupId)
            .collection(AppConstants.groupMessagesSubcollection)
            .snapshots()
            .listen(
              (snapshot) {
                final seen = seenIdsByGroup.putIfAbsent(
                  groupId,
                  () => <String>{},
                );
                if (initial) {
                  initial = false;
                  if (!initialGroupIds.contains(groupId) &&
                      snapshot.docs.isNotEmpty) {
                    DocumentSnapshot<Map<String, dynamic>>? latest;
                    DateTime? latestAt;
                    for (final doc in snapshot.docs) {
                      final at = _timestampFrom(doc.data());
                      if (at != null &&
                          (latestAt == null || at.isAfter(latestAt))) {
                        latest = doc;
                        latestAt = at;
                      }
                    }
                    if (latest != null && seen.add(latest.id)) {
                      emit(groupId, latest);
                    }
                  }
                  seen.addAll(snapshot.docs.map((doc) => doc.id));
                  return;
                }
                for (final change in snapshot.docChanges) {
                  if (change.type == DocumentChangeType.added &&
                      seen.add(change.doc.id)) {
                    emit(groupId, change.doc);
                  }
                }
              },
              onError: (_) {
                // Não reiniciar este listener em loop. O SDK gere as
                // reconexões transitórias do Firestore.
                subscriptions.remove(groupId)?.cancel();
              },
            );
      }

      start = () {
        if (disposed) return;
        groupsSubscription?.cancel();
        cancelChildren();
        initialGroupIds.clear();
        seenIdsByGroup.clear();
        groupsInitial = true;
        groupsSubscription = firestore
            .collection(AppConstants.groupsCollection)
            .where('membros', arrayContains: userId)
            .snapshots()
            .listen((snapshot) {
              final currentIds = snapshot.docs.map((doc) => doc.id).toSet();
              if (groupsInitial) {
                initialGroupIds.addAll(currentIds);
                groupsInitial = false;
              }
              for (final oldId in subscriptions.keys.toList()) {
                if (!currentIds.contains(oldId)) {
                  subscriptions.remove(oldId)?.cancel();
                  seenIdsByGroup.remove(oldId);
                }
              }
              for (final groupId in currentIds) {
                watchGroup(groupId);
              }
            }, onError: (_) {
              // O SDK do Firestore gere a reconexão de listeners. Não
              // reiniciar manualmente em loop quando há erro de rede/permissão.
            });
      };

      start();
      ref.onDispose(() {
        disposed = true;
        groupsSubscription?.cancel();
        cancelChildren();
        controller.close();
      });
      return controller.stream;
    });

/// Mensagens diretas recebidas pelo admin. Usa `lastMessageId` para distinguir
/// mensagens consecutivas que tenham o mesmo timestamp.
final stableAdminChatNotificationProvider =
    StreamProvider<StableChatNotification>((ref) {
      final adminId = ref.watch(authProvider).user?.uid ?? '';
      if (adminId.isEmpty) return const Stream.empty();

      final firestore = FirebaseFirestore.instance;
      final controller = StreamController<StableChatNotification>();
      final lastCursorByRoom = <String, String>{};
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
      var initial = true;
      var disposed = false;

      late void Function() start;

      start = () {
        if (disposed) return;
        subscription?.cancel();
        initial = true;
        subscription = firestore
            .collection(AppConstants.chatCollection)
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'chat_')
            .where(FieldPath.documentId, isLessThanOrEqualTo: 'chat_\uf8ff')
            .snapshots()
            .listen((snapshot) {
              for (final change in snapshot.docChanges) {
                final data = change.doc.data();
                if (data == null) continue;
                final parts = change.doc.id.split('_');
                if (parts.length < 3 ||
                    (parts[1] != adminId && parts[2] != adminId)) {
                  continue;
                }
                final senderId = data['lastSenderId'] as String? ?? '';
                final messageId = data['lastMessageId'] as String? ?? '';
                final timestamp = _timestampFrom(data, 'lastTimestamp');
                if (timestamp == null) continue;

                final roomId = change.doc.id;
                final cursor = messageId.isNotEmpty
                    ? messageId
                    : '${timestamp.microsecondsSinceEpoch}:$senderId';
                final previous = lastCursorByRoom[roomId];
                lastCursorByRoom[roomId] = cursor;
                if (initial || previous == cursor || senderId == adminId) {
                  continue;
                }
                if (!controller.isClosed) {
                  controller.add(
                    StableChatNotification(
                      roomId: roomId,
                      timestamp: timestamp,
                    ),
                  );
                }
              }
              initial = false;
            }, onError: (_) {
              // O SDK do Firestore gere a reconexão de listeners. Não
              // reiniciar manualmente em loop quando há erro de rede/permissão.
            });
      };

      start();
      ref.onDispose(() {
        disposed = true;
        subscription?.cancel();
        controller.close();
      });
      return controller.stream;
    });

/// Mensagens dos grupos recebidas pelo admin, sem collectionGroup.
final stableAdminGroupNotificationProvider =
    StreamProvider<StableChatNotification>((ref) {
      final adminId = ref.watch(authProvider).user?.uid ?? '';
      if (adminId.isEmpty) return const Stream.empty();

      final firestore = FirebaseFirestore.instance;
      final controller = StreamController<StableChatNotification>();
      final subscriptions =
          <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
      final seenIdsByGroup = <String, Set<String>>{};
      final initialGroupIds = <String>{};
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      groupsSubscription;
      var initialGroupsSnapshot = true;
      var disposed = false;

      void emit(String groupId, DocumentSnapshot<Map<String, dynamic>> doc) {
        if (controller.isClosed) return;
        final data = doc.data();
        if (data == null || data['remetenteId'] == adminId) return;
        final timestamp = _timestampFrom(data);
        if (timestamp != null) {
          controller.add(
            StableChatNotification(roomId: groupId, timestamp: timestamp),
          );
        }
      }

      late void Function() start;

      void cancelChildren() {
        for (final subscription in subscriptions.values) {
          subscription.cancel();
        }
        subscriptions.clear();
      }

      void watchGroup(String groupId) {
        if (subscriptions.containsKey(groupId)) return;
        var initial = true;
        subscriptions[groupId] = firestore
            .collection(AppConstants.groupsCollection)
            .doc(groupId)
            .collection(AppConstants.groupMessagesSubcollection)
            .snapshots()
            .listen(
              (snapshot) {
                final seen = seenIdsByGroup.putIfAbsent(
                  groupId,
                  () => <String>{},
                );
                if (initial) {
                  initial = false;
                  if (!initialGroupIds.contains(groupId) &&
                      snapshot.docs.isNotEmpty) {
                    DocumentSnapshot<Map<String, dynamic>>? latest;
                    DateTime? latestAt;
                    for (final doc in snapshot.docs) {
                      final at = _timestampFrom(doc.data());
                      if (at != null &&
                          (latestAt == null || at.isAfter(latestAt))) {
                        latest = doc;
                        latestAt = at;
                      }
                    }
                    if (latest != null && seen.add(latest.id)) {
                      emit(groupId, latest);
                    }
                  }
                  seen.addAll(snapshot.docs.map((doc) => doc.id));
                  return;
                }
                for (final change in snapshot.docChanges) {
                  if (change.type == DocumentChangeType.added &&
                      seen.add(change.doc.id)) {
                    emit(groupId, change.doc);
                  }
                }
              },
              onError: (_) {
                // Não reiniciar este listener em loop. O SDK gere as
                // reconexões transitórias do Firestore.
                subscriptions.remove(groupId)?.cancel();
              },
            );
      }

      start = () {
        if (disposed) return;
        groupsSubscription?.cancel();
        cancelChildren();
        initialGroupsSnapshot = true;
        groupsSubscription = firestore
            .collection(AppConstants.groupsCollection)
            .snapshots()
            .listen((snapshot) {
              final currentIds = snapshot.docs.map((doc) => doc.id).toSet();
              if (initialGroupsSnapshot) {
                initialGroupIds.addAll(currentIds);
                initialGroupsSnapshot = false;
              }
              for (final oldId in subscriptions.keys.toList()) {
                if (!currentIds.contains(oldId)) {
                  subscriptions.remove(oldId)?.cancel();
                  seenIdsByGroup.remove(oldId);
                }
              }
              for (final groupId in currentIds) {
                watchGroup(groupId);
              }
            }, onError: (_) {
              // O SDK do Firestore gere a reconexão de listeners. Não
              // reiniciar manualmente em loop quando há erro de rede/permissão.
            });
      };

      start();
      ref.onDispose(() {
        disposed = true;
        groupsSubscription?.cancel();
        cancelChildren();
        controller.close();
      });
      return controller.stream;
    });
