import '../datasources/firestore_datasource.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';

/// Repositório de grupos de chat.
class GroupRepository {
  final FirestoreDataSource _firestore;

  GroupRepository({required FirestoreDataSource firestoreDataSource})
    : _firestore = firestoreDataSource;

  Future<List<GroupModel>> getMyGroups(String userId) =>
      _firestore.getMyGroups(userId);

  Future<List<GroupModel>> getAllGroups() => _firestore.getAllGroups();

  Future<String> createGroup(Map<String, dynamic> data) =>
      _firestore.createGroup(data);

  Future<void> sendMessage(String groupId, Map<String, dynamic> data) =>
      _firestore.sendGroupMessage(groupId, data);

  Stream<List<MessageModel>> watchMessages(String groupId) =>
      _firestore.watchGroupMessages(groupId);
}
