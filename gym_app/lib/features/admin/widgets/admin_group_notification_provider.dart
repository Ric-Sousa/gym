import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'admin_messages_view.dart';

final adminIncomingGroupChatNotificationProvider =
    StreamProvider<AdminChatNotification>((ref) {
      final adminId = ref.watch(authProvider).user?.uid ?? '';
      if (adminId.isEmpty) return const Stream.empty();

      // A filtragem de membros é feita dentro do stream para não exigir um
      // índice composto nem permitir que salas externas sejam notificadas.
      final query = FirebaseFirestore.instance
          .collectionGroup(AppConstants.groupMessagesSubcollection)
          .orderBy('timestamp');

      return () async* {
        var initial = true;
        final latestByMessage = <String, DateTime>{};
        await for (final snapshot in query.snapshots()) {
          for (final change in snapshot.docChanges) {
            final path = change.doc.reference.path.split('/');
            if (path.length < 4 || path[0] != AppConstants.groupsCollection) {
              continue;
            }
            final data = change.doc.data();
            if (data == null || data['remetenteId'] == adminId) continue;

            final rawTimestamp = data['timestamp'];
            final timestamp = rawTimestamp is Timestamp
                ? rawTimestamp.toDate()
                : rawTimestamp is DateTime
                ? rawTimestamp
                : null;
            if (timestamp == null) continue;

            final key = change.doc.reference.path;
            final previous = latestByMessage[key];
            latestByMessage[key] = timestamp;
            if (initial || previous != null) continue;

            yield AdminChatNotification(roomId: path[1], timestamp: timestamp);
          }
          initial = false;
        }
      }();
    });
