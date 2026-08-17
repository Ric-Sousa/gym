import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';

DateTime? _adminChatTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

bool _isDirectRoomForAdmin(String roomId, String adminId) {
  final parts = roomId.split('_');
  return parts.length >= 3 &&
      (parts[1] == adminId || parts[2] == adminId);
}

/// Counts unread direct messages without depending on an async map over room
/// snapshots. The message listeners are the source of truth, so a parent-room
/// refresh cannot briefly reset the tab badge to zero.
final adminUnreadCountProvider = StreamProvider<int>((ref) {
  final adminId = ref.watch(authProvider.select((s) => s.user?.uid ?? ''));
  if (adminId.isEmpty) return Stream.value(0);

  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<int>();
  final counts = <String, int>{};
  final initializedRooms = <String>{};
  final subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomsSubscription;
  var roomsDiscovered = false;
  var firstValueEmitted = false;

  void emitTotal() {
    if (!controller.isClosed) {
      controller.add(counts.values.fold<int>(0, (total, value) => total + value));
    }
  }

  bool ready() =>
      roomsDiscovered && subscriptions.keys.every(initializedRooms.contains);

  void watchRoom(String roomId) {
    if (subscriptions.containsKey(roomId)) return;
    subscriptions[roomId] = firestore
        .collection(AppConstants.chatCollection)
        .doc(roomId)
        .collection(AppConstants.messagesSubcollection)
        .snapshots()
        .listen((snapshot) {
          initializedRooms.add(roomId);
          counts[roomId] = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['lida'] != true && data['remetenteId'] != adminId;
          }).length;
          if (firstValueEmitted || ready()) {
            firstValueEmitted = true;
            emitTotal();
          }
        }, onError: (_) {
          initializedRooms.add(roomId);
          counts[roomId] = 0;
          if (firstValueEmitted || ready()) {
            firstValueEmitted = true;
            emitTotal();
          }
        });
  }

  roomsSubscription = firestore
      .collection(AppConstants.chatCollection)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'chat_')
      .where(FieldPath.documentId, isLessThanOrEqualTo: 'chat_\uf8ff')
      .snapshots()
      .listen((snapshot) {
    final currentIds = snapshot.docs
        .map((doc) => doc.id)
        .where((roomId) => _isDirectRoomForAdmin(roomId, adminId))
        .toSet();

    for (final oldId in subscriptions.keys.toList()) {
      if (!currentIds.contains(oldId)) {
        subscriptions.remove(oldId)?.cancel();
        counts.remove(oldId);
        initializedRooms.remove(oldId);
      }
    }
    for (final roomId in currentIds) {
      watchRoom(roomId);
    }

    if (!roomsDiscovered) {
      roomsDiscovered = true;
      if (currentIds.isEmpty) {
        firstValueEmitted = true;
        emitTotal();
      } else if (ready()) {
        firstValueEmitted = true;
        emitTotal();
      }
    } else if (currentIds.isEmpty || firstValueEmitted) {
      // Room additions/removals should update the total, but do not emit a
      // transient zero while an existing room is refreshing its messages.
      emitTotal();
    }
  }, onError: (_) {
    if (!roomsDiscovered) {
      roomsDiscovered = true;
      firstValueEmitted = true;
    }
    emitTotal();
  });

  ref.onDispose(() {
    roomsSubscription?.cancel();
    for (final subscription in subscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Per-group unread counts. Both the Groups tab badge and each group tile use
/// this provider, preventing them from disagreeing about the same messages.
final adminGroupUnreadCountsProvider =
    StreamProvider<Map<String, int>>((ref) {
  final adminId = ref.watch(authProvider.select((s) => s.user?.uid ?? ''));
  if (adminId.isEmpty) return Stream.value(const <String, int>{});

  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<Map<String, int>>();
  final counts = <String, int>{};
  final readAtByGroup = <String, DateTime?>{};
  final messagesByGroup = <String, List<Map<String, dynamic>>>{};
  final initializedGroups = <String>{};
  final subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? groupsSubscription;
  var groupsDiscovered = false;
  var firstValueEmitted = false;

  void emitCounts() {
    if (!controller.isClosed) {
      controller.add(Map<String, int>.from(counts));
    }
  }

  void recalculate(String groupId) {
    final readAt = readAtByGroup[groupId];
    final messages = messagesByGroup[groupId] ?? const <Map<String, dynamic>>[];
    counts[groupId] = messages.where((data) {
      final timestamp = _adminChatTimestamp(data['timestamp']);
      return data['lida'] != true &&
          data['remetenteId'] != adminId &&
          (readAt == null ||
              (timestamp != null && timestamp.isAfter(readAt)));
    }).length;
  }

  bool ready() => groupsDiscovered &&
      subscriptions.keys.every(initializedGroups.contains);

  void watchGroup(String groupId) {
    if (subscriptions.containsKey(groupId)) return;
    subscriptions[groupId] = firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .snapshots()
        .listen((snapshot) {
          initializedGroups.add(groupId);
          messagesByGroup[groupId] =
              snapshot.docs.map((doc) => doc.data()).toList();
          recalculate(groupId);
          if (firstValueEmitted || ready()) {
            firstValueEmitted = true;
            emitCounts();
          }
        }, onError: (_) {
          initializedGroups.add(groupId);
          messagesByGroup[groupId] = const [];
          counts[groupId] = 0;
          if (firstValueEmitted || ready()) {
            firstValueEmitted = true;
            emitCounts();
          }
        });
  }

  groupsSubscription = firestore
      .collection(AppConstants.groupsCollection)
      .snapshots()
      .listen((snapshot) {
    final currentIds = snapshot.docs.map((doc) => doc.id).toSet();
    for (final oldId in subscriptions.keys.toList()) {
      if (!currentIds.contains(oldId)) {
        subscriptions.remove(oldId)?.cancel();
        counts.remove(oldId);
        readAtByGroup.remove(oldId);
        messagesByGroup.remove(oldId);
        initializedGroups.remove(oldId);
      }
    }

    for (final doc in snapshot.docs) {
      final raw = (doc.data()['lastReadAtByUser'] as Map?)?[adminId];
      readAtByGroup[doc.id] = _adminChatTimestamp(raw);
      if (messagesByGroup.containsKey(doc.id)) recalculate(doc.id);
    }
    for (final groupId in currentIds) {
      watchGroup(groupId);
    }

    if (!groupsDiscovered) {
      groupsDiscovered = true;
      if (currentIds.isEmpty) {
        firstValueEmitted = true;
        emitCounts();
      } else if (ready()) {
        firstValueEmitted = true;
        emitCounts();
      }
    } else if (firstValueEmitted) {
      emitCounts();
    }
  }, onError: (_) {
    if (!groupsDiscovered) {
      groupsDiscovered = true;
      firstValueEmitted = true;
    }
    emitCounts();
  });

  ref.onDispose(() {
    groupsSubscription?.cancel();
    for (final subscription in subscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Total unread group messages used by the admin floating chat and its tab.
final adminGroupUnreadCountProvider = Provider<int>((ref) {
  final countsAsync = ref.watch(adminGroupUnreadCountsProvider);
  return countsAsync.maybeWhen(
    data: (counts) => counts.values.fold<int>(0, (total, amount) => total + amount),
    orElse: () => 0,
  );
});
